import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:csv/csv.dart';
import 'package:excel/excel.dart';

import '../models/quiz_models.dart';

class QuizService {
  const QuizService();

  FirebaseFirestore get _db => FirebaseFirestore.instance;

  Stream<List<QuizSummary>> streamStudentQuizzes({String? batch}) {
    return _db
        .collection('quizzes')
        .orderBy('startAt')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(QuizSummary.fromSnapshot)
              .where((quiz) {
                if (batch == null || batch.trim().isEmpty) {
                  return true;
                }
                return quiz.batch.toLowerCase() == batch.trim().toLowerCase();
              })
              .toList(growable: false),
        );
  }

  Stream<List<QuizSummary>> streamTeacherQuizzes(String teacherId) {
    return _db
        .collection('quizzes')
        .where('createdBy', isEqualTo: teacherId)
        .snapshots()
        .map((snapshot) {
          final quizzes = snapshot.docs
              .map(QuizSummary.fromSnapshot)
              .toList(growable: false);
          final sorted = List<QuizSummary>.from(quizzes)
            ..sort((a, b) => b.startAt.compareTo(a.startAt));
          return sorted;
        });
  }

  Future<List<QuizQuestion>> getQuizQuestions(String quizId) async {
    final snapshot = await _db
        .collection('quizzes')
        .doc(quizId)
        .collection('questions')
        .orderBy('order')
        .get();

    return snapshot.docs.map(QuizQuestion.fromSnapshot).toList(growable: false);
  }

  Future<String> createQuizFromExcel({
    required String teacherId,
    required String teacherEmail,
    required String title,
    required String subject,
    required DateTime startAt,
    required int durationMinutes,
    required String batch,
    required Uint8List fileBytes,
    required String fileName,
    required String? fileExtension,
  }) async {
    final quizRef = _db.collection('quizzes').doc();
    final resolvedExtension = _resolveFileExtension(
      fileExtension: fileExtension,
      fileName: fileName,
    );

    await quizRef.set({
      'title': title.trim(),
      'subject': subject.trim(),
      'startAt': Timestamp.fromDate(startAt),
      'durationMinutes': durationMinutes,
      'batch': batch.trim(),
      'createdBy': teacherId,
      'createdByEmail': teacherEmail,
      'createdAt': FieldValue.serverTimestamp(),
      'status': 'processing',
      'totalQuestions': 0,
      'totalPoints': 0,
      'sourceFileName': fileName,
      'sourceFileType': resolvedExtension,
      'parsedLocally': true,
    }, SetOptions(merge: true));

    try {
      final parsedQuestions = _parseQuestionsFromFile(
        fileBytes: fileBytes,
        fileExtension: resolvedExtension,
      );

      if (parsedQuestions.isEmpty) {
        throw const FormatException(
          'No valid question rows found in uploaded sheet.',
        );
      }

      final questionsRef = quizRef.collection('questions');
      await _clearCollection(questionsRef);

      var totalPoints = 0;
      var batchWriter = _db.batch();
      var batchOps = 0;

      for (var index = 0; index < parsedQuestions.length; index++) {
        final question = parsedQuestions[index];
        totalPoints += question.points;

        final docRef = questionsRef.doc();
        batchWriter.set(docRef, {
          'text': question.text,
          'options': question.options,
          'correctOption': question.correctOption,
          'points': question.points,
          'order': index,
          'createdAt': FieldValue.serverTimestamp(),
        });

        batchOps += 1;
        if (batchOps >= 450) {
          await batchWriter.commit();
          batchWriter = _db.batch();
          batchOps = 0;
        }
      }

      if (batchOps > 0) {
        await batchWriter.commit();
      }

      await quizRef.set({
        'status': 'ready',
        'totalQuestions': parsedQuestions.length,
        'totalPoints': totalPoints,
        'parsedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (error) {
      await quizRef.set({
        'status': 'error',
        'errorCode': 'local-parse-failed',
        'errorMessage': error.toString(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      rethrow;
    }

    return quizRef.id;
  }

  List<_ParsedQuestion> _parseQuestionsFromFile({
    required Uint8List fileBytes,
    required String? fileExtension,
  }) {
    final extension = (fileExtension ?? '').toLowerCase().trim();

    if (extension == 'csv') {
      final rows = _readCsvRows(fileBytes);
      return _normalizeRows(rows);
    }

    if (extension == 'xlsx') {
      final rows = _readXlsxRows(fileBytes);
      return _normalizeRows(rows);
    }

    if (extension == 'xls') {
      throw UnsupportedError(
        'Local parsing for .xls is not supported. Please convert to .xlsx.',
      );
    }

    throw FormatException(
      'Unsupported file type "$extension". Use .xlsx or .csv files.',
    );
  }

  List<Map<String, String>> _readXlsxRows(Uint8List bytes) {
    final workbook = Excel.decodeBytes(bytes);
    if (workbook.tables.isEmpty) {
      throw const FormatException('No worksheet found in uploaded file.');
    }

    final sheet = workbook.tables.values.first;
    if (sheet.rows.isEmpty) {
      throw const FormatException('Uploaded sheet has no rows.');
    }

    final rawHeaders = sheet.rows.first;
    final headers = rawHeaders
        .map((cell) => _normalizeHeader(_toCellText(cell)))
        .toList(growable: false);

    final rows = <Map<String, String>>[];
    for (var rowIndex = 1; rowIndex < sheet.rows.length; rowIndex++) {
      final rowCells = sheet.rows[rowIndex];
      final rowMap = <String, String>{};

      for (var colIndex = 0; colIndex < headers.length; colIndex++) {
        final header = headers[colIndex];
        if (header.isEmpty) {
          continue;
        }

        final value = colIndex < rowCells.length
            ? _toCellText(rowCells[colIndex]).trim()
            : '';
        rowMap[header] = value;
      }

      rows.add(rowMap);
    }

    return rows;
  }

  List<Map<String, String>> _readCsvRows(Uint8List bytes) {
    final text = utf8.decode(bytes, allowMalformed: true);
    final normalizedText = text.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    final records = const CsvToListConverter(
      shouldParseNumbers: false,
      eol: '\n',
    ).convert(normalizedText);

    if (records.isEmpty) {
      throw const FormatException('Uploaded CSV has no rows.');
    }

    final headers = records.first
        .map((cell) => _normalizeHeader(cell.toString()))
        .toList(growable: false);

    final rows = <Map<String, String>>[];
    for (var rowIndex = 1; rowIndex < records.length; rowIndex++) {
      final record = records[rowIndex];
      final rowMap = <String, String>{};

      for (var colIndex = 0; colIndex < headers.length; colIndex++) {
        final header = headers[colIndex];
        if (header.isEmpty) {
          continue;
        }

        final value = colIndex < record.length
            ? record[colIndex].toString().trim()
            : '';
        rowMap[header] = value;
      }

      rows.add(rowMap);
    }

    return rows;
  }

  List<_ParsedQuestion> _normalizeRows(List<Map<String, String>> rows) {
    final parsed = <_ParsedQuestion>[];

    for (var index = 0; index < rows.length; index++) {
      final question = _normalizeQuestionRow(rows[index], index + 2);
      if (question != null) {
        parsed.add(question);
      }
    }

    return parsed;
  }

  _ParsedQuestion? _normalizeQuestionRow(Map<String, String> row, int rowNo) {
    final questionText = _pickField(row, const [
      'question',
      'question_text',
      'questiontext',
    ]);

    if (questionText.isEmpty) {
      return null;
    }

    final optionA = _pickField(row, const ['optiona', 'a']);
    final optionB = _pickField(row, const ['optionb', 'b']);
    final optionC = _pickField(row, const ['optionc', 'c']);
    final optionD = _pickField(row, const ['optiond', 'd']);

    final options = <String>[
      optionA,
      optionB,
      optionC,
      optionD,
    ].where((value) => value.isNotEmpty).toList(growable: false);

    if (options.length < 2) {
      return null;
    }

    final rawCorrect = _pickField(row, const [
      'correctoption',
      'correct',
      'answer',
    ]).toUpperCase();

    String correctOption;
    if (rawCorrect.length == 1 &&
        rawCorrect.codeUnitAt(0) >= 65 &&
        rawCorrect.codeUnitAt(0) <= 68) {
      final optionIndex = rawCorrect.codeUnitAt(0) - 65;
      correctOption = optionIndex < options.length
          ? options[optionIndex]
          : options.first;
    } else {
      final exactMatch = options.where(
        (option) => option.toLowerCase() == rawCorrect.toLowerCase(),
      );
      correctOption = exactMatch.isNotEmpty ? exactMatch.first : options.first;
    }

    final pointsValue = _pickField(row, const [
      'points',
      'point',
      'mark',
      'marks',
    ]);
    final points = int.tryParse(pointsValue) ?? 1;

    if (points <= 0) {
      throw FormatException('Invalid points at row $rowNo. Points must be > 0');
    }

    return _ParsedQuestion(
      text: questionText,
      options: options,
      correctOption: correctOption,
      points: points,
    );
  }

  String _pickField(Map<String, String> row, List<String> candidates) {
    for (final key in candidates) {
      final value = row[_normalizeHeader(key)] ?? '';
      if (value.trim().isNotEmpty) {
        return value.trim();
      }
    }
    return '';
  }

  String _normalizeHeader(String header) {
    return header.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  String _resolveFileExtension({
    required String? fileExtension,
    required String fileName,
  }) {
    final raw = (fileExtension ?? '').trim().toLowerCase();
    if (raw.isNotEmpty) {
      return raw;
    }

    final dotIndex = fileName.lastIndexOf('.');
    if (dotIndex < 0 || dotIndex == fileName.length - 1) {
      return '';
    }

    return fileName.substring(dotIndex + 1).trim().toLowerCase();
  }

  String _toCellText(dynamic cell) {
    if (cell == null) {
      return '';
    }

    final dynamic rawValue = cell is Data ? cell.value : cell;
    if (rawValue == null) {
      return '';
    }

    try {
      final dynamic nestedValue = rawValue.value;
      if (nestedValue != null) {
        return nestedValue.toString();
      }
    } catch (_) {
      // Some cell value implementations do not expose `.value`.
    }

    return rawValue.toString();
  }

  Future<void> _clearCollection(
    CollectionReference<Map<String, dynamic>> ref,
  ) async {
    while (true) {
      final snapshot = await ref.limit(400).get();
      if (snapshot.docs.isEmpty) {
        break;
      }

      final batch = _db.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();

      if (snapshot.size < 400) {
        break;
      }
    }
  }
}

class _ParsedQuestion {
  const _ParsedQuestion({
    required this.text,
    required this.options,
    required this.correctOption,
    required this.points,
  });

  final String text;
  final List<String> options;
  final String correctOption;
  final int points;
}

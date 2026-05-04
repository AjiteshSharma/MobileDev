import 'dart:convert';
import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:csv/csv.dart';
import 'package:excel/excel.dart';
import 'package:http/http.dart' as http;

import '../models/quiz_models.dart';

class QuizService {
  const QuizService();

  FirebaseFirestore get _db => FirebaseFirestore.instance;
  static const String _apiKeyCollection = 'key';
  static const String _apiKeyDocument = '2mVwBh6A9DrMSukIAL1X';
  static const String _apiKeyField = 'gemini';
  static const String _groqModel = String.fromEnvironment(
    'GROQ_MODEL',
    defaultValue: 'llama-3.1-8b-instant',
  );
  static const String _groqEndpoint =
      'https://api.groq.com/openai/v1/chat/completions';
  static String? _cachedGroqApiKey;

  Stream<List<QuizSummary>> streamStudentQuizzes({String? batch}) {
    final normalizedBatch = _normalizeBatch(batch);
    if (normalizedBatch.isEmpty) {
      return Stream.value(const <QuizSummary>[]);
    }

    return _db
        .collection('quizzes')
        .where('batch', isEqualTo: normalizedBatch)
        .snapshots()
        .map((snapshot) {
          final quizzes = snapshot.docs
              .map(QuizSummary.fromSnapshot)
              .toList(growable: false);
          final sorted = List<QuizSummary>.from(quizzes)
            ..sort((a, b) => a.startAt.compareTo(b.startAt));
          return sorted;
        });
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
    final batchLabel = batch.trim();
    final normalizedBatch = _normalizeBatch(batchLabel);
    if (normalizedBatch.isEmpty) {
      throw const FormatException('Batch is required to create a quiz.');
    }
    final resolvedExtension = _resolveFileExtension(
      fileExtension: fileExtension,
      fileName: fileName,
    );

    await quizRef.set({
      'title': title.trim(),
      'subject': subject.trim(),
      'startAt': Timestamp.fromDate(startAt),
      'durationMinutes': durationMinutes,
      'batch': normalizedBatch,
      'batchLabel': batchLabel,
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
      await _writeQuestions(questionsRef, parsedQuestions);
      final totalPoints = parsedQuestions.fold<int>(
        0,
        (accumulator, question) => accumulator + question.points,
      );

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

  Future<String> createQuizFromAI({
    required String title,
    required String subject,
    required DateTime startAt,
    required int durationMinutes,
    required String batch,
    required String prompt,
    required String difficulty,
    required int questionCount,
    required int maxMarks,
  }) async {
    final teacher = FirebaseAuth.instance.currentUser;
    if (teacher == null) {
      throw const FormatException('Session expired. Please sign in again.');
    }
    final groqApiKey = await _resolveGroqApiKey();

    final input = _normalizeAiInput(
      title: title,
      subject: subject,
      startAt: startAt,
      durationMinutes: durationMinutes,
      batch: batch,
      prompt: prompt,
      difficulty: difficulty,
      questionCount: questionCount,
      maxMarks: maxMarks,
    );

    final quizRef = _db.collection('quizzes').doc();
    await quizRef.set({
      'title': input.title,
      'subject': input.subject,
      'startAt': Timestamp.fromDate(input.startAt),
      'durationMinutes': input.durationMinutes,
      'batch': input.batch,
      'batchLabel': input.batchLabel,
      'createdBy': teacher.uid,
      'createdByEmail': teacher.email ?? '',
      'createdAt': FieldValue.serverTimestamp(),
      'status': 'processing',
      'totalQuestions': 0,
      'totalPoints': 0,
      'source': 'ai',
      'aiPrompt': input.prompt,
      'aiTopics': input.topics,
      'aiDifficulty': input.difficulty,
      'aiRequestedQuestionCount': input.questionCount,
      'aiRequestedMaxMarks': input.maxMarks,
    }, SetOptions(merge: true));

    try {
      final generated = await _generateQuestionsWithGroq(
        input,
        apiKey: groqApiKey,
      );
      final parsedQuestions = _normalizeGeneratedQuestions(
        rawQuestions: generated.questions,
        expectedCount: input.questionCount,
        maxMarks: input.maxMarks,
      );

      if (parsedQuestions.length != input.questionCount) {
        throw const FormatException(
          'AI generated invalid number of questions.',
        );
      }

      final questionsRef = quizRef.collection('questions');
      await _clearCollection(questionsRef);
      await _writeQuestions(questionsRef, parsedQuestions);

      final totalPoints = parsedQuestions.fold<int>(
        0,
        (accumulator, question) => accumulator + question.points,
      );

      await quizRef.set({
        'title': input.title,
        'status': 'ready',
        'totalQuestions': parsedQuestions.length,
        'totalPoints': totalPoints,
        'parsedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'aiGeneratedAt': FieldValue.serverTimestamp(),
        'aiModel': generated.model,
      }, SetOptions(merge: true));

      return quizRef.id;
    } catch (error) {
      await quizRef.set({
        'status': 'error',
        'errorCode': 'ai-generation-failed',
        'errorMessage': error.toString(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      rethrow;
    }
  }

  _AiInput _normalizeAiInput({
    required String title,
    required String subject,
    required DateTime startAt,
    required int durationMinutes,
    required String batch,
    required String prompt,
    required String difficulty,
    required int questionCount,
    required int maxMarks,
  }) {
    final normalizedTitle = title.trim();
    final normalizedSubject = subject.trim();
    final batchLabel = batch.trim();
    final normalizedBatch = _normalizeBatch(batchLabel);
    final normalizedPrompt = prompt.trim();
    final normalizedDifficulty = _normalizeDifficulty(difficulty);
    final topics = _extractTopics(normalizedPrompt);

    if (normalizedTitle.isEmpty) {
      throw const FormatException('Quiz title is required.');
    }
    if (normalizedSubject.isEmpty) {
      throw const FormatException('Subject is required.');
    }
    if (normalizedBatch.isEmpty) {
      throw const FormatException('Batch is required.');
    }
    if (normalizedPrompt.isEmpty) {
      throw const FormatException('Prompt is required.');
    }
    if (topics.isEmpty) {
      throw const FormatException(
        'Provide at least one topic (comma-separated is supported).',
      );
    }
    if (questionCount < 2 || questionCount > 50) {
      throw const FormatException('Question count must be between 2 and 50.');
    }
    if (maxMarks < 2 || maxMarks > 500) {
      throw const FormatException('Max marks must be between 2 and 500.');
    }
    if (maxMarks < questionCount) {
      throw const FormatException(
        'Max marks must be at least the question count.',
      );
    }
    if (durationMinutes < 1 || durationMinutes > 600) {
      throw const FormatException(
        'Duration must be between 1 and 600 minutes.',
      );
    }

    return _AiInput(
      title: normalizedTitle,
      subject: normalizedSubject,
      startAt: startAt,
      durationMinutes: durationMinutes,
      batch: normalizedBatch,
      batchLabel: batchLabel,
      prompt: normalizedPrompt,
      topics: topics,
      difficulty: normalizedDifficulty,
      questionCount: questionCount,
      maxMarks: maxMarks,
    );
  }

  Future<_AiGeneratedQuiz> _generateQuestionsWithGroq(
    _AiInput input, {
    required String apiKey,
  }) async {
    final endpoint = Uri.parse(_groqEndpoint);

    final response = await http.post(
      endpoint,
      headers: {
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'model': _groqModel,
        'messages': [
          {
            'role': 'system',
            'content':
                'You are an exam-setter assistant. Return valid JSON only.',
          },
          {'role': 'user', 'content': _buildAiPrompt(input)},
        ],
        'temperature': 0.3,
      }),
    );

    Map<String, dynamic> jsonBody = <String, dynamic>{};
    if (response.body.isNotEmpty) {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        jsonBody = decoded;
      } else if (decoded is Map) {
        jsonBody = decoded.cast<String, dynamic>();
      }
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = (jsonBody['error']?['message']?.toString() ?? '').trim();
      throw FormatException(
        message.isNotEmpty
            ? 'Groq generation failed: $message'
            : 'Groq generation failed with status ${response.statusCode}.',
      );
    }

    final choices = jsonBody['choices'];
    if (choices is! List || choices.isEmpty) {
      throw const FormatException('Groq returned no choices.');
    }

    final firstChoice = choices.first;
    if (firstChoice is! Map) {
      throw const FormatException('Groq response format is invalid.');
    }

    final message = firstChoice['message'];
    if (message is! Map) {
      throw const FormatException('Groq message is missing.');
    }

    final text = (message['content'] ?? '').toString().trim();

    if (text.isEmpty) {
      throw const FormatException('Groq returned empty text response.');
    }

    final decodedJson = _decodeJsonValueFromText(text);
    final extracted = _extractQuizPayload(decodedJson);

    return _AiGeneratedQuiz(
      title: extracted.title,
      questions: extracted.questions,
      model: (jsonBody['model']?.toString() ?? _groqModel).trim(),
    );
  }

  dynamic _decodeJsonValueFromText(String text) {
    final direct = _tryDecodeJson(text);
    if (direct != null) {
      return direct;
    }

    final fenceMatch = RegExp(
      r'```(?:json)?\s*([\s\S]*?)\s*```',
      caseSensitive: false,
    ).firstMatch(text);
    if (fenceMatch != null) {
      final insideFence = fenceMatch.group(1) ?? '';
      final fencedMap = _tryDecodeJson(insideFence);
      if (fencedMap != null) {
        return fencedMap;
      }
    }

    final firstBrace = text.indexOf('{');
    final lastBrace = text.lastIndexOf('}');
    if (firstBrace >= 0 && lastBrace > firstBrace) {
      final sliced = text.substring(firstBrace, lastBrace + 1);
      final slicedMap = _tryDecodeJson(sliced);
      if (slicedMap != null) {
        return slicedMap;
      }
    }

    final firstBracket = text.indexOf('[');
    final lastBracket = text.lastIndexOf(']');
    if (firstBracket >= 0 && lastBracket > firstBracket) {
      final sliced = text.substring(firstBracket, lastBracket + 1);
      final slicedList = _tryDecodeJson(sliced);
      if (slicedList != null) {
        return slicedList;
      }
    }

    throw const FormatException(
      'AI output is not valid JSON. Please retry with clearer topics.',
    );
  }

  dynamic _tryDecodeJson(String raw) {
    final candidate = raw.trim();
    if (candidate.isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(candidate);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      if (decoded is Map) {
        return decoded.cast<String, dynamic>();
      }
      if (decoded is List) {
        return decoded;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  _ExtractedQuizPayload _extractQuizPayload(dynamic decodedJson) {
    if (decodedJson is List) {
      return _ExtractedQuizPayload(title: '', questions: decodedJson);
    }

    if (decodedJson is Map) {
      final normalizedMap = decodedJson is Map<String, dynamic>
          ? decodedJson
          : decodedJson.cast<String, dynamic>();

      final title =
          (normalizedMap['title'] ??
                  normalizedMap['quizTitle'] ??
                  normalizedMap['quiz_title'] ??
                  normalizedMap['topic'] ??
                  '')
              .toString()
              .trim();

      final questionList = _extractQuestionListFromMap(normalizedMap);
      if (questionList.isNotEmpty) {
        return _ExtractedQuizPayload(title: title, questions: questionList);
      }

      if (_looksLikeQuestionMap(normalizedMap)) {
        return _ExtractedQuizPayload(title: title, questions: [normalizedMap]);
      }
    }

    return const _ExtractedQuizPayload(title: '', questions: <dynamic>[]);
  }

  List<dynamic> _extractQuestionListFromMap(Map<String, dynamic> map) {
    const listKeys = <String>[
      'questions',
      'mcqs',
      'quiz',
      'items',
      'data',
      'questionList',
      'question_list',
    ];

    for (final key in listKeys) {
      final value = map[key];
      if (value is List && value.isNotEmpty) {
        return List<dynamic>.from(value);
      }
    }

    for (final value in map.values) {
      if (value is List && value.isNotEmpty && value.first is Map) {
        return List<dynamic>.from(value);
      }
      if (value is Map) {
        final nested = value is Map<String, dynamic>
            ? value
            : value.cast<String, dynamic>();
        final nestedList = _extractQuestionListFromMap(nested);
        if (nestedList.isNotEmpty) {
          return nestedList;
        }
      }
    }

    return const <dynamic>[];
  }

  bool _looksLikeQuestionMap(Map<String, dynamic> map) {
    final hasQuestionText = (map['text'] ?? map['question'] ?? '')
        .toString()
        .trim()
        .isNotEmpty;
    final hasOptions =
        map['options'] is List ||
        map['options'] is Map ||
        map['choices'] is List ||
        map['choices'] is Map;
    return hasQuestionText && hasOptions;
  }

  Future<String> _resolveGroqApiKey() async {
    final cached = _cachedGroqApiKey;
    if (cached != null && cached.trim().isNotEmpty) {
      return cached;
    }

    try {
      final fixedDoc = await _db
          .collection(_apiKeyCollection)
          .doc(_apiKeyDocument)
          .get();
      final fromFixedDoc = _extractKeyFromDocument(fixedDoc.data());
      if (fromFixedDoc.isNotEmpty) {
        _cachedGroqApiKey = fromFixedDoc;
        return fromFixedDoc;
      }

      final fallbackSnapshot = await _db
          .collection(_apiKeyCollection)
          .limit(1)
          .get();
      if (fallbackSnapshot.docs.isNotEmpty) {
        final fromFallback = _extractKeyFromDocument(
          fallbackSnapshot.docs.first.data(),
        );
        if (fromFallback.isNotEmpty) {
          _cachedGroqApiKey = fromFallback;
          return fromFallback;
        }
      }
    } on FirebaseException catch (error) {
      throw FormatException(
        'Failed to read Groq key from Firestore (${error.code}).',
      );
    }

    throw const FormatException(
      'Groq key not found in Firestore. Expected key/2mVwBh6A9DrMSukIAL1X field "gemini".',
    );
  }

  String _extractKeyFromDocument(Map<String, dynamic>? data) {
    if (data == null) {
      return '';
    }
    final value = (data[_apiKeyField] ?? '').toString().trim();
    return value;
  }

  List<_ParsedQuestion> _normalizeGeneratedQuestions({
    required List<dynamic> rawQuestions,
    required int expectedCount,
    required int maxMarks,
  }) {
    if (rawQuestions.isEmpty) {
      throw const FormatException('AI did not generate any questions.');
    }

    final cleaned = <_ParsedQuestion>[];
    for (final item in rawQuestions) {
      if (item is! Map) {
        continue;
      }

      final text =
          (item['text'] ?? item['question'] ?? item['questionText'] ?? '')
              .toString()
              .trim();
      if (text.isEmpty) {
        continue;
      }

      final optionsRaw = item['options'] ?? item['choices'] ?? item['answers'];
      final options = <String>[];
      if (optionsRaw is List) {
        for (final option in optionsRaw.take(4)) {
          final value = option.toString().trim();
          if (value.isNotEmpty) {
            options.add(value);
          }
        }
      } else if (optionsRaw is Map) {
        const preferredOrder = ['A', 'B', 'C', 'D', 'a', 'b', 'c', 'd'];
        for (final key in preferredOrder) {
          final raw = optionsRaw[key];
          if (raw != null) {
            final value = raw.toString().trim();
            if (value.isNotEmpty) {
              options.add(value);
            }
          }
        }
        if (options.isEmpty) {
          for (final raw in optionsRaw.values) {
            final value = raw.toString().trim();
            if (value.isNotEmpty) {
              options.add(value);
            }
          }
        }
      }

      while (options.length < 4) {
        options.add('Option ${options.length + 1}');
      }

      final rawIndex = int.tryParse(
        (item['correctOptionIndex'] ??
                item['answerIndex'] ??
                item['correct_index'] ??
                '')
            .toString(),
      );
      var validIndex =
          rawIndex != null && rawIndex >= 0 && rawIndex < options.length
          ? rawIndex
          : -1;

      if (validIndex < 0) {
        final correctAnswerText =
            (item['correct_answer'] ??
                    item['correctAnswer'] ??
                    item['answer'] ??
                    item['correctOption'] ??
                    '')
                .toString()
                .trim();
        if (correctAnswerText.isNotEmpty) {
          if (correctAnswerText.length == 1 &&
              RegExp(r'^[A-Da-d]$').hasMatch(correctAnswerText)) {
            validIndex = correctAnswerText.toUpperCase().codeUnitAt(0) - 65;
          } else {
            final byText = options.indexWhere(
              (option) =>
                  option.toLowerCase() == correctAnswerText.toLowerCase(),
            );
            validIndex = byText;
          }
        }
      }
      if (validIndex < 0 || validIndex >= options.length) {
        validIndex = 0;
      }
      final correctOption = options[validIndex];
      final points =
          int.tryParse(
            (item['points'] ?? item['marks'] ?? item['mark'] ?? '').toString(),
          ) ??
          1;

      cleaned.add(
        _ParsedQuestion(
          text: text,
          options: options,
          correctOption: correctOption,
          points: points > 0 ? points : 1,
        ),
      );
    }

    if (cleaned.length < expectedCount) {
      throw FormatException(
        'AI generated ${cleaned.length} valid questions, expected $expectedCount.',
      );
    }

    final trimmed = cleaned.take(expectedCount).toList(growable: false);
    return _rebalancePoints(trimmed, maxMarks);
  }

  List<_ParsedQuestion> _rebalancePoints(
    List<_ParsedQuestion> questions,
    int maxMarks,
  ) {
    final currentTotal = questions.fold<int>(
      0,
      (accumulator, q) => accumulator + q.points,
    );
    if (currentTotal == maxMarks) {
      return questions;
    }

    final base = maxMarks ~/ questions.length;
    final remainder = maxMarks % questions.length;
    return List<_ParsedQuestion>.generate(questions.length, (index) {
      final question = questions[index];
      final points = base + (index < remainder ? 1 : 0);
      return _ParsedQuestion(
        text: question.text,
        options: question.options,
        correctOption: question.correctOption,
        points: points,
      );
    }, growable: false);
  }

  String _buildAiPrompt(_AiInput input) {
    final topicLines = input.topics
        .asMap()
        .entries
        .map((entry) => '${entry.key + 1}) ${entry.value}')
        .join('\n');

    return [
      'Generate a multiple-choice quiz.',
      'Subject: ${input.subject}',
      'Difficulty: ${input.difficulty}',
      'Focus topics (from teacher input):',
      topicLines,
      'Number of questions: ${input.questionCount}',
      'Total maximum marks: ${input.maxMarks}',
      'Instructions:',
      '1) Keep questions concise and clear.',
      '2) Each question must have exactly 4 options.',
      '3) Provide one correct option index from 0 to 3.',
      '4) Use integer points per question.',
      '5) Avoid duplicate questions.',
      '6) Return ONLY valid JSON.',
      '7) Required JSON format:',
      '{"title":"...","questions":[{"text":"...","options":["A","B","C","D"],"correctOptionIndex":0,"points":1}]}',
    ].join('\n');
  }

  List<String> _extractTopics(String prompt) {
    return prompt
        .split(RegExp(r'[,\n]+'))
        .map((topic) => topic.trim())
        .where((topic) => topic.isNotEmpty)
        .toList(growable: false);
  }

  String _normalizeDifficulty(String value) {
    final normalized = value.trim().toLowerCase();
    if (normalized == 'easy' ||
        normalized == 'medium' ||
        normalized == 'hard') {
      return normalized;
    }
    return 'medium';
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

  String _normalizeBatch(String? input) {
    return (input ?? '').trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
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

  Future<void> _writeQuestions(
    CollectionReference<Map<String, dynamic>> questionsRef,
    List<_ParsedQuestion> questions,
  ) async {
    var batchWriter = _db.batch();
    var batchOps = 0;

    for (var index = 0; index < questions.length; index++) {
      final question = questions[index];
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

class _AiInput {
  const _AiInput({
    required this.title,
    required this.subject,
    required this.startAt,
    required this.durationMinutes,
    required this.batch,
    required this.batchLabel,
    required this.prompt,
    required this.topics,
    required this.difficulty,
    required this.questionCount,
    required this.maxMarks,
  });

  final String title;
  final String subject;
  final DateTime startAt;
  final int durationMinutes;
  final String batch;
  final String batchLabel;
  final String prompt;
  final List<String> topics;
  final String difficulty;
  final int questionCount;
  final int maxMarks;
}

class _AiGeneratedQuiz {
  const _AiGeneratedQuiz({
    required this.title,
    required this.questions,
    required this.model,
  });

  final String title;
  final List<dynamic> questions;
  final String model;
}

class _ExtractedQuizPayload {
  const _ExtractedQuizPayload({required this.title, required this.questions});

  final String title;
  final List<dynamic> questions;
}

import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../models/quiz_models.dart';

class QuizService {
  const QuizService();

  FirebaseFirestore get _db => FirebaseFirestore.instance;
  FirebaseStorage get _storage => FirebaseStorage.instance;
  FirebaseFunctions get _functions => FirebaseFunctions.instance;

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
        .orderBy('startAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(QuizSummary.fromSnapshot)
              .toList(growable: false),
        );
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
  }) async {
    final quizRef = _db.collection('quizzes').doc();
    final storagePath = 'quiz_uploads/$teacherId/${quizRef.id}/$fileName';

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
      'filePath': storagePath,
    }, SetOptions(merge: true));

    await _storage
        .ref(storagePath)
        .putData(
          fileBytes,
          SettableMetadata(
            contentType:
                'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
          ),
        );

    try {
      await _functions.httpsCallable('parseQuizExcel').call({
        'quizId': quizRef.id,
        'storagePath': storagePath,
      });

      await quizRef.set({
        'status': 'ready',
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } on FirebaseFunctionsException catch (error) {
      await quizRef.set({
        'status': 'error',
        'errorCode': error.code,
        'errorMessage': error.message,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      rethrow;
    }

    return quizRef.id;
  }
}

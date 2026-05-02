import 'package:cloud_firestore/cloud_firestore.dart';

class AttemptService {
  const AttemptService();

  static const int flagThreshold = 2;
  static const int disqualificationThreshold = 4;

  FirebaseFirestore get _db => FirebaseFirestore.instance;

  Future<String> startOrResumeAttempt({
    required String quizId,
    required String studentId,
  }) async {
    final attemptId = '${quizId}_$studentId';
    final ref = _db.collection('attempts').doc(attemptId);
    final createPayload = {
      'quizId': quizId,
      'studentId': studentId,
      'status': 'in_progress',
      'violationCount': 0,
      'answers': <String, String>{},
      'startedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    try {
      await ref.update({'updatedAt': FieldValue.serverTimestamp()});
    } on FirebaseException catch (error) {
      final canFallbackToCreate =
          error.code == 'not-found' || error.code == 'permission-denied';
      if (!canFallbackToCreate) {
        rethrow;
      }

      await ref.set(createPayload);
    }

    return attemptId;
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> watchAttempt(
    String attemptId,
  ) {
    return _db.collection('attempts').doc(attemptId).snapshots();
  }

  Future<void> saveAnswer({
    required String attemptId,
    required String questionId,
    required String selectedOption,
  }) {
    return _db.collection('attempts').doc(attemptId).update({
      'answers.$questionId': selectedOption,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<int> logViolation({
    required String attemptId,
    required String quizId,
    required String studentId,
    required String type,
    String? details,
  }) async {
    final attemptRef = _db.collection('attempts').doc(attemptId);
    final violationRef = attemptRef.collection('violations').doc();

    return _db.runTransaction((transaction) async {
      final attemptSnapshot = await transaction.get(attemptRef);
      final data = attemptSnapshot.data() ?? const <String, dynamic>{};
      final currentCount = (data['violationCount'] as num?)?.toInt() ?? 0;
      final updatedCount = currentCount + 1;
      final currentStatus = (data['status'] as String?) ?? 'in_progress';

      final nextStatus = _resolveStatusAfterViolation(
        currentStatus: currentStatus,
        violationCount: updatedCount,
      );

      transaction.set(attemptRef, {
        'quizId': quizId,
        'studentId': studentId,
        'violationCount': updatedCount,
        'status': nextStatus,
        'isFlagged': updatedCount >= flagThreshold,
        'lastViolationAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      transaction.set(violationRef, {
        'type': type,
        'details': details ?? '',
        'createdAt': FieldValue.serverTimestamp(),
        'violationNumber': updatedCount,
      });

      return updatedCount;
    });
  }

  Future<void> submitAttempt({
    required String attemptId,
    bool autoSubmitted = false,
    String? submitReason,
  }) async {
    final attemptRef = _db.collection('attempts').doc(attemptId);
    final snapshot = await attemptRef.get();
    final data = snapshot.data() ?? const <String, dynamic>{};

    if (data['submittedAt'] != null) {
      return;
    }

    final violations = (data['violationCount'] as num?)?.toInt() ?? 0;
    final currentStatus = (data['status'] as String?) ?? 'in_progress';

    final nextStatus = _resolveStatusOnSubmit(
      currentStatus: currentStatus,
      violationCount: violations,
    );

    await attemptRef.set({
      'status': nextStatus,
      'isFlagged': violations >= flagThreshold,
      'autoSubmitted': autoSubmitted,
      'submitReason': (submitReason ?? '').trim(),
      'submittedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  String _resolveStatusAfterViolation({
    required String currentStatus,
    required int violationCount,
  }) {
    if (currentStatus == 'disqualified') {
      return currentStatus;
    }

    if (violationCount >= disqualificationThreshold) {
      return 'disqualified';
    }

    if (violationCount >= flagThreshold) {
      return 'flagged';
    }

    return 'in_progress';
  }

  String _resolveStatusOnSubmit({
    required String currentStatus,
    required int violationCount,
  }) {
    if (currentStatus == 'disqualified' ||
        violationCount >= disqualificationThreshold) {
      return 'disqualified';
    }

    if (currentStatus == 'flagged' || violationCount >= flagThreshold) {
      return 'flagged';
    }

    return 'submitted';
  }
}

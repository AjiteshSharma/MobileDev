import 'package:cloud_firestore/cloud_firestore.dart';

class QuizSummary {
  const QuizSummary({
    required this.id,
    required this.title,
    required this.subject,
    required this.startAt,
    required this.durationMinutes,
    required this.batch,
    required this.totalQuestions,
    required this.totalPoints,
    required this.createdBy,
    required this.status,
  });

  final String id;
  final String title;
  final String subject;
  final DateTime startAt;
  final int durationMinutes;
  final String batch;
  final int totalQuestions;
  final int totalPoints;
  final String createdBy;
  final String status;

  DateTime get endAt => startAt.add(Duration(minutes: durationMinutes));

  bool isActiveAt(DateTime now) =>
      !now.isBefore(startAt) && now.isBefore(endAt);

  bool isUpcomingAt(DateTime now) => now.isBefore(startAt);

  bool isPastAt(DateTime now) => !now.isBefore(endAt);

  factory QuizSummary.fromSnapshot(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    return QuizSummary(
      id: doc.id,
      title: (data['title'] as String?)?.trim().isNotEmpty == true
          ? (data['title'] as String).trim()
          : 'Untitled Quiz',
      subject: (data['subject'] as String?)?.trim().isNotEmpty == true
          ? (data['subject'] as String).trim()
          : 'General',
      startAt: _toDateTime(data['startAt']) ?? DateTime.now(),
      durationMinutes: (data['durationMinutes'] as num?)?.toInt() ?? 30,
      batch: (data['batch'] as String?)?.trim() ?? 'All',
      totalQuestions: (data['totalQuestions'] as num?)?.toInt() ?? 0,
      totalPoints: (data['totalPoints'] as num?)?.toInt() ?? 0,
      createdBy: (data['createdBy'] as String?) ?? '',
      status: ((data['status'] as String?) ?? 'ready').toLowerCase(),
    );
  }
}

class QuizQuestion {
  const QuizQuestion({
    required this.id,
    required this.text,
    required this.options,
    required this.points,
    this.correctOption = '',
  });

  final String id;
  final String text;
  final List<String> options;
  final int points;
  final String correctOption;

  factory QuizQuestion.fromSnapshot(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    final rawOptions = (data['options'] as List<dynamic>? ?? const <dynamic>[])
        .map((option) => option.toString())
        .where((option) => option.trim().isNotEmpty)
        .toList(growable: false);

    return QuizQuestion(
      id: doc.id,
      text: (data['text'] as String?)?.trim().isNotEmpty == true
          ? (data['text'] as String).trim()
          : 'Question text not available',
      options: rawOptions,
      points: (data['points'] as num?)?.toInt() ?? 1,
      correctOption: (data['correctOption'] as String?)?.trim() ?? '',
    );
  }
}

DateTime? _toDateTime(dynamic value) {
  if (value is Timestamp) {
    return value.toDate();
  }
  if (value is DateTime) {
    return value;
  }
  if (value is String) {
    return DateTime.tryParse(value);
  }
  return null;
}

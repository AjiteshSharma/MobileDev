import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:csv/csv.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../models/quiz_models.dart';
import '../services/quiz_service.dart';
import '../theme/app_theme.dart';
import '../utils/csv_exporter.dart';
import 'quiz_taking_screen.dart';

class TeacherQuizInsightsScreen extends StatefulWidget {
  const TeacherQuizInsightsScreen({super.key, required this.quiz});

  final QuizSummary quiz;

  @override
  State<TeacherQuizInsightsScreen> createState() =>
      _TeacherQuizInsightsScreenState();
}

class _TeacherQuizInsightsScreenState extends State<TeacherQuizInsightsScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final QuizService _quizService = const QuizService();
  late Future<_TeacherQuizInsightsData> _insightsFuture = _loadInsights();

  Future<_TeacherQuizInsightsData> _loadInsights() async {
    final questions = await _quizService.getQuizQuestions(widget.quiz.id);
    final questionById = <String, QuizQuestion>{
      for (final question in questions) question.id: question,
    };

    final totalPoints = questions.fold<int>(
      0,
      (current, q) => current + q.points,
    );
    final resolvedTotalPoints = totalPoints > 0
        ? totalPoints
        : widget.quiz.totalPoints;

    final attemptsSnapshot = await _db
        .collection('attempts')
        .where('quizId', isEqualTo: widget.quiz.id)
        .get();

    final violationEntries = await Future.wait(
      attemptsSnapshot.docs.map((attemptDoc) async {
        try {
          final violationSnapshot = await attemptDoc.reference
              .collection('violations')
              .orderBy('createdAt')
              .get();

          final events = violationSnapshot.docs
              .map((violationDoc) {
                final violationData = violationDoc.data();
                return _ViolationEvent(
                  violationNumber: (violationData['violationNumber'] as num?)
                      ?.toInt(),
                  type: (violationData['type'] as String?)?.trim() ?? '',
                  details: (violationData['details'] as String?)?.trim() ?? '',
                  createdAt: _toDateTime(violationData['createdAt']),
                );
              })
              .toList(growable: false);

          return MapEntry(attemptDoc.id, events);
        } catch (_) {
          return const MapEntry<String, List<_ViolationEvent>>(
            '',
            <_ViolationEvent>[],
          );
        }
      }),
    );

    final violationByAttempt = <String, List<_ViolationEvent>>{
      for (final entry in violationEntries)
        if (entry.key.isNotEmpty) entry.key: entry.value,
    };

    final uniqueStudentIds = attemptsSnapshot.docs
        .map((doc) => (doc.data()['studentId'] as String?)?.trim() ?? '')
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList(growable: false);

    final userSnapshots = await Future.wait(
      uniqueStudentIds.map((id) => _db.collection('users').doc(id).get()),
    );
    final userById = <String, Map<String, dynamic>>{
      for (final userSnap in userSnapshots) userSnap.id: userSnap.data() ?? {},
    };

    final attempts = <_AttemptInsight>[];
    for (final doc in attemptsSnapshot.docs) {
      final data = doc.data();
      final studentId = (data['studentId'] as String?)?.trim() ?? '';
      final profile = userById[studentId] ?? const <String, dynamic>{};
      final studentName = (profile['displayName'] as String?)?.trim() ?? '';
      final studentEmail = (profile['email'] as String?)?.trim() ?? '';

      final answers =
          (data['answers'] as Map<String, dynamic>? ?? <String, dynamic>{}).map(
            (key, value) => MapEntry(key, value.toString()),
          );

      var securedPoints = 0;
      var answeredCount = 0;
      var correctCount = 0;

      for (final entry in questionById.entries) {
        final selected = (answers[entry.key] ?? '').trim();
        if (selected.isEmpty) {
          continue;
        }

        answeredCount += 1;
        final isCorrect =
            _normalize(selected) == _normalize(entry.value.correctOption);
        if (isCorrect) {
          correctCount += 1;
          securedPoints += entry.value.points;
        }
      }

      final scorePercentage = resolvedTotalPoints <= 0
          ? 0.0
          : (securedPoints * 100) / resolvedTotalPoints;

      final rawStatus =
          (data['status'] as String?)?.trim().toLowerCase() ?? 'in_progress';
      final submittedAt = _toDateTime(data['submittedAt']);
      final updatedAt = _toDateTime(data['updatedAt']);
      final startedAt = _toDateTime(data['startedAt']);
      final violationCount = (data['violationCount'] as num?)?.toInt() ?? 0;
      final submitReason = (data['submitReason'] as String?)?.trim() ?? '';
      final explicitAuto = data['autoSubmitted'] == true;
      final inferredAuto =
          rawStatus == 'disqualified' ||
          submitReason.toLowerCase().contains('auto');
      final autoSubmitted = explicitAuto || inferredAuto;

      final isSubmitted =
          submittedAt != null ||
          rawStatus == 'submitted' ||
          rawStatus == 'flagged' ||
          rawStatus == 'disqualified';

      attempts.add(
        _AttemptInsight(
          attemptId: doc.id,
          studentId: studentId,
          studentName: studentName,
          studentEmail: studentEmail,
          status: rawStatus,
          securedPoints: securedPoints,
          scorePercentage: scorePercentage,
          violationCount: violationCount,
          autoSubmitted: autoSubmitted,
          submitReason: submitReason,
          submittedAt: submittedAt,
          sortKey: submittedAt ?? updatedAt ?? startedAt ?? DateTime(1970),
          isSubmitted: isSubmitted,
          answeredCount: answeredCount,
          correctCount: correctCount,
          violationEvents:
              violationByAttempt[doc.id] ?? const <_ViolationEvent>[],
        ),
      );
    }

    attempts.sort((a, b) => b.sortKey.compareTo(a.sortKey));

    var scoredAttempts = attempts
        .where((attempt) => attempt.isSubmitted)
        .toList(growable: false);
    if (scoredAttempts.isEmpty) {
      scoredAttempts = attempts;
    }

    final averageScore = scoredAttempts.isEmpty
        ? 0.0
        : scoredAttempts
                  .map((attempt) => attempt.scorePercentage)
                  .reduce((a, b) => a + b) /
              scoredAttempts.length;

    final highestScoreAttempt = scoredAttempts.isEmpty
        ? null
        : scoredAttempts.reduce(
            (left, right) =>
                left.scorePercentage >= right.scorePercentage ? left : right,
          );

    final lowestScoreAttempt = scoredAttempts.isEmpty
        ? null
        : scoredAttempts.reduce(
            (left, right) =>
                left.scorePercentage <= right.scorePercentage ? left : right,
          );

    return _TeacherQuizInsightsData(
      quiz: widget.quiz,
      questions: questions,
      totalPoints: resolvedTotalPoints,
      attempts: attempts,
      totalViolations: attempts.fold<int>(
        0,
        (current, attempt) => current + attempt.violationCount,
      ),
      autoSubmittedCount: attempts
          .where((attempt) => attempt.autoSubmitted)
          .length,
      averageScorePercentage: averageScore,
      highestScore: highestScoreAttempt == null
          ? null
          : _ScoreSummary(
              studentLabel: highestScoreAttempt.studentLabel,
              percentage: highestScoreAttempt.scorePercentage,
              securedPoints: highestScoreAttempt.securedPoints,
            ),
      lowestScore: lowestScoreAttempt == null
          ? null
          : _ScoreSummary(
              studentLabel: lowestScoreAttempt.studentLabel,
              percentage: lowestScoreAttempt.scorePercentage,
              securedPoints: lowestScoreAttempt.securedPoints,
            ),
    );
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

  String _normalize(String value) => value.trim().toLowerCase();

  String _formatDate(DateTime? value) {
    if (value == null) {
      return '-';
    }
    return DateFormat('dd MMM yyyy, hh:mm a').format(value.toLocal());
  }

  String _safeFileName(String raw) {
    final cleaned = raw
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    return cleaned.isEmpty ? widget.quiz.id : cleaned;
  }

  Future<void> _exportCsv(_TeacherQuizInsightsData data) async {
    final rows = <List<dynamic>>[
      <dynamic>['Quiz ID', widget.quiz.id],
      <dynamic>['Quiz Title', widget.quiz.title],
      <dynamic>['Subject', widget.quiz.subject],
      <dynamic>['Batch', widget.quiz.batch],
      <dynamic>['Total Questions', data.questions.length],
      <dynamic>['Total Points', data.totalPoints],
      <dynamic>[
        'Average Score %',
        data.averageScorePercentage.toStringAsFixed(2),
      ],
      <dynamic>[
        'Highest Score %',
        data.highestScore?.percentage.toStringAsFixed(2) ?? 'N/A',
      ],
      <dynamic>[
        'Lowest Score %',
        data.lowestScore?.percentage.toStringAsFixed(2) ?? 'N/A',
      ],
      <dynamic>['Total Violations', data.totalViolations],
      <dynamic>['Auto Submitted Attempts', data.autoSubmittedCount],
      <dynamic>[],
      <dynamic>[
        'Attempt ID',
        'Student Name',
        'Student Email',
        'Student ID',
        'Score Points',
        'Total Points',
        'Score %',
        'Answered',
        'Correct',
        'Violations',
        'Violation Timeline',
        'Auto Submitted',
        'Status',
        'Submitted At',
        'Submit Reason',
      ],
    ];

    for (final attempt in data.attempts) {
      rows.add(<dynamic>[
        attempt.attemptId,
        attempt.studentName,
        attempt.studentEmail,
        attempt.studentId,
        attempt.securedPoints,
        data.totalPoints,
        attempt.scorePercentage.toStringAsFixed(2),
        attempt.answeredCount,
        attempt.correctCount,
        attempt.violationCount,
        attempt.violationTimelineCsv,
        attempt.autoSubmitted ? 'Yes' : 'No',
        attempt.status.toUpperCase(),
        _formatDate(attempt.submittedAt),
        attempt.submitReason,
      ]);
    }

    final csv = const ListToCsvConverter().convert(rows);
    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final fileName =
        '${_safeFileName(widget.quiz.title)}_insights_$timestamp.csv';

    final result = await exportCsvFile(fileName: fileName, csvContent: csv);
    if (!mounted) {
      return;
    }

    _showSnack(result.message);
  }

  void _showSnack(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _openInteractivePreview() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => QuizTakingScreen(
          quizId: widget.quiz.id,
          quizTitle: widget.quiz.title,
          durationMinutes: widget.quiz.durationMinutes,
        ),
      ),
    );
  }

  void _refresh() {
    setState(() {
      _insightsFuture = _loadInsights();
    });
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final statusLabel = widget.quiz.isPastAt(now)
        ? 'Completed'
        : (widget.quiz.isActiveAt(now) ? 'Active' : 'Upcoming');

    return Scaffold(
      backgroundColor: AppTheme.midnight,
      body: FutureBuilder<_TeacherQuizInsightsData>(
        future: _insightsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Failed to load quiz insights.\n${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final data = snapshot.data;
          if (data == null) {
            return const Center(child: Text('No insights available.'));
          }
          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: const BoxDecoration(
                          color: AppTheme.panelSoft,
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          icon: const Icon(LucideIcons.arrowLeft, size: 16),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Statistics',
                        style: TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: _refresh,
                        icon: const Icon(LucideIcons.refreshCw),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _MetricCard(
                        title: 'Students',
                        value: data.attempts.length.toString(),
                        subtitle: 'attempt records',
                        color: AppTheme.coral,
                      ),
                      _MetricCard(
                        title: 'Auto Submitted',
                        value: data.autoSubmittedCount.toString(),
                        subtitle: 'submissions',
                        color: const Color(0xFFF2C062),
                      ),
                      _MetricCard(
                        title: 'Highest',
                        value: data.highestScore == null
                            ? 'N/A'
                            : '${data.highestScore!.percentage.toStringAsFixed(1)}%',
                        subtitle:
                            data.highestScore?.studentLabel ?? 'No attempts',
                        color: const Color(0xFF7FD08A),
                      ),
                      _MetricCard(
                        title: 'Lowest',
                        value: data.lowestScore == null
                            ? 'N/A'
                            : '${data.lowestScore!.percentage.toStringAsFixed(1)}%',
                        subtitle:
                            data.lowestScore?.studentLabel ?? 'No attempts',
                        color: const Color(0xFFE58AA3),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.panelSoft,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Text(
                              statusLabel.toUpperCase(),
                              style: const TextStyle(
                                color: AppTheme.coral,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          OutlinedButton.icon(
                            onPressed: _openInteractivePreview,
                            icon: const Icon(LucideIcons.eye, size: 17),
                            label: const Text('Preview Quiz'),
                          ),
                          ElevatedButton.icon(
                            onPressed: () => _exportCsv(data),
                            icon: const Icon(
                              LucideIcons.download,
                              color: Colors.white,
                              size: 17,
                            ),
                            label: const Text(
                              'Export CSV',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Student Performance',
                    style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  if (data.attempts.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Text(
                          'No student attempts found for this quiz yet.',
                        ),
                      ),
                    )
                  else
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            headingRowColor: WidgetStateProperty.resolveWith(
                              (_) => AppTheme.panelSoft,
                            ),
                            columns: const [
                              DataColumn(label: Text('Student')),
                              DataColumn(label: Text('Email')),
                              DataColumn(label: Text('Score')),
                              DataColumn(label: Text('Violations')),
                              DataColumn(label: Text('Auto')),
                              DataColumn(label: Text('Status')),
                              DataColumn(label: Text('Submitted')),
                            ],
                            rows: data.attempts
                                .map((attempt) {
                                  return DataRow(
                                    cells: [
                                      DataCell(Text(attempt.studentLabel)),
                                      DataCell(
                                        Text(
                                          attempt.studentEmail.isEmpty
                                              ? '-'
                                              : attempt.studentEmail,
                                        ),
                                      ),
                                      DataCell(
                                        Text(
                                          '${attempt.securedPoints}/${data.totalPoints} (${attempt.scorePercentage.toStringAsFixed(1)}%)',
                                        ),
                                      ),
                                      DataCell(
                                        Text('${attempt.violationCount}'),
                                      ),
                                      DataCell(
                                        Text(
                                          attempt.autoSubmitted ? 'Yes' : 'No',
                                          style: TextStyle(
                                            color: attempt.autoSubmitted
                                                ? Colors.red
                                                : Colors.green,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                      DataCell(
                                        Text(attempt.status.toUpperCase()),
                                      ),
                                      DataCell(
                                        Text(_formatDate(attempt.submittedAt)),
                                      ),
                                    ],
                                  );
                                })
                                .toList(growable: false),
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),
                  const Text(
                    'Question Bank',
                    style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  if (data.questions.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('No questions found in this quiz.'),
                      ),
                    )
                  else
                    Card(
                      child: ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: data.questions.length,
                        separatorBuilder: (_, index) =>
                            const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final question = data.questions[index];
                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            title: Text(
                              '${index + 1}. ${question.text}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  ...question.options.asMap().entries.map((
                                    entry,
                                  ) {
                                    final optionPrefix = String.fromCharCode(
                                      (65 + entry.key).clamp(65, 90),
                                    );
                                    final isCorrect =
                                        _normalize(entry.value) ==
                                        _normalize(question.correctOption);
                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: 2),
                                      child: Text(
                                        '$optionPrefix. ${entry.value}${isCorrect ? '  (Correct)' : ''}',
                                        style: TextStyle(
                                          color: isCorrect
                                              ? const Color(0xFF15803D)
                                              : AppTheme.textMuted,
                                          fontWeight: isCorrect
                                              ? FontWeight.w600
                                              : FontWeight.w400,
                                        ),
                                      ),
                                    );
                                  }),
                                ],
                              ),
                            ),
                            trailing: Text('${question.points} pts'),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.color,
  });

  final String title;
  final String value;
  final String subtitle;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final cardWidth = width > 430 ? (width - 58) / 2 : width - 36;

    return SizedBox(
      width: cardWidth,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
              ),
              const SizedBox(height: 8),
              Text(
                value,
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TeacherQuizInsightsData {
  const _TeacherQuizInsightsData({
    required this.quiz,
    required this.questions,
    required this.totalPoints,
    required this.attempts,
    required this.totalViolations,
    required this.autoSubmittedCount,
    required this.averageScorePercentage,
    required this.highestScore,
    required this.lowestScore,
  });

  final QuizSummary quiz;
  final List<QuizQuestion> questions;
  final int totalPoints;
  final List<_AttemptInsight> attempts;
  final int totalViolations;
  final int autoSubmittedCount;
  final double averageScorePercentage;
  final _ScoreSummary? highestScore;
  final _ScoreSummary? lowestScore;
}

class _AttemptInsight {
  const _AttemptInsight({
    required this.attemptId,
    required this.studentId,
    required this.studentName,
    required this.studentEmail,
    required this.status,
    required this.securedPoints,
    required this.scorePercentage,
    required this.violationCount,
    required this.autoSubmitted,
    required this.submitReason,
    required this.submittedAt,
    required this.sortKey,
    required this.isSubmitted,
    required this.answeredCount,
    required this.correctCount,
    required this.violationEvents,
  });

  final String attemptId;
  final String studentId;
  final String studentName;
  final String studentEmail;
  final String status;
  final int securedPoints;
  final double scorePercentage;
  final int violationCount;
  final bool autoSubmitted;
  final String submitReason;
  final DateTime? submittedAt;
  final DateTime sortKey;
  final bool isSubmitted;
  final int answeredCount;
  final int correctCount;
  final List<_ViolationEvent> violationEvents;

  String get studentLabel {
    if (studentName.isNotEmpty) {
      return studentName;
    }
    if (studentEmail.isNotEmpty) {
      return studentEmail;
    }
    return studentId.isEmpty ? 'Unknown Student' : studentId;
  }

  String get violationTimelineCsv {
    if (violationEvents.isEmpty) {
      return '-';
    }

    return violationEvents
        .map((event) {
          final numberPrefix = event.violationNumber == null
              ? ''
              : '#${event.violationNumber} ';
          final when = event.createdAt == null
              ? 'Unknown time'
              : DateFormat(
                  'dd MMM yyyy, hh:mm:ss a',
                ).format(event.createdAt!.toLocal());
          final typeLabel = event.type.isEmpty ? 'unknown' : event.type;
          final detailsSuffix = event.details.isEmpty
              ? ''
              : ' (${event.details})';
          return '$numberPrefix$when - $typeLabel$detailsSuffix';
        })
        .join(' | ');
  }
}

class _ScoreSummary {
  const _ScoreSummary({
    required this.studentLabel,
    required this.percentage,
    required this.securedPoints,
  });

  final String studentLabel;
  final double percentage;
  final int securedPoints;
}

class _ViolationEvent {
  const _ViolationEvent({
    required this.violationNumber,
    required this.type,
    required this.details,
    required this.createdAt,
  });

  final int? violationNumber;
  final String type;
  final String details;
  final DateTime? createdAt;
}

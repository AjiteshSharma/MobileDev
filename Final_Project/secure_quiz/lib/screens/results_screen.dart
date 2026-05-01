import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../models/quiz_models.dart';
import '../services/quiz_service.dart';

class ResultsScreen extends StatefulWidget {
  const ResultsScreen({super.key, this.attemptId, this.quizId, this.quizTitle});

  final String? attemptId;
  final String? quizId;
  final String? quizTitle;

  @override
  State<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends State<ResultsScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final QuizService _quizService = const QuizService();
  late final Future<_LiveResultData> _resultFuture = _loadResultData();

  Future<_LiveResultData> _loadResultData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw StateError('No active session. Please sign in again.');
    }

    final attemptSnap = await _resolveAttemptSnapshot(user.uid);
    if (attemptSnap == null || !attemptSnap.exists) {
      throw StateError('No attempt found yet for this account.');
    }

    final attemptData = attemptSnap.data() ?? const <String, dynamic>{};
    final resolvedQuizId =
        widget.quizId ?? (attemptData['quizId'] as String?)?.trim() ?? '';
    if (resolvedQuizId.isEmpty) {
      throw StateError('Attempt is missing quiz reference.');
    }

    final quizSnap = await _db.collection('quizzes').doc(resolvedQuizId).get();
    final quizData = quizSnap.data() ?? const <String, dynamic>{};
    final questions = await _quizService.getQuizQuestions(resolvedQuizId);

    final answers =
        (attemptData['answers'] as Map<String, dynamic>? ??
                const <String, dynamic>{})
            .map((key, value) => MapEntry(key, value.toString()));

    final questionResults = <_QuestionResult>[];
    var totalPoints = 0;
    var pointsSecured = 0;
    var correctCount = 0;
    var incorrectCount = 0;
    var unansweredCount = 0;

    for (final question in questions) {
      totalPoints += question.points;
      final selected = answers[question.id];

      if (selected == null || selected.trim().isEmpty) {
        unansweredCount += 1;
        questionResults.add(
          _QuestionResult(
            question: question,
            selectedOption: '',
            isCorrect: false,
            isAnswered: false,
          ),
        );
        continue;
      }

      final isCorrect =
          _normalize(selected) == _normalize(question.correctOption);
      if (isCorrect) {
        correctCount += 1;
        pointsSecured += question.points;
      } else {
        incorrectCount += 1;
      }

      questionResults.add(
        _QuestionResult(
          question: question,
          selectedOption: selected,
          isCorrect: isCorrect,
          isAnswered: true,
        ),
      );
    }

    if (totalPoints == 0) {
      totalPoints = (quizData['totalPoints'] as num?)?.toInt() ?? 0;
    }

    final percentage = totalPoints <= 0
        ? 0
        : ((pointsSecured * 100) / totalPoints).round();

    final status = ((attemptData['status'] as String?) ?? 'submitted')
        .toUpperCase();
    final violationCount =
        (attemptData['violationCount'] as num?)?.toInt() ?? 0;
    final title = widget.quizTitle?.trim().isNotEmpty == true
        ? widget.quizTitle!.trim()
        : ((quizData['title'] as String?)?.trim().isNotEmpty == true
              ? (quizData['title'] as String).trim()
              : 'Quiz Result');

    return _LiveResultData(
      attemptId: attemptSnap.id,
      quizId: resolvedQuizId,
      title: title,
      status: status,
      percentage: percentage,
      pointsSecured: pointsSecured,
      totalPoints: totalPoints,
      correctCount: correctCount,
      incorrectCount: incorrectCount,
      unansweredCount: unansweredCount,
      totalQuestions: questions.length,
      violationCount: violationCount,
      questionResults: questionResults,
    );
  }

  Future<DocumentSnapshot<Map<String, dynamic>>?> _resolveAttemptSnapshot(
    String uid,
  ) async {
    if ((widget.attemptId ?? '').trim().isNotEmpty) {
      return _db.collection('attempts').doc(widget.attemptId!.trim()).get();
    }

    final requestedQuizId = (widget.quizId ?? '').trim();
    if (requestedQuizId.isNotEmpty) {
      // Primary lookup: canonical attempt id pattern used by AttemptService.
      final directId = '${requestedQuizId}_$uid';
      final directSnap = await _db.collection('attempts').doc(directId).get();
      if (directSnap.exists) {
        return directSnap;
      }

      // Fallback lookup: any attempt document for this quiz + student.
      final quizAttempts = await _db
          .collection('attempts')
          .where('studentId', isEqualTo: uid)
          .where('quizId', isEqualTo: requestedQuizId)
          .get();

      if (quizAttempts.docs.isNotEmpty) {
        final sortedQuizAttempts = quizAttempts.docs.toList(growable: false)
          ..sort(
            (a, b) => _sortKeyForAttempt(
              b.data(),
            ).compareTo(_sortKeyForAttempt(a.data())),
          );
        return sortedQuizAttempts.first;
      }
    }

    final snapshot = await _db
        .collection('attempts')
        .where('studentId', isEqualTo: uid)
        .get();

    if (snapshot.docs.isEmpty) {
      return null;
    }

    final sorted = snapshot.docs.toList(growable: false)
      ..sort(
        (a, b) => _sortKeyForAttempt(
          b.data(),
        ).compareTo(_sortKeyForAttempt(a.data())),
      );

    return sorted.first;
  }

  DateTime _sortKeyForAttempt(Map<String, dynamic> data) {
    return _toDateTime(data['submittedAt']) ??
        _toDateTime(data['updatedAt']) ??
        _toDateTime(data['startedAt']) ??
        DateTime.fromMillisecondsSinceEpoch(0);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FF),
      appBar: AppBar(
        title: const Text('EduAssess'),
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: FutureBuilder<_LiveResultData>(
        future: _resultFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Failed to load result: ${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final result = snapshot.data;
          if (result == null) {
            return const Center(child: Text('No result available.'));
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'Assessment Completed',
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _StatusPill(status: result.status),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  result.title,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 24),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'FINAL SCORE',
                                  style: TextStyle(
                                    color: Colors.grey,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Row(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.baseline,
                                  textBaseline: TextBaseline.alphabetic,
                                  children: [
                                    Text(
                                      '${result.percentage}',
                                      style: TextStyle(
                                        fontSize: 72,
                                        fontWeight: FontWeight.w900,
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.primary,
                                      ),
                                    ),
                                    Text(
                                      '%',
                                      style: TextStyle(
                                        fontSize: 28,
                                        fontWeight: FontWeight.bold,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary
                                            .withValues(alpha: 0.5),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(width: 40),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'POINTS SECURED',
                                  style: TextStyle(
                                    color: Colors.grey,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '${result.pointsSecured} / ${result.totalPoints}',
                                  style: const TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'Violations: ${result.violationCount}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.black54,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const Divider(height: 28),
                        Wrap(
                          spacing: 24,
                          runSpacing: 10,
                          children: [
                            _summaryItem(
                              icon: LucideIcons.checkCircle,
                              color: Colors.green,
                              label: 'Correct',
                              value: '${result.correctCount} Questions',
                            ),
                            _summaryItem(
                              icon: LucideIcons.xCircle,
                              color: Colors.red,
                              label: 'Incorrect',
                              value: '${result.incorrectCount} Questions',
                            ),
                            _summaryItem(
                              icon: LucideIcons.helpCircle,
                              color: Colors.orange,
                              label: 'Unanswered',
                              value: '${result.unansweredCount} Questions',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Attempt ID: ${result.attemptId}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.black54,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Quiz ID: ${result.quizId}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.black54,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Questions: ${result.totalQuestions}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () => _showAnswerReview(result),
                  icon: const Icon(LucideIcons.fileText, color: Colors.white),
                  label: const Text(
                    'Review Answers',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    minimumSize: const Size(double.infinity, 52),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _summaryItem({
    required IconData icon,
    required Color color,
    required String label,
    required String value,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
      ],
    );
  }

  Future<void> _showAnswerReview(_LiveResultData result) async {
    if (!mounted) {
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SizedBox(
          height: MediaQuery.of(context).size.height * 0.8,
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: result.questionResults.length,
            separatorBuilder: (_, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final item = result.questionResults[index];
              final selectedText = item.isAnswered
                  ? item.selectedOption
                  : 'Not answered';
              final answerColor = !item.isAnswered
                  ? Colors.orange
                  : (item.isCorrect ? Colors.green : Colors.red);

              return ListTile(
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
                title: Text(
                  '${index + 1}. ${item.question.text}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Your answer: $selectedText',
                        style: TextStyle(color: answerColor),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Correct answer: ${item.question.correctOption.isEmpty ? 'N/A' : item.question.correctOption}',
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (status) {
      'SUBMITTED' => (const Color(0xFFDDF4E1), const Color(0xFF2E7D32)),
      'FLAGGED' => (const Color(0xFFFFF3CD), const Color(0xFF8A6D3B)),
      'DISQUALIFIED' => (const Color(0xFFFFE2E2), const Color(0xFFB71C1C)),
      _ => (const Color(0xFFE2E8F0), const Color(0xFF334155)),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: fg,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _LiveResultData {
  const _LiveResultData({
    required this.attemptId,
    required this.quizId,
    required this.title,
    required this.status,
    required this.percentage,
    required this.pointsSecured,
    required this.totalPoints,
    required this.correctCount,
    required this.incorrectCount,
    required this.unansweredCount,
    required this.totalQuestions,
    required this.violationCount,
    required this.questionResults,
  });

  final String attemptId;
  final String quizId;
  final String title;
  final String status;
  final int percentage;
  final int pointsSecured;
  final int totalPoints;
  final int correctCount;
  final int incorrectCount;
  final int unansweredCount;
  final int totalQuestions;
  final int violationCount;
  final List<_QuestionResult> questionResults;
}

class _QuestionResult {
  const _QuestionResult({
    required this.question,
    required this.selectedOption,
    required this.isCorrect,
    required this.isAnswered,
  });

  final QuizQuestion question;
  final String selectedOption;
  final bool isCorrect;
  final bool isAnswered;
}

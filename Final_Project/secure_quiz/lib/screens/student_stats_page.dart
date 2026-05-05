import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../models/app_role.dart';
import '../models/quiz_models.dart';
import '../services/auth_service.dart';
import '../services/quiz_service.dart';
import '../theme/app_theme.dart';
import '../widgets/press_scale.dart';
import 'quiz_taking_screen.dart';
import 'results_screen.dart';

enum _StudentQuizFilterTab { active, upcoming, completed, all }

class StudentStatisticsScreen extends StatefulWidget {
  const StudentStatisticsScreen({super.key});

  @override
  State<StudentStatisticsScreen> createState() =>
      _StudentStatisticsScreenState();
}

class _StudentStatisticsScreenState extends State<StudentStatisticsScreen> {
  final QuizService _quizService = const QuizService();
  _StudentQuizFilterTab? _selectedTab = _StudentQuizFilterTab.active;

  @override
  Widget build(BuildContext context) {
    final student = FirebaseAuth.instance.currentUser;
    if (student == null) {
      return const _NoSessionScaffold();
    }

    return Scaffold(
      backgroundColor: AppTheme.midnight,
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: const AuthService().watchUserProfile(student.uid),
        builder: (context, profileSnapshot) {
          if (profileSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (profileSnapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Failed to load profile.\n${profileSnapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final profile =
              profileSnapshot.data?.data() ?? const <String, dynamic>{};
          final role = appRoleFromDynamic(profile['role']);
          if (role != AppRole.student) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('Student profile not configured for this account.'),
              ),
            );
          }

          final studentBatch = (profile['batch'] as String?)?.trim() ?? '';
          if (studentBatch.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Batch is not assigned to this student account.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          return StreamBuilder<List<QuizSummary>>(
            stream: _quizService.streamStudentQuizzes(batch: studentBatch),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'Failed to load assessments.\n${snapshot.error}',
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }

              final allQuizzes = (snapshot.data ?? const <QuizSummary>[])
                  .where((quiz) => quiz.status == 'ready')
                  .toList(growable: false);
              final now = DateTime.now();
              final selectedTab = _selectedTab ?? _StudentQuizFilterTab.active;
              final filteredQuizzes = _filterQuizzes(
                quizzes: allQuizzes,
                now: now,
                tab: selectedTab,
              );

              return SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          PressScale(
                            onTap: () => Navigator.pop(context),
                            child: Container(
                              width: 38,
                              height: 38,
                              decoration: const BoxDecoration(
                                color: AppTheme.panelSoft,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                LucideIcons.arrowLeft,
                                size: 18,
                                color: AppTheme.textPrimary,
                              ),
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
                          Container(
                            width: 38,
                            height: 38,
                            decoration: const BoxDecoration(
                              color: AppTheme.panelSoft,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              LucideIcons.user,
                              size: 18,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      const SizedBox(height: 8),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildTab('Active', _StudentQuizFilterTab.active),
                            _buildTab(
                              'Upcoming',
                              _StudentQuizFilterTab.upcoming,
                            ),
                            _buildTab(
                              'Completed',
                              _StudentQuizFilterTab.completed,
                            ),
                            _buildTab('All', _StudentQuizFilterTab.all),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      if (allQuizzes.isEmpty)
                        const _EmptyCard(
                          message:
                              'No quizzes found yet. Your assigned quizzes will appear here.',
                        )
                      else if (filteredQuizzes.isEmpty)
                        _EmptyCard(
                          message: 'No quizzes in ${_tabLabel(selectedTab)}.',
                        )
                      else
                        ...filteredQuizzes.map(
                          (quiz) => _StudentStatisticsQuizCard(
                            quiz: quiz,
                            status: _statusForQuiz(quiz, now),
                            schedule: _scheduleLabel(quiz, now),
                            onTap: () => _openQuizForStudent(
                              context: context,
                              studentId: student.uid,
                              quiz: quiz,
                              now: now,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildTab(String label, _StudentQuizFilterTab tab) {
    final isSelected = (_selectedTab ?? _StudentQuizFilterTab.active) == tab;
    return PressScale(
      onTap: () => setState(() => _selectedTab = tab),
      child: Container(
        margin: const EdgeInsets.only(right: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.coral : AppTheme.panelSoft,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? Colors.transparent : AppTheme.stroke,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : AppTheme.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  List<QuizSummary> _filterQuizzes({
    required List<QuizSummary> quizzes,
    required DateTime now,
    required _StudentQuizFilterTab tab,
  }) {
    switch (tab) {
      case _StudentQuizFilterTab.active:
        return quizzes.where((quiz) => quiz.isActiveAt(now)).toList();
      case _StudentQuizFilterTab.upcoming:
        return quizzes.where((quiz) => quiz.isUpcomingAt(now)).toList();
      case _StudentQuizFilterTab.completed:
        return quizzes.where((quiz) => quiz.isPastAt(now)).toList();
      case _StudentQuizFilterTab.all:
        return quizzes;
    }
  }

  String _statusForQuiz(QuizSummary quiz, DateTime now) {
    if (quiz.status == 'processing') {
      return 'PROCESSING';
    }
    if (quiz.status == 'error') {
      return 'ERROR';
    }
    if (quiz.isActiveAt(now)) {
      return 'ACTIVE';
    }
    if (quiz.isUpcomingAt(now)) {
      return 'UPCOMING';
    }
    return 'COMPLETED';
  }

  String _scheduleLabel(QuizSummary quiz, DateTime now) {
    final formatter = DateFormat('dd MMM yyyy, hh:mm a');

    if (quiz.status == 'processing') {
      return 'Parsing questions...';
    }
    if (quiz.status == 'error') {
      return 'Failed to parse sheet';
    }
    if (quiz.isUpcomingAt(now)) {
      return 'Starts: ${formatter.format(quiz.startAt)}';
    }
    if (quiz.isActiveAt(now)) {
      return 'Ends: ${formatter.format(quiz.endAt)}';
    }
    return 'Ended: ${formatter.format(quiz.endAt)}';
  }

  String _tabLabel(_StudentQuizFilterTab tab) {
    switch (tab) {
      case _StudentQuizFilterTab.active:
        return 'Active';
      case _StudentQuizFilterTab.upcoming:
        return 'Upcoming';
      case _StudentQuizFilterTab.completed:
        return 'Completed';
      case _StudentQuizFilterTab.all:
        return 'All';
    }
  }

  void _openQuizForStudent({
    required BuildContext context,
    required String studentId,
    required QuizSummary quiz,
    required DateTime now,
  }) {
    if (quiz.isActiveAt(now)) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => QuizTakingScreen(
            quizId: quiz.id,
            quizTitle: quiz.title,
            durationMinutes: quiz.durationMinutes,
          ),
        ),
      );
      return;
    }

    if (quiz.isPastAt(now)) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ResultsScreen(
            attemptId: '${quiz.id}_$studentId',
            quizId: quiz.id,
            quizTitle: quiz.title,
          ),
        ),
      );
    }
  }
}

class _StudentStatisticsQuizCard extends StatelessWidget {
  const _StudentStatisticsQuizCard({
    required this.quiz,
    required this.status,
    required this.schedule,
    required this.onTap,
  });

  final QuizSummary quiz;
  final String status;
  final String schedule;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final statusColor = switch (status) {
      'ACTIVE' => Colors.green,
      'UPCOMING' => const Color(0xFF8AA3E6),
      'PROCESSING' => const Color(0xFFF2C062),
      'ERROR' => Colors.red,
      _ => AppTheme.textMuted,
    };

    return PressScale(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: AppTheme.panel,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppTheme.stroke),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    status,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
                const Spacer(),
                const Icon(
                  LucideIcons.chevronRight,
                  size: 16,
                  color: AppTheme.textMuted,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              quiz.title,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 5),
            Text(
              '${quiz.subject} - ${quiz.batch} - ${quiz.totalQuestions} questions',
              style: const TextStyle(color: AppTheme.textMuted, fontSize: 13),
            ),
            const SizedBox(height: 5),
            Text(
              schedule,
              style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.panel,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.stroke),
      ),
      child: Text(message, style: const TextStyle(color: AppTheme.textMuted)),
    );
  }
}

class _NoSessionScaffold extends StatelessWidget {
  const _NoSessionScaffold();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ElevatedButton(
          onPressed: () => Navigator.pushReplacementNamed(context, '/login'),
          child: const Text('Sign in again'),
        ),
      ),
    );
  }
}

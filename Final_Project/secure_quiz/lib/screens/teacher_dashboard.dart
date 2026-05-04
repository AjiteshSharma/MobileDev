import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../models/quiz_models.dart';
import '../services/auth_service.dart';
import '../services/quiz_service.dart';
import '../theme/app_theme.dart';
import '../widgets/press_scale.dart';
import 'teacher_quiz_insights_screen.dart';

class TeacherDashboard extends StatelessWidget {
  const TeacherDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final teacher = FirebaseAuth.instance.currentUser;
    if (teacher == null) {
      return const _NoSessionScaffold();
    }

    final quizService = const QuizService();

    return Scaffold(
      backgroundColor: AppTheme.midnight,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.pushNamed(context, '/create-quiz'),
        child: const Icon(LucideIcons.plus, color: Colors.white),
      ),
      body: StreamBuilder<List<QuizSummary>>(
        stream: quizService.streamTeacherQuizzes(teacher.uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text('Failed to load quizzes: ${snapshot.error}'),
            );
          }

          final quizzes = snapshot.data ?? const <QuizSummary>[];
          final now = DateTime.now();
          final readyQuizzes = quizzes
              .where((quiz) => quiz.status == 'ready')
              .toList(growable: false);
          final activeQuizzes = readyQuizzes
              .where((quiz) => quiz.isActiveAt(now))
              .toList(growable: false);
          final upcomingQuizzes = readyQuizzes
              .where((quiz) => quiz.isUpcomingAt(now))
              .toList(growable: false);
          final completedQuizzes = readyQuizzes
              .where((quiz) => quiz.isPastAt(now))
              .take(5)
              .toList(growable: false);

          Widget sectionHeader(String label) {
            return Padding(
              padding: const EdgeInsets.only(top: 16, bottom: 8),
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
            );
          }

          List<Widget> buildQuizCards({
            required List<QuizSummary> items,
            required String status,
            required String emptyMessage,
          }) {
            if (items.isEmpty) {
              return [
                const SizedBox(height: 2),
                _EmptyCard(message: emptyMessage),
              ];
            }

            return items
                .map(
                  (quiz) => _TeacherQuizCard(
                    quiz: quiz,
                    status: status,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => TeacherQuizInsightsScreen(quiz: quiz),
                        ),
                      );
                    },
                  ),
                )
                .toList(growable: false);
          }

          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 94),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _HeaderBar(
                    dateLabel: DateFormat('MMMM d').format(now),
                    onManageTap: () =>
                        Navigator.pushNamed(context, '/manage-quizzes'),
                    onSignOutTap: () => const AuthService().signOut(),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'My quizzes',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (activeQuizzes.isEmpty &&
                      upcomingQuizzes.isEmpty &&
                      completedQuizzes.isEmpty)
                    const _EmptyCard(
                      message: 'No quizzes yet. Tap + to upload a new quiz.',
                    )
                  else ...[
                    sectionHeader('Active (${activeQuizzes.length})'),
                    ...buildQuizCards(
                      items: activeQuizzes,
                      status: 'ACTIVE',
                      emptyMessage: 'No active quizzes right now.',
                    ),
                    sectionHeader('Upcoming (${upcomingQuizzes.length})'),
                    ...buildQuizCards(
                      items: upcomingQuizzes,
                      status: 'UPCOMING',
                      emptyMessage: 'No upcoming quizzes right now.',
                    ),
                    sectionHeader('Completed '),
                    ...buildQuizCards(
                      items: completedQuizzes,
                      status: 'COMPLETED',
                      emptyMessage: 'No completed quizzes yet.',
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _HeaderBar extends StatelessWidget {
  const _HeaderBar({
    required this.dateLabel,
    required this.onManageTap,
    required this.onSignOutTap,
  });

  final String dateLabel;
  final VoidCallback onManageTap;
  final VoidCallback onSignOutTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Text(
          'Today,',
          style: TextStyle(fontSize: 34, fontWeight: FontWeight.w700),
        ),
        const SizedBox(width: 8),
        Text(
          dateLabel,
          style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w800),
        ),
        const Spacer(),
        _RoundIconButton(icon: LucideIcons.layers, onTap: onManageTap),
        const SizedBox(width: 8),
        _RoundIconButton(icon: LucideIcons.logOut, onTap: onSignOutTap),
      ],
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PressScale(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: const BoxDecoration(
          color: AppTheme.panelSoft,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 18, color: AppTheme.textPrimary),
      ),
    );
  }
}

class _TeacherQuizCard extends StatelessWidget {
  const _TeacherQuizCard({
    required this.quiz,
    required this.status,
    required this.onTap,
  });

  final QuizSummary quiz;
  final String status;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheduleLabel = switch (status) {
      'ACTIVE' => 'Ends ${DateFormat('dd MMM, hh:mm a').format(quiz.endAt)}',
      'COMPLETED' =>
        'Ended ${DateFormat('dd MMM, hh:mm a').format(quiz.endAt)}',
      _ => 'Starts ${DateFormat('dd MMM, hh:mm a').format(quiz.startAt)}',
    };

    final statusColor = switch (status) {
      'ACTIVE' => Colors.green,
      'UPCOMING' => const Color(0xFF8AA3E6),
      'PROCESSING' => const Color(0xFFF2C062),
      'ERROR' => Colors.red,
      _ => AppTheme.textMuted,
    };

    return PressScale(
      onTap: null,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
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
                    Expanded(
                      child: Text(
                        quiz.title,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        status,
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.9,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  '${quiz.subject} - ${quiz.batch}',
                  style: const TextStyle(
                    color: AppTheme.textMuted,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  scheduleLabel,
                  style: const TextStyle(
                    color: AppTheme.textMuted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
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

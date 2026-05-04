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
import '../widgets/fade_slide_in.dart';
import '../widgets/press_scale.dart';
import 'quiz_taking_screen.dart';
import 'results_screen.dart';

class StudentDashboard extends StatelessWidget {
  const StudentDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final student = FirebaseAuth.instance.currentUser;
    if (student == null) {
      return const _NoSessionScaffold();
    }

    final quizService = const QuizService();

    return Scaffold(
      backgroundColor: AppTheme.midnight,
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: const AuthService().watchUserProfile(student.uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text('Failed to load profile: ${snapshot.error}'),
            );
          }

          final profile = snapshot.data?.data() ?? const <String, dynamic>{};
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
          final studentBatchLabel =
              ((profile['batchLabel'] as String?)?.trim().isNotEmpty == true
              ? (profile['batchLabel'] as String).trim()
              : studentBatch);

          if (studentBatch.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Batch is not assigned to this student account. Contact your teacher/admin.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          return StreamBuilder<List<QuizSummary>>(
            stream: quizService.streamStudentQuizzes(batch: studentBatch),
            builder: (context, quizSnapshot) {
              if (quizSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (quizSnapshot.hasError) {
                return Center(
                  child: Text('Failed to load quizzes: ${quizSnapshot.error}'),
                );
              }

              final quizzes = quizSnapshot.data ?? const <QuizSummary>[];
              final now = DateTime.now();

              final active = quizzes
                  .where(
                    (quiz) => quiz.status == 'ready' && quiz.isActiveAt(now),
                  )
                  .toList(growable: false);
              final upcoming = quizzes
                  .where(
                    (quiz) => quiz.status == 'ready' && quiz.isUpcomingAt(now),
                  )
                  .toList(growable: false);
              final past = quizzes
                  .where((quiz) => quiz.status == 'ready' && quiz.isPastAt(now))
                  .toList(growable: false);

              return SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _HeaderBar(
                        rightLabel: DateFormat('MMMM d').format(now),
                        onStatsTap: () =>
                            Navigator.pushNamed(context, '/results'),
                        onProfileTap: () => const AuthService().signOut(),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Batch: $studentBatchLabel',
                        style: const TextStyle(
                          color: AppTheme.textMuted,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        'My quizzes',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (active.isEmpty && upcoming.isEmpty)
                        const _EmptyCard(
                          message: 'No active or upcoming quiz right now.',
                        )
                      else ...[
                        ...active.asMap().entries.map((entry) {
                          final index = entry.key;
                          final quiz = entry.value;
                          return _QuizHabitCard(
                            quiz: quiz,
                            statusLabel: 'ACTIVE',
                            statusColor: Colors.green,
                            animationDelay: Duration(
                              milliseconds: 60 + (index * 35),
                            ),
                            actionLabel: 'Start',
                            onActionTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => QuizTakingScreen(
                                    quizId: quiz.id,
                                    quizTitle: quiz.title,
                                    durationMinutes: quiz.durationMinutes,
                                  ),
                                ),
                              );
                            },
                          );
                        }),
                        ...upcoming.asMap().entries.map((entry) {
                          final index = entry.key;
                          final quiz = entry.value;
                          return _QuizHabitCard(
                            quiz: quiz,
                            statusLabel: 'UPCOMING',
                            statusColor: const Color(0xFF8AA3E6),
                            animationDelay: Duration(
                              milliseconds: 120 + (index * 35),
                            ),
                            actionLabel: 'Scheduled',
                            onActionTap: null,
                          );
                        }),
                      ],
                      const SizedBox(height: 24),
                      const Text(
                        'Past attempts',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (past.isEmpty)
                        const _EmptyCard(message: 'No completed quizzes yet.')
                      else
                        ...past
                            .take(6)
                            .map(
                              (quiz) => PressScale(
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => ResultsScreen(
                                      attemptId: '${quiz.id}_${student.uid}',
                                      quizId: quiz.id,
                                      quizTitle: quiz.title,
                                    ),
                                  ),
                                ),
                                child: Container(
                                  margin: const EdgeInsets.only(bottom: 10),
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: AppTheme.panel,
                                    borderRadius: BorderRadius.circular(18),
                                    border: Border.all(color: AppTheme.stroke),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        LucideIcons.history,
                                        size: 18,
                                        color: AppTheme.textMuted,
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          quiz.title,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        DateFormat('dd MMM').format(quiz.endAt),
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
}

class _HeaderBar extends StatelessWidget {
  const _HeaderBar({
    required this.rightLabel,
    required this.onStatsTap,
    required this.onProfileTap,
  });

  final String rightLabel;
  final VoidCallback onStatsTap;
  final VoidCallback onProfileTap;

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
          rightLabel,
          style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w800),
        ),
        const Spacer(),
        _RoundIconButton(icon: LucideIcons.barChart3, onTap: onStatsTap),
        const SizedBox(width: 8),
        _RoundIconButton(icon: LucideIcons.user, onTap: onProfileTap),
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

class _QuizHabitCard extends StatelessWidget {
  const _QuizHabitCard({
    required this.quiz,
    required this.statusLabel,
    required this.statusColor,
    required this.animationDelay,
    required this.actionLabel,
    required this.onActionTap,
  });

  final QuizSummary quiz;
  final String statusLabel;
  final Color statusColor;
  final Duration animationDelay;
  final String actionLabel;
  final VoidCallback? onActionTap;

  @override
  Widget build(BuildContext context) {
    return FadeSlideIn(
      delay: animationDelay,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
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
                      height: 1.2,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: statusColor.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Icon(
                    onActionTap == null ? LucideIcons.clock3 : LucideIcons.play,
                    size: 13,
                    color: statusColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '${quiz.subject} • ${quiz.durationMinutes} min • ${quiz.totalQuestions} questions',
              style: const TextStyle(fontSize: 13, color: AppTheme.textMuted),
            ),
            const SizedBox(height: 4),
            Text(
              '${statusLabel == 'ACTIVE' ? 'Ends' : 'Starts'} ${DateFormat('dd MMM, hh:mm a').format(statusLabel == 'ACTIVE' ? quiz.endAt : quiz.startAt)}',
              style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
            ),
            const SizedBox(height: 12),
            if (onActionTap != null)
              Align(
                alignment: Alignment.centerLeft,
                child: PressScale(
                  onTap: onActionTap,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.coral,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      actionLabel,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.panelSoft,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  actionLabel,
                  style: const TextStyle(
                    color: AppTheme.textMuted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
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

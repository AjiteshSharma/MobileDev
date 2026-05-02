import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../models/quiz_models.dart';
import '../services/auth_service.dart';
import '../services/quiz_service.dart';

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
      backgroundColor: const Color(0xFFF7F9FF),
      appBar: AppBar(
        title: const Text('Teacher Dashboard'),
        actions: [
          IconButton(
            onPressed: () => Navigator.pushNamed(context, '/manage-quizzes'),
            icon: const Icon(LucideIcons.layers),
          ),
          IconButton(
            onPressed: () => const AuthService().signOut(),
            icon: const Icon(LucideIcons.logOut),
          ),
        ],
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

          final activeCount = quizzes
              .where((quiz) => quiz.isActiveAt(now))
              .length;
          final upcomingCount = quizzes
              .where((quiz) => quiz.isUpcomingAt(now))
              .length;
          final processingCount = quizzes
              .where((quiz) => quiz.status == 'processing')
              .length;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome, ${teacher.displayName?.trim().isNotEmpty == true ? teacher.displayName : teacher.email}',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Manage uploads, monitor quiz status, and review student performance.',
                  style: TextStyle(color: Colors.black54),
                ),
                const SizedBox(height: 20),
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: MediaQuery.of(context).size.width > 700
                      ? 4
                      : 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  children: [
                    _StatCard(
                      label: 'Total Quizzes',
                      value: quizzes.length.toString(),
                      icon: LucideIcons.layers,
                      color: const Color(0xFF005BBF),
                    ),
                    _StatCard(
                      label: 'Active',
                      value: activeCount.toString(),
                      icon: LucideIcons.playCircle,
                      color: Colors.green,
                    ),
                    _StatCard(
                      label: 'Upcoming',
                      value: upcomingCount.toString(),
                      icon: LucideIcons.calendar,
                      color: Colors.blue,
                    ),
                    _StatCard(
                      label: 'Processing',
                      value: processingCount.toString(),
                      icon: LucideIcons.loader2,
                      color: Colors.orange,
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                const Text(
                  'Recent Quizzes',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                if (quizzes.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                        'No quizzes yet. Tap + to upload your first Excel quiz.',
                      ),
                    ),
                  )
                else
                  Card(
                    child: ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: quizzes.length,
                      separatorBuilder: (_, index) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final quiz = quizzes[index];
                        final status = _statusForQuiz(quiz, now);
                        final formatted = DateFormat(
                          'dd MMM yyyy, hh:mm a',
                        ).format(quiz.startAt);

                        return ListTile(
                          title: Text(
                            quiz.title,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          subtitle: Text(
                            '${quiz.subject} - ${quiz.batch} - $formatted',
                          ),
                          trailing: _StatusBadge(label: status),
                        );
                      },
                    ),
                  ),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.pushNamed(context, '/create-quiz'),
        icon: const Icon(LucideIcons.plus, color: Colors.white),
        label: const Text('New Quiz', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF005BBF),
      ),
    );
  }

  String _statusForQuiz(QuizSummary quiz, DateTime now) {
    if (quiz.status == 'processing' || quiz.status == 'error') {
      return quiz.status.toUpperCase();
    }

    if (quiz.isActiveAt(now)) {
      return 'ACTIVE';
    }
    if (quiz.isUpcomingAt(now)) {
      return 'UPCOMING';
    }
    return 'COMPLETED';
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: Colors.black54),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Icon(icon, color: color),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final color = switch (label) {
      'ACTIVE' => Colors.green,
      'UPCOMING' => Colors.blue,
      'PROCESSING' => Colors.orange,
      'ERROR' => Colors.red,
      _ => Colors.grey,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 11,
        ),
      ),
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

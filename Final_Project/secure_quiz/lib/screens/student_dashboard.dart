import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../models/quiz_models.dart';
import '../services/auth_service.dart';
import '../services/quiz_service.dart';
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
      backgroundColor: const Color(0xFFF7F9FF),
      appBar: AppBar(
        title: const Text('Student Dashboard'),
        actions: [
          IconButton(
            onPressed: () => Navigator.pushNamed(context, '/results'),
            icon: const Icon(LucideIcons.barChart3),
          ),
          IconButton(
            onPressed: () => const AuthService().signOut(),
            icon: const Icon(LucideIcons.logOut),
          ),
        ],
      ),
      body: StreamBuilder<List<QuizSummary>>(
        stream: quizService.streamStudentQuizzes(),
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

          final active = quizzes
              .where((quiz) => quiz.status == 'ready' && quiz.isActiveAt(now))
              .toList(growable: false);
          final upcoming = quizzes
              .where((quiz) => quiz.status == 'ready' && quiz.isUpcomingAt(now))
              .toList(growable: false);
          final past = quizzes
              .where((quiz) => quiz.status == 'ready' && quiz.isPastAt(now))
              .toList(growable: false);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome, ${student.displayName?.trim().isNotEmpty == true ? student.displayName : student.email}',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Active quizzes: ${active.length} - Upcoming: ${upcoming.length} - Past: ${past.length}',
                  style: const TextStyle(color: Colors.black54),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Active Quizzes',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                if (active.isEmpty)
                  const _EmptyCard(message: 'No active quiz right now.')
                else
                  ...active.map(
                    (quiz) => _QuizCard(
                      quiz: quiz,
                      statusLabel: 'ACTIVE',
                      statusColor: Colors.green,
                      onStart: () {
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
                    ),
                  ),
                const SizedBox(height: 24),
                const Text(
                  'Upcoming Quizzes',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                if (upcoming.isEmpty)
                  const _EmptyCard(message: 'No upcoming quizzes scheduled.')
                else
                  ...upcoming
                      .take(8)
                      .map(
                        (quiz) => _QuizCard(
                          quiz: quiz,
                          statusLabel: 'UPCOMING',
                          statusColor: Colors.blue,
                          onStart: null,
                        ),
                      ),
                const SizedBox(height: 24),
                const Text(
                  'Past Attempts',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                if (past.isEmpty)
                  const _EmptyCard(message: 'No completed quizzes yet.')
                else
                  ...past
                      .take(5)
                      .map(
                        (quiz) => Card(
                          child: ListTile(
                            leading: const Icon(LucideIcons.history),
                            title: Text(quiz.title),
                            subtitle: Text(
                              '${quiz.subject} - Ended ${DateFormat('dd MMM yyyy, hh:mm a').format(quiz.endAt)}',
                            ),
                            trailing: const Text('View marks'),
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ResultsScreen(
                                  quizId: quiz.id,
                                  quizTitle: quiz.title,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _QuizCard extends StatelessWidget {
  const _QuizCard({
    required this.quiz,
    required this.statusLabel,
    required this.statusColor,
    required this.onStart,
  });

  final QuizSummary quiz;
  final String statusLabel;
  final Color statusColor;
  final VoidCallback? onStart;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  statusLabel,
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  DateFormat('dd MMM yyyy, hh:mm a').format(quiz.startAt),
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              quiz.title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              '${quiz.subject} - ${quiz.batch} - ${quiz.durationMinutes} min - ${quiz.totalQuestions} questions',
              style: const TextStyle(color: Colors.black54),
            ),
            if (onStart != null) ...[
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: onStart,
                icon: const Icon(LucideIcons.play),
                label: const Text('Start Quiz'),
              ),
            ],
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
    return Card(
      child: Padding(padding: const EdgeInsets.all(16), child: Text(message)),
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

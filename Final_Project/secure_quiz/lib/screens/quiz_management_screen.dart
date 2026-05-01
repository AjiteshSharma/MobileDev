import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../models/quiz_models.dart';
import '../services/quiz_service.dart';

enum _QuizFilterTab { active, upcoming, completed, all }

class QuizManagementScreen extends StatefulWidget {
  const QuizManagementScreen({super.key});

  @override
  State<QuizManagementScreen> createState() => _QuizManagementScreenState();
}

class _QuizManagementScreenState extends State<QuizManagementScreen> {
  final QuizService _quizService = const QuizService();
  _QuizFilterTab _selectedTab = _QuizFilterTab.active;

  @override
  Widget build(BuildContext context) {
    final teacher = FirebaseAuth.instance.currentUser;
    if (teacher == null) {
      return const _NoSessionScaffold();
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FF),
      appBar: AppBar(
        title: const Text('Assessments'),
        actions: [
          IconButton(
            onPressed: () => Navigator.pushNamed(context, '/create-quiz'),
            icon: const Icon(LucideIcons.plus),
          ),
        ],
      ),
      body: StreamBuilder<List<QuizSummary>>(
        stream: _quizService.streamTeacherQuizzes(teacher.uid),
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

          final allQuizzes = snapshot.data ?? const <QuizSummary>[];
          final now = DateTime.now();
          final filteredQuizzes = _filterQuizzes(
            quizzes: allQuizzes,
            now: now,
            tab: _selectedTab,
          );

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Management',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${filteredQuizzes.length} shown of ${allQuizzes.length} assessments',
                          style: const TextStyle(
                            color: Colors.grey,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    ElevatedButton.icon(
                      onPressed: () =>
                          Navigator.pushNamed(context, '/create-quiz'),
                      icon: const Icon(
                        LucideIcons.plus,
                        size: 18,
                        color: Colors.white,
                      ),
                      label: const Text(
                        'New',
                        style: TextStyle(color: Colors.white),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildTab('Active', _QuizFilterTab.active),
                      _buildTab('Upcoming', _QuizFilterTab.upcoming),
                      _buildTab('Completed', _QuizFilterTab.completed),
                      _buildTab('All', _QuizFilterTab.all),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                if (allQuizzes.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(18),
                      child: Text(
                        'No quizzes found yet. Create your first quiz to manage it here.',
                      ),
                    ),
                  )
                else if (filteredQuizzes.isEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Text('No quizzes in ${_tabLabel(_selectedTab)}.'),
                    ),
                  )
                else
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: filteredQuizzes.length,
                    itemBuilder: (context, index) {
                      final quiz = filteredQuizzes[index];
                      return _buildQuizListItem(
                        context: context,
                        quiz: quiz,
                        now: now,
                      );
                    },
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildTab(String label, _QuizFilterTab tab) {
    final isSelected = _selectedTab == tab;
    return GestureDetector(
      onTap: () => setState(() => _selectedTab = tab),
      child: Container(
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF005BBF) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? Colors.transparent : const Color(0xFFC1C6D6),
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.blue.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : const Color(0xFF414754),
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _buildQuizListItem({
    required BuildContext context,
    required QuizSummary quiz,
    required DateTime now,
  }) {
    final status = _statusForQuiz(quiz, now);
    final statusColor = _statusColor(status);
    final schedule = _scheduleLabel(quiz, now);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: () {},
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: statusColor.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Text(
                      status,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                  const Icon(
                    LucideIcons.moreVertical,
                    size: 18,
                    color: Colors.grey,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                quiz.title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '${quiz.subject} - ${quiz.batch}',
                style: const TextStyle(color: Colors.grey, fontSize: 13),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        const Icon(
                          LucideIcons.calendar,
                          size: 14,
                          color: Colors.blue,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            schedule,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Row(
                      children: [
                        const Icon(
                          LucideIcons.helpCircle,
                          size: 14,
                          color: Colors.blue,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${quiz.totalQuestions} Questions',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Divider(height: 1),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Total Points: ${quiz.totalPoints}',
                    style: const TextStyle(
                      color: Color(0xFF005BBF),
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  const Icon(
                    LucideIcons.arrowRight,
                    size: 16,
                    color: Color(0xFF005BBF),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<QuizSummary> _filterQuizzes({
    required List<QuizSummary> quizzes,
    required DateTime now,
    required _QuizFilterTab tab,
  }) {
    switch (tab) {
      case _QuizFilterTab.active:
        return quizzes.where((quiz) => quiz.isActiveAt(now)).toList();
      case _QuizFilterTab.upcoming:
        return quizzes.where((quiz) => quiz.isUpcomingAt(now)).toList();
      case _QuizFilterTab.completed:
        return quizzes.where((quiz) => quiz.isPastAt(now)).toList();
      case _QuizFilterTab.all:
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

  Color _statusColor(String status) {
    switch (status) {
      case 'ACTIVE':
        return Colors.green;
      case 'UPCOMING':
        return Colors.blue;
      case 'PROCESSING':
        return Colors.orange;
      case 'ERROR':
        return Colors.red;
      default:
        return Colors.grey;
    }
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

  String _tabLabel(_QuizFilterTab tab) {
    switch (tab) {
      case _QuizFilterTab.active:
        return 'Active';
      case _QuizFilterTab.upcoming:
        return 'Upcoming';
      case _QuizFilterTab.completed:
        return 'Completed';
      case _QuizFilterTab.all:
        return 'All';
    }
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

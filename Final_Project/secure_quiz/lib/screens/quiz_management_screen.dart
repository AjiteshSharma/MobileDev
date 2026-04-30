import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

class QuizManagementScreen extends StatelessWidget {
  const QuizManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FF),
      appBar: AppBar(
        title: const Text('Assessments'),
        actions: [
          IconButton(onPressed: () {}, icon: const Icon(LucideIcons.search)),
          IconButton(onPressed: () {}, icon: const Icon(LucideIcons.bell)),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Management',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '12 Active Assessments',
                      style: TextStyle(
                        color: Colors.grey,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: () => Navigator.pushNamed(context, '/create-quiz'),
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
                  _buildTab('Active', true),
                  _buildTab('Drafts', false),
                  _buildTab('Completed', false),
                  _buildTab('Archived', false),
                ],
              ),
            ),
            const SizedBox(height: 32),
            _buildQuizListItem(
              context,
              'Advanced Macroeconomics Final',
              'Section B â€¢ 150 Students',
              'Ends: Today, 11:59 PM',
              '142 Submitted',
              'ACTIVE',
              Colors.greenAccent,
            ),
            _buildQuizListItem(
              context,
              'Introduction to Psychology',
              'Section A â€¢ 120 Students',
              'Ends: Tomorrow',
              '88 Submitted',
              'ACTIVE',
              Colors.greenAccent,
            ),
            _buildQuizListItem(
              context,
              'Quantum Physics 402',
              'Graduate Level â€¢ 45 Students',
              'Scheduled: Oct 28',
              '0 Submitted',
              'UPCOMING',
              Colors.blue,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTab(String label, bool isSelected) {
    return Container(
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
    );
  }

  Widget _buildQuizListItem(
    BuildContext context,
    String title,
    String subtitle,
    String date,
    String submissions,
    String status,
    Color statusColor,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: () {},
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
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
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                subtitle,
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
                        Text(
                          date,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Row(
                      children: [
                        const Icon(
                          LucideIcons.users,
                          size: 14,
                          color: Colors.blue,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          submissions,
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
              const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'View Live Results',
                    style: TextStyle(
                      color: Color(0xFF005BBF),
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  Icon(
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
}

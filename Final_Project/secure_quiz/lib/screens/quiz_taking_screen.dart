import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';

class QuizTakingScreen extends StatefulWidget {
  const QuizTakingScreen({super.key});

  @override
  State<QuizTakingScreen> createState() => _QuizTakingScreenState();
}

class _QuizTakingScreenState extends State<QuizTakingScreen> {
  int _currentQuestionIndex = 0;
  final int _totalQuestions = 20;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            const Icon(LucideIcons.clock, size: 20, color: Color(0xFF005BBF)),
            const SizedBox(width: 8),
            Text(
              '18:45',
              style: GoogleFonts.jetBrainsMono(
                fontWeight: FontWeight.bold,
                color: const Color(0xFF005BBF),
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: OutlinedButton(
              onPressed: () => _showSubmitDialog(),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFFE2E8F0)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Submit Quiz'),
            ),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Column(
        children: [
          LinearProgressIndicator(
            value: (_currentQuestionIndex + 1) / _totalQuestions,
            backgroundColor: const Color(0xFFE2E8F0),
            color: const Color(0xFF005BBF),
            minHeight: 4,
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Question ${_currentQuestionIndex + 1} of $_totalQuestions',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '2 Points',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF475569),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Which of the following describes the behavior of a function where the output value increases as the input value increases across its entire domain?',
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      height: 1.4,
                      color: const Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 32),
                  _buildOption('A', 'Strictly Increasing Function'),
                  _buildOption('B', 'Constant Function'),
                  _buildOption('C', 'Strictly Decreasing Function'),
                  _buildOption('D', 'Periodic Function'),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildOption(String letter, String text) {
    bool isSelected = false; // Just for UI mock

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Material(
        color: isSelected ? const Color(0xFFEFF6FF) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: isSelected ? const Color(0xFF005BBF) : const Color(0xFFE2E8F0),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: InkWell(
          onTap: () {},
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFF005BBF) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected ? const Color(0xFF005BBF) : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Center(
                    child: Text(
                      letter,
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.bold,
                        color: isSelected ? Colors.white : const Color(0xFF64748B),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    text,
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                      color: isSelected ? const Color(0xFF005BBF) : const Color(0xFF334155),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: const Color(0xFFE2E8F0))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: () {
              if (_currentQuestionIndex > 0) {
                setState(() => _currentQuestionIndex--);
              }
            },
            icon: const Icon(LucideIcons.chevronLeft),
            style: IconButton.styleFrom(
              backgroundColor: const Color(0xFFF8FAFC),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
          OutlinedButton.icon(
            onPressed: () => _showQuestionGrid(),
            icon: const Icon(LucideIcons.grid, size: 18),
            label: const Text('Review All'),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFFE2E8F0)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
          IconButton(
            onPressed: () {
              if (_currentQuestionIndex < _totalQuestions - 1) {
                setState(() => _currentQuestionIndex++);
              }
            },
            icon: const Icon(LucideIcons.chevronRight),
            style: IconButton.styleFrom(
              backgroundColor: const Color(0xFF005BBF),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
    );
  }

  void _showSubmitDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Submit Quiz?'),
        content: const Text('You have 2 unanswered questions. Are you sure you want to submit?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pushReplacementNamed(context, '/results');
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF005BBF), foregroundColor: Colors.white),
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }

  void _showQuestionGrid() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Question Overview',
                  style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(LucideIcons.x)),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _statusLegend(Colors.blue, 'Current'),
                const SizedBox(width: 16),
                _statusLegend(const Color(0xFFE2E8F0), 'Unanswered'),
                const SizedBox(width: 16),
                _statusLegend(const Color(0xFF005BBF), 'Answered'),
              ],
            ),
            const SizedBox(height: 24),
            Expanded(
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 5,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                ),
                itemCount: _totalQuestions,
                itemBuilder: (context, index) {
                  bool isCurrent = index == _currentQuestionIndex;
                  return InkWell(
                    onTap: () {
                      setState(() => _currentQuestionIndex = index);
                      Navigator.pop(context);
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: isCurrent ? const Color(0xFFEFF6FF) : const Color(0xFFF8FAFC),
                        border: Border.all(
                          color: isCurrent ? const Color(0xFF005BBF) : const Color(0xFFE2E8F0),
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          '${index + 1}',
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.bold,
                            color: isCurrent ? const Color(0xFF005BBF) : const Color(0xFF64748B),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusLegend(Color color, String label) {
    return Row(
      children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B))),
      ],
    );
  }
}

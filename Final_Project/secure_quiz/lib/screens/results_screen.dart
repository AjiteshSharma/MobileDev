import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

class ResultsScreen extends StatelessWidget {
  const ResultsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FF),
      appBar: AppBar(
        title: const Text('EduAssess'),
        actions: [
          IconButton(onPressed: () {}, icon: const Icon(LucideIcons.bell)),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
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
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'SUBMITTED',
                    style: TextStyle(
                      color: Colors.green,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Advanced Mathematics Terminal A',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 32),

            // Main Grade Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'FINAL GRADE',
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.baseline,
                              textBaseline: TextBaseline.alphabetic,
                              children: [
                                Text(
                                  '84',
                                  style: TextStyle(
                                    fontSize: 80,
                                    fontWeight: FontWeight.w900,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                  ),
                                ),
                                Text(
                                  '%',
                                  style: TextStyle(
                                    fontSize: 32,
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(context).colorScheme.primary
                                        .withValues(alpha: 0.5),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(width: 48),
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
                            const Row(
                              crossAxisAlignment: CrossAxisAlignment.baseline,
                              textBaseline: TextBaseline.alphabetic,
                              children: [
                                Text(
                                  '42',
                                  style: TextStyle(
                                    fontSize: 32,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  ' / 50',
                                  style: TextStyle(
                                    fontSize: 18,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                          ],
                        ),
                      ],
                    ),
                    const Divider(),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        _buildSummaryItem(
                          context,
                          LucideIcons.checkCircle,
                          Colors.green,
                          'Correct',
                          '42 Questions',
                        ),
                        const SizedBox(width: 32),
                        _buildSummaryItem(
                          context,
                          LucideIcons.xCircle,
                          Colors.red,
                          'Incorrect',
                          '8 Questions',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 32),
            const Text(
              'Competency Breakdown',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Card(
              child: Column(
                children: [
                  _buildBreakdownItem(
                    'Calculus & Limits',
                    'Differential equations and theoretical limits application.',
                    1.0,
                  ),
                  const Divider(height: 1),
                  _buildBreakdownItem(
                    'Linear Algebra',
                    'Vector spaces, matrices, and linear transformations.',
                    0.75,
                  ),
                  const Divider(height: 1),
                  _buildBreakdownItem(
                    'Probability & Statistics',
                    'Bayesian inference and normal distribution analysis.',
                    0.79,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                minimumSize: const Size(double.infinity, 56),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(LucideIcons.fileText, color: Colors.white),
                  SizedBox(width: 8),
                  Text(
                    'Review Answer Key',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryItem(
    BuildContext context,
    IconData icon,
    Color color,
    String label,
    String value,
  ) {
    return Row(
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

  Widget _buildBreakdownItem(String title, String subtitle, double progress) {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
              Text(
                '${(progress * 100).toInt()}%',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: progress == 1.0 ? Colors.green : Colors.blue,
                ),
              ),
            ],
          ),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: progress,
            backgroundColor: Colors.grey[200],
            borderRadius: BorderRadius.circular(4),
          ),
        ],
      ),
    );
  }
}

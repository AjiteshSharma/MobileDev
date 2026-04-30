import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

class TeacherDashboard extends StatelessWidget {
  const TeacherDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('EduAssess'),
        actions: [
          IconButton(onPressed: () {}, icon: const Icon(LucideIcons.bell)),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0),
            child: CircleAvatar(
              backgroundImage: NetworkImage('https://lh3.googleusercontent.com/aida-public/AB6AXuC_cKvNvN7FO2voBStgvd3vz2QEdlVZSFinewLnqih6b3jtj5GmmTIl-bbyK03CV_6Owcyx6hrpwtgxCi2tsTjawtUgVRrSZOYHpcsnMLRf_IKCe9jHgnc5CrbTtF_rBicZQVfMjgAyxN4BDYkBLmkCvhb5ppdWODil08lcAMw30SVYA5jPRUFqATFZhISg6fTdVEZ_c5pvKWZ8MARpNWp-nZliJMRBsJdqUc7W2b3lXqBKL4yvqeoG_4wZKNzPVcM20Nysn-KRHf4'),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Teacher Dashboard',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const Text(
              'Welcome back. Here is your assessment overview for today.',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 32),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: MediaQuery.of(context).size.width > 600 ? 4 : 2,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              children: [
                _buildStatCard(context, 'Total Quizzes', '24', LucideIcons.layers, Colors.blue),
                _buildStatCard(context, 'Active', '3', LucideIcons.playCircle, Colors.green),
                _buildStatCard(context, 'Upcoming', '1', LucideIcons.calendar, Colors.blue),
                _buildStatCard(context, 'Flagged', '2', LucideIcons.alertCircle, Colors.red, isError: true),
              ],
            ),
            const SizedBox(height: 48),
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Recent Quizzes', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 16),
            Card(
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: 3,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final titles = ['Mid-term Algebra Assessment', 'Cell Biology Basics', 'World War II Recap'];
                  final subjects = ['Mathematics', 'Natural Sciences', 'History'];
                  final statuses = ['ACTIVE', 'DRAFT', 'SCHEDULED'];
                  return ListTile(
                    contentPadding: const EdgeInsets.all(16),
                    title: Text(titles[index], style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(subjects[index]),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildStatusBadge(statuses[index]),
                        const SizedBox(width: 16),
                        const Icon(LucideIcons.edit2, size: 18),
                        const SizedBox(width: 8),
                        const Icon(LucideIcons.barChart3, size: 18),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.pushNamed(context, '/create-quiz'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        child: const Icon(LucideIcons.plus, color: Colors.white),
      ),
      bottomNavigationBar: BottomNavigationBar(
        onTap: (index) {
          if (index == 1) Navigator.pushNamed(context, '/manage-quizzes');
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(LucideIcons.layoutDashboard), label: 'Dashboard'),
          BottomNavigationBarItem(icon: Icon(LucideIcons.layers), label: 'Quizzes'),
          BottomNavigationBarItem(icon: Icon(LucideIcons.barChart3), label: 'Results'),
          BottomNavigationBarItem(icon: Icon(LucideIcons.user), label: 'Profile'),
        ],
        currentIndex: 0,
        selectedItemColor: Theme.of(context).colorScheme.primary,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
      ),
    );
  }

  Widget _buildStatCard(BuildContext context, String label, String value, IconData icon, Color iconColor, {bool isError = false}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isError ? const Color(0xFFFFDAD6) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isError ? Colors.red.withOpacity(0.2) : const Color(0xFFC1C6D6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label.toUpperCase(), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(value, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
              Icon(icon, color: iconColor, size: 28),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color = Colors.grey;
    if (status == 'ACTIVE') color = Colors.green;
    if (status == 'SCHEDULED') color = Colors.blue;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Text(status, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color)),
    );
  }
}


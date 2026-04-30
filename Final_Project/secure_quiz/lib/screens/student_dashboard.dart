import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

class StudentDashboard extends StatelessWidget {
  const StudentDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FF),
      appBar: AppBar(
        title: const Text('EduAssess'),
        actions: [
          IconButton(onPressed: () {}, icon: const Icon(LucideIcons.bell)),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0),
            child: CircleAvatar(
              backgroundImage: NetworkImage('https://lh3.googleusercontent.com/aida-public/AB6AXuA_SR3EcxZvdLt6YohbjdDTpP9gt3w5-nFmeB2ZNKblS7LMpaZlv1RjGBi8pRCnq4sB-aaQwDE0lO90eavVnBni7Wa_HdZBVPq8aTkv3yXtJPQu13PHIfbpCBa-9diPMhG5rcmgSM3gv11KeFnBZ1cQizJ_CTToStb5eeiIzNat3jafnGB-_v92WuZ9z2mNs0w8JEPB5VPNj92escxKob8CRXN68vBXcWqiLn4pafiRs1nEu_56B09m2-bQjdZ1kct7M0QqmpibVds'),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Welcome back, Alex', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
            const Text('You have 2 active assessments today. Keep up the momentum!', style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 32),
            
            // Hero Card for Active Assessment
            Card(
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  Stack(
                    children: [
                      Image.network(
                        'https://lh3.googleusercontent.com/aida-public/AB6AXuA3iZcGv_0QD1wbDQA6rptasFIn3vKPZelg5OGLgcSdxVWFvfEsCKtdtmTCVZQIFAfd_XE95nYcF2OQsd1M7RfvHWwHWKAnqkLXzFaRq8-4GgRWVz69UzE0FUDRToxOTYK81jHaXsTeocvEz2ESwPJoNLPr-5fIexLZ71V1hs5ckIS_aM-jv5sMNUS55jPSc42R9xXRqCaKKCx4ho_soJPl0PWZ1IIuc_LaDseM_76pOzKKWd7gb6ewg0Rm-GodY-uDiYpti2A2KUc',
                        height: 200,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                      Positioned(
                        bottom: 16,
                        left: 16,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary, borderRadius: BorderRadius.circular(4)),
                          child: const Text('ACTIVE NOW', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('MATHEMATICS', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1.2)),
                        const SizedBox(height: 8),
                        const Text('Advanced Calculus Final', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        const Text('Comprehensive exam covering derivatives, integrals, and vector spaces.', style: TextStyle(color: Colors.grey)),
                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Row(
                              children: [
                                Icon(LucideIcons.timer, size: 20, color: Colors.grey),
                                SizedBox(width: 8),
                                Text('90 Minutes', style: TextStyle(fontWeight: FontWeight.w600)),
                              ],
                            ),
                            ElevatedButton(
                              onPressed: () => Navigator.pushNamed(context, '/quiz-preview'),
                              style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                              child: const Text('Start Assessment', style: TextStyle(color: Colors.white)),
                            ),
                          ],
                        )
                      ],
                    ),
                  )
                ],
              ),
            ),
            
            const SizedBox(height: 48),
            const Text('Upcoming Quizzes', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            SizedBox(
              height: 160,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _buildUpcomingCard('Organic Chemistry', 'Unit 4: Molecular Bonding', 'TOMORROW', LucideIcons.beaker),
                  _buildUpcomingCard('European History', 'Mid-term Revision', 'OCT 26', LucideIcons.book),
                  _buildUpcomingCard('English Literature', 'Poetry Analysis', 'OCT 28', LucideIcons.languages),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
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

  Widget _buildUpcomingCard(String title, String subtitle, String date, IconData icon) {
    return Container(
      width: 240,
      margin: const EdgeInsets.only(right: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFC1C6D6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: Colors.blue),
              Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(4)), child: Text(date, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold))),
            ],
          ),
          const SizedBox(height: 12),
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          const Spacer(),
          const Divider(),
          const Row(
            children: [
              Icon(LucideIcons.calendar, size: 12, color: Colors.grey),
              SizedBox(width: 4),
              Text('Oct 24', style: TextStyle(fontSize: 10)),
              SizedBox(width: 8),
              Icon(LucideIcons.clock, size: 12, color: Colors.grey),
              SizedBox(width: 4),
              Text('10:00 AM', style: TextStyle(fontSize: 10)),
            ],
          )
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../theme/app_theme.dart';

class QuizPreviewScreen extends StatelessWidget {
  const QuizPreviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.midnight,
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(context),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeaderInfo(),
                  const SizedBox(height: 24),
                  _buildStatsGrid(),
                  const SizedBox(height: 32),
                  _buildSectionTitle('Assessment Description'),
                  const SizedBox(height: 12),
                  Text(
                    'This comprehensive assessment covers fundamental concepts of differential and integral calculus. Students will be tested on their ability to solve limits, derivatives, and basic integrals, with practical application problems involving rates of change and area under curves.',
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      height: 1.6,
                      color: const Color(0xFF475569),
                    ),
                  ),
                  const SizedBox(height: 32),
                  _buildSectionTitle('Instructions'),
                  const SizedBox(height: 12),
                  _buildInstructionItem(
                    'Ensure a stable internet connection throughout the session.',
                  ),
                  _buildInstructionItem(
                    'Calculators are permitted for Section B (Integral applications).',
                  ),
                  _buildInstructionItem(
                    'Once started, the timer cannot be paused.',
                  ),
                  _buildInstructionItem(
                    'App switching and capture attempts are monitored on mobile quiz attempts.',
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomAction(context),
    );
  }

  Widget _buildSliverAppBar(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 200,
      pinned: true,
      backgroundColor: AppTheme.midnight,
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(
              'https://images.unsplash.com/photo-1543286386-713bdd548da4?auto=format&fit=crop&q=80&w=2000',
              fit: BoxFit.cover,
            ),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.3),
                    Colors.black.withValues(alpha: 0.7),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      leading: IconButton(
        icon: const Icon(LucideIcons.arrowLeft, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      actions: [
        IconButton(
          icon: const Icon(LucideIcons.share2, color: Colors.white),
          onPressed: () {},
        ),
      ],
    );
  }

  Widget _buildHeaderInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.panelSoft,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'MATHEMATAICS',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.coral,
                  letterSpacing: 1,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.panel,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'ADVANCED',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textMuted,
                  letterSpacing: 1,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          'Calculus & Analytical Geometry Terminal A',
          style: GoogleFonts.inter(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            const CircleAvatar(
              radius: 12,
              backgroundImage: NetworkImage(
                'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?auto=format&fit=crop&q=80&w=100',
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'By Prof. Robert Jenkins',
              style: GoogleFonts.inter(fontSize: 14, color: AppTheme.textMuted),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatsGrid() {
    return Row(
      children: [
        _buildStatItem(LucideIcons.helpCircle, '25 Questions'),
        const SizedBox(width: 12),
        _buildStatItem(LucideIcons.clock, '60 Minutes'),
        const SizedBox(width: 12),
        _buildStatItem(LucideIcons.award, '100 Points'),
      ],
    );
  }

  Widget _buildStatItem(IconData icon, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: AppTheme.panel,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.stroke),
        ),
        child: Column(
          children: [
            Icon(icon, size: 20, color: AppTheme.coral),
            const SizedBox(height: 8),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.inter(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: AppTheme.textPrimary,
      ),
    );
  }

  Widget _buildInstructionItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 6),
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: AppTheme.coral,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: AppTheme.textMuted,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomAction(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.midnight,
        border: Border(top: BorderSide(color: AppTheme.stroke)),
      ),
      child: ElevatedButton(
        onPressed: () {
          Navigator.pushNamed(context, '/take-quiz');
        },
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(double.infinity, 58),
          padding: const EdgeInsets.symmetric(vertical: 16),
          elevation: 0,
        ),
        child: Text(
          'Start Assessment Now',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ),
    );
  }
}

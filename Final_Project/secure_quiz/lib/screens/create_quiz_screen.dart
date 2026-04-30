import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';

class CreateQuizScreen extends StatefulWidget {
  const CreateQuizScreen({super.key});

  @override
  State<CreateQuizScreen> createState() => _CreateQuizScreenState();
}

class _CreateQuizScreenState extends State<CreateQuizScreen> {
  int _currentStep = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Create New Quiz'),
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          TextButton(
            onPressed: () {},
            child: const Text('Save Draft'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          _buildStepProgress(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: _buildCurrentStepView(),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomAction(),
    );
  }

  Widget _buildStepProgress() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
      child: Row(
        children: [
          _stepIcon(0, 'Info', LucideIcons.info),
          _stepDivider(),
          _stepIcon(1, 'Questions', LucideIcons.helpCircle),
          _stepDivider(),
          _stepIcon(2, 'Settings', LucideIcons.settings),
        ],
      ),
    );
  }

  Widget _stepIcon(int index, String label, IconData icon) {
    bool isActive = _currentStep == index;
    bool isCompleted = _currentStep > index;

    return Expanded(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isActive ? const Color(0xFF005BBF) : (isCompleted ? const Color(0xFFE2E8F0) : Colors.transparent),
              shape: BoxShape.circle,
              border: Border.all(
                color: isActive ? const Color(0xFF005BBF) : const Color(0xFFE2E8F0),
              ),
            ),
            child: Icon(
              isCompleted ? LucideIcons.check : icon,
              size: 20,
              color: isActive ? Colors.white : (isCompleted ? const Color(0xFF005BBF) : const Color(0xFF94A3B8)),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
              color: isActive ? const Color(0xFF005BBF) : const Color(0xFF94A3B8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _stepDivider() {
    return Container(
      width: 40,
      height: 1,
      color: const Color(0xFFE2E8F0),
      margin: const EdgeInsets.only(bottom: 20),
    );
  }

  Widget _buildCurrentStepView() {
    switch (_currentStep) {
      case 0:
        return _buildGeneralInfo();
      case 1:
        return _buildQuestionsSection();
      case 2:
        return _buildFinalSettings();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildGeneralInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader('General Information', 'Set the basic details for your quiz'),
        const SizedBox(height: 24),
        _buildTextField('Quiz Title', 'e.g. Introduction to Calculus'),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(child: _buildDropdown('Category', ['Mathematics', 'Science', 'History'])),
            const SizedBox(width: 16),
            Expanded(child: _buildDropdown('Level', ['Beginner', 'Intermediate', 'Advanced'])),
          ],
        ),
        const SizedBox(height: 20),
        _buildTextField('Description', 'Provide a brief summary of what this quiz covers', maxLines: 3),
        const SizedBox(height: 32),
        _sectionHeader('Cover Image', 'Optional cover image for the quiz'),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          height: 150,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0), style: BorderStyle.none),
          ),
          child: Material(
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: Color(0xFFE2E8F0), width: 1),
            ),
            child: InkWell(
              onTap: () {},
              borderRadius: BorderRadius.circular(12),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(LucideIcons.image, size: 32, color: Color(0xFF94A3B8)),
                  const SizedBox(height: 8),
                  Text(
                    'Tap to upload image',
                    style: GoogleFonts.inter(color: const Color(0xFF64748B)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQuestionsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _sectionHeader('Questions (0)', 'Add and manage quiz questions'),
            ElevatedButton.icon(
              onPressed: () {},
              icon: const Icon(LucideIcons.plus, size: 16),
              label: const Text('Add Question'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF005BBF),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 40),
        Center(
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  shape: BoxShape.circle,
                ),
                child: const Icon(LucideIcons.helpCircle, size: 48, color: Color(0xFF005BBF)),
              ),
              const SizedBox(height: 16),
              Text(
                'No questions added yet',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Start by adding your first question to the quiz.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(color: const Color(0xFF64748B)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFinalSettings() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader('Quiz Settings', 'Configure how the quiz will behave'),
        const SizedBox(height: 24),
        _buildSettingToggle('Time Limit', 'Set a duration for the entire quiz', true),
        _buildTextField('Duration (minutes)', '30', keyboardType: TextInputType.number),
        const SizedBox(height: 20),
        _buildSettingToggle('Randomize Questions', 'Change question order for each student', true),
        _buildSettingToggle('Instant Feedback', 'Show results immediately after submission', false),
        _buildSettingToggle('Lock Browser', 'Restrict students from leaving the quiz app', false),
        const SizedBox(height: 32),
        _sectionHeader('Release Schedule', 'When should this quiz be available?'),
        const SizedBox(height: 16),
        _buildTextField('Start Date', 'Select date...', icon: LucideIcons.calendar),
      ],
    );
  }

  Widget _sectionHeader(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF1E293B),
          ),
        ),
        Text(
          subtitle,
          style: GoogleFonts.inter(
            fontSize: 14,
            color: const Color(0xFF64748B),
          ),
        ),
      ],
    );
  }

  Widget _buildTextField(String label, String hint, {int maxLines = 1, IconData? icon, TextInputType? keyboardType}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF475569),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          maxLines: maxLines,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: icon != null ? Icon(icon, size: 20) : null,
          ),
        ),
      ],
    );
  }

  Widget _buildDropdown(String label, List<String> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF475569),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: const Color(0xFFE2E8F0)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              hint: Text(items.first),
              items: items.map((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value),
                );
              }).toList(),
              onChanged: (_) {},
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSettingToggle(String title, String subtitle, bool value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1E293B),
                  ),
                ),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: (v) {},
            activeColor: const Color(0xFF005BBF),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomAction() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: const Color(0xFFE2E8F0))),
      ),
      child: Row(
        children: [
          if (_currentStep > 0)
            Expanded(
              child: OutlinedButton(
                onPressed: () {
                  setState(() => _currentStep--);
                },
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  side: const BorderSide(color: Color(0xFFE2E8F0)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('Back'),
              ),
            ),
          if (_currentStep > 0) const SizedBox(width: 16),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: () {
                if (_currentStep < 2) {
                  setState(() => _currentStep++);
                } else {
                  // Finish
                  Navigator.pop(context);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF005BBF),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: Text(_currentStep < 2 ? 'Continue' : 'Create Quiz'),
            ),
          ),
        ],
      ),
    );
  }
}

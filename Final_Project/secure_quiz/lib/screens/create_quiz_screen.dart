import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../services/quiz_service.dart';
import '../theme/app_theme.dart';
import '../widgets/press_scale.dart';

enum _CreateQuizMode { excel, ai }

class CreateQuizScreen extends StatefulWidget {
  const CreateQuizScreen({super.key});

  @override
  State<CreateQuizScreen> createState() => _CreateQuizScreenState();
}

class _CreateQuizScreenState extends State<CreateQuizScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _subjectController = TextEditingController();
  final _batchController = TextEditingController();
  final _durationController = TextEditingController(text: '30');
  final _promptController = TextEditingController();
  final _questionCountController = TextEditingController(text: '10');
  final _maxMarksController = TextEditingController(text: '20');

  final QuizService _quizService = const QuizService();

  DateTime? _startAt;
  PlatformFile? _excelFile;
  _CreateQuizMode _mode = _CreateQuizMode.excel;
  String _difficulty = 'medium';
  bool _isSubmitting = false;

  @override
  void dispose() {
    _titleController.dispose();
    _subjectController.dispose();
    _batchController.dispose();
    _durationController.dispose();
    _promptController.dispose();
    _questionCountController.dispose();
    _maxMarksController.dispose();
    super.dispose();
  }

  Future<void> _pickStartDateTime() async {
    final now = DateTime.now();
    final initial = _startAt ?? now.add(const Duration(hours: 1));

    final date = await showDatePicker(
      context: context,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
      initialDate: initial,
      builder: (context, child) {
        return Theme(data: Theme.of(context), child: child!);
      },
    );

    if (date == null || !mounted) {
      return;
    }

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
      builder: (context, child) {
        return Theme(data: Theme.of(context), child: child!);
      },
    );

    if (time == null) {
      return;
    }

    setState(() {
      _startAt = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  Future<void> _pickExcelFile() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['xlsx', 'csv'],
      withData: true,
    );

    if (!mounted || result == null || result.files.isEmpty) {
      return;
    }

    setState(() {
      _excelFile = result.files.first;
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_startAt == null) {
      _showSnack('Please choose quiz date and time.');
      return;
    }

    final teacher = FirebaseAuth.instance.currentUser;
    if (teacher == null) {
      _showSnack('Session expired. Please sign in again.');
      return;
    }

    final durationMinutes = int.tryParse(_durationController.text.trim());
    if (durationMinutes == null || durationMinutes <= 0) {
      _showSnack('Duration must be a positive number.');
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      late final String quizId;
      if (_mode == _CreateQuizMode.excel) {
        final file = _excelFile;
        if (file == null || file.bytes == null) {
          _showSnack('Please upload an Excel file first.');
          return;
        }

        quizId = await _quizService.createQuizFromExcel(
          teacherId: teacher.uid,
          teacherEmail: teacher.email ?? '',
          title: _titleController.text,
          subject: _subjectController.text,
          startAt: _startAt!,
          durationMinutes: durationMinutes,
          batch: _batchController.text,
          fileBytes: file.bytes!,
          fileName: file.name,
          fileExtension: file.extension,
        );
      } else {
        final questionCount = int.parse(_questionCountController.text.trim());
        final maxMarks = int.parse(_maxMarksController.text.trim());

        quizId = await _quizService.createQuizFromAI(
          title: _titleController.text,
          subject: _subjectController.text,
          startAt: _startAt!,
          durationMinutes: durationMinutes,
          batch: _batchController.text,
          prompt: _promptController.text,
          difficulty: _difficulty,
          questionCount: questionCount,
          maxMarks: maxMarks,
        );
      }

      if (!mounted) {
        return;
      }

      _showSnack('Quiz created successfully: $quizId');
      Navigator.pop(context);
    } catch (error) {
      _showSnack('Failed to create quiz: $error');
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAiMode = _mode == _CreateQuizMode.ai;

    return Scaffold(
      appBar: AppBar(title: const Text('Create Quiz')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SectionCard(
                    title: 'Quiz Details',
                    subtitle: 'Set title, class, schedule, and duration.',
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _titleController,
                          decoration: const InputDecoration(
                            labelText: 'Quiz Title',
                            hintText: 'Example: SEPM Unit Test 1',
                          ),
                          validator: (value) => (value ?? '').trim().isEmpty
                              ? 'Title is required'
                              : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _subjectController,
                          decoration: const InputDecoration(
                            labelText: 'Subject',
                            hintText: 'Example: Software Engineering',
                          ),
                          validator: (value) => (value ?? '').trim().isEmpty
                              ? 'Subject is required'
                              : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _batchController,
                          decoration: const InputDecoration(
                            labelText: 'Class / Batch (e.g. BCA-5A)',
                            hintText: 'Example: AIML-6',
                          ),
                          validator: (value) => (value ?? '').trim().isEmpty
                              ? 'Batch is required'
                              : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _durationController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Duration (minutes)',
                            hintText: 'Example: 30',
                          ),
                          validator: (value) {
                            final minutes = int.tryParse((value ?? '').trim());
                            if (minutes == null || minutes <= 0) {
                              return 'Enter a valid duration';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppTheme.panelSoft,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: AppTheme.strokeSoft),
                          ),
                          child: Wrap(
                            runSpacing: 12,
                            spacing: 12,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            alignment: WrapAlignment.spaceBetween,
                            children: [
                              Text(
                                _startAt == null
                                    ? 'Quiz start: Not selected'
                                    : 'Quiz start: ${DateFormat('dd MMM yyyy, hh:mm a').format(_startAt!)}',
                                style: Theme.of(context).textTheme.titleSmall,
                              ),
                              SizedBox(
                                width: 190,
                                child: OutlinedButton.icon(
                                  onPressed: _pickStartDateTime,
                                  icon: const Icon(
                                    LucideIcons.calendar,
                                    size: 18,
                                  ),
                                  label: const Text('Set Date & Time'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _SectionCard(
                    title: 'Question Source',
                    subtitle:
                        'Choose whether to upload a sheet or auto-generate with AI.',
                    child: Row(
                      children: [
                        Expanded(
                          child: _ModeButton(
                            label: 'Excel Upload',
                            icon: LucideIcons.fileSpreadsheet,
                            selected: _mode == _CreateQuizMode.excel,
                            onTap: () {
                              setState(() => _mode = _CreateQuizMode.excel);
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _ModeButton(
                            label: 'AI Generate',
                            icon: LucideIcons.sparkles,
                            selected: _mode == _CreateQuizMode.ai,
                            onTap: () {
                              setState(() => _mode = _CreateQuizMode.ai);
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (isAiMode)
                    _SectionCard(
                      title: 'AI Quiz Generator',
                      subtitle:
                          'Enter topics separated by commas. AI generates objective MCQs.',
                      child: Column(
                        children: [
                          TextFormField(
                            controller: _promptController,
                            minLines: 3,
                            maxLines: 5,
                            decoration: const InputDecoration(
                              labelText: 'Prompt / Topic',
                              hintText:
                                  'Example: SDLC, Agile model, Scrum roles, Sprint planning',
                            ),
                            validator: (value) {
                              if (!isAiMode) {
                                return null;
                              }
                              if ((value ?? '').trim().isEmpty) {
                                return 'Prompt is required for AI generation';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            initialValue: _difficulty,
                            decoration: const InputDecoration(
                              labelText: 'Difficulty level',
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'easy',
                                child: Text('Easy'),
                              ),
                              DropdownMenuItem(
                                value: 'medium',
                                child: Text('Medium'),
                              ),
                              DropdownMenuItem(
                                value: 'hard',
                                child: Text('Hard'),
                              ),
                            ],
                            onChanged: (value) {
                              if (value != null) {
                                setState(() => _difficulty = value);
                              }
                            },
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _questionCountController,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    labelText: 'No. of questions',
                                    hintText: 'Example: 10',
                                  ),
                                  validator: (value) {
                                    if (!isAiMode) {
                                      return null;
                                    }
                                    final count = int.tryParse(
                                      (value ?? '').trim(),
                                    );
                                    if (count == null ||
                                        count < 2 ||
                                        count > 50) {
                                      return 'Use 2 to 50';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextFormField(
                                  controller: _maxMarksController,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    labelText: 'Max marks',
                                    hintText: 'Example: 20',
                                  ),
                                  validator: (value) {
                                    if (!isAiMode) {
                                      return null;
                                    }
                                    final marks = int.tryParse(
                                      (value ?? '').trim(),
                                    );
                                    final count = int.tryParse(
                                      _questionCountController.text.trim(),
                                    );
                                    if (marks == null || marks <= 0) {
                                      return 'Enter valid marks';
                                    }
                                    if (count != null && marks < count) {
                                      return 'Marks must be >= questions';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          const Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Groq key is read from Firestore key/2mVwBh6A9DrMSukIAL1X (field: gemini).',
                              style: TextStyle(
                                color: AppTheme.textMuted,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    _SectionCard(
                      title: 'Upload Question Sheet',
                      subtitle: 'Supported formats: .xlsx and .csv',
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppTheme.panelSoft,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppTheme.strokeSoft),
                        ),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final fileLabel = Text(
                              _excelFile == null
                                  ? 'No file selected'
                                  : '${_excelFile!.name} (${(_excelFile!.size / 1024).toStringAsFixed(1)} KB)',
                              style: Theme.of(context).textTheme.bodyMedium,
                            );

                            if (constraints.maxWidth < 540) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(
                                    LucideIcons.fileSpreadsheet,
                                    size: 30,
                                    color: AppTheme.textMuted,
                                  ),
                                  const SizedBox(height: 10),
                                  fileLabel,
                                  const SizedBox(height: 12),
                                  SizedBox(
                                    width: double.infinity,
                                    child: OutlinedButton(
                                      onPressed: _pickExcelFile,
                                      child: const Text('Choose File'),
                                    ),
                                  ),
                                ],
                              );
                            }

                            return Row(
                              children: [
                                const Icon(
                                  LucideIcons.fileSpreadsheet,
                                  size: 30,
                                  color: AppTheme.textMuted,
                                ),
                                const SizedBox(width: 12),
                                Expanded(child: fileLabel),
                                const SizedBox(width: 12),
                                SizedBox(
                                  width: 160,
                                  child: OutlinedButton(
                                    onPressed: _pickExcelFile,
                                    child: const Text('Choose File'),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                  const SizedBox(height: 20),
                  PressScale(
                    onTap: _isSubmitting ? null : _submit,
                    child: ElevatedButton.icon(
                      onPressed: _isSubmitting ? null : _submit,
                      icon: _isSubmitting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Icon(
                              isAiMode
                                  ? LucideIcons.sparkles
                                  : LucideIcons.uploadCloud,
                              size: 18,
                            ),
                      label: Text(
                        _isSubmitting
                            ? 'Creating quiz...'
                            : isAiMode
                            ? 'Generate & Create Quiz'
                            : 'Upload & Create Quiz',
                      ),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 60),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _ModeButton extends StatelessWidget {
  const _ModeButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PressScale(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: selected
              ? AppTheme.coral.withValues(alpha: 0.18)
              : AppTheme.panelSoft,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? AppTheme.coral : AppTheme.strokeSoft,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: selected ? AppTheme.coral : AppTheme.textMuted,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: selected ? AppTheme.textPrimary : AppTheme.textMuted,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.panel,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppTheme.stroke),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppTheme.textMuted),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

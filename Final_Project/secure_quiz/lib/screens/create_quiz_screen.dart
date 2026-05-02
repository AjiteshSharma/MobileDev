import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../services/quiz_service.dart';

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

  final QuizService _quizService = const QuizService();

  DateTime? _startAt;
  PlatformFile? _excelFile;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _titleController.dispose();
    _subjectController.dispose();
    _batchController.dispose();
    _durationController.dispose();
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
    );

    if (date == null || !mounted) {
      return;
    }

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
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

    final file = _excelFile;
    if (file == null || file.bytes == null) {
      _showSnack('Please upload an Excel file first.');
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
      final quizId = await _quizService.createQuizFromExcel(
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
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(title: const Text('Create Quiz from Excel')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 700),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Quiz Details',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _titleController,
                            decoration: const InputDecoration(
                              labelText: 'Quiz Title',
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
                            ),
                            validator: (value) {
                              final minutes = int.tryParse(
                                (value ?? '').trim(),
                              );
                              if (minutes == null || minutes <= 0) {
                                return 'Enter a valid duration';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  _startAt == null
                                      ? 'Quiz start: Not selected'
                                      : 'Quiz start: ${DateFormat('dd MMM yyyy, hh:mm a').format(_startAt!)}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              OutlinedButton.icon(
                                onPressed: _pickStartDateTime,
                                icon: const Icon(LucideIcons.calendar),
                                label: const Text('Set Date & Time'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Upload Question Sheet',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text('Supported formats: .xlsx, .csv.'),
                          const SizedBox(height: 16),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(0xFFE2E8F0),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  LucideIcons.fileSpreadsheet,
                                  size: 30,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    _excelFile == null
                                        ? 'No file selected'
                                        : '${_excelFile!.name} (${(_excelFile!.size / 1024).toStringAsFixed(1)} KB)',
                                  ),
                                ),
                                OutlinedButton(
                                  onPressed: _pickExcelFile,
                                  child: const Text('Choose File'),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
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
                          : const Icon(LucideIcons.uploadCloud),
                      label: Text(
                        _isSubmitting
                            ? 'Creating quiz...'
                            : 'Upload & Create Quiz',
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF005BBF),
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(54),
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

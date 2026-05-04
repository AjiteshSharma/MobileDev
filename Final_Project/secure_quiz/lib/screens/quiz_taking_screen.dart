import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:screen_protector/screen_protector.dart';

import '../models/app_role.dart';
import '../models/quiz_models.dart';
import '../services/attempt_service.dart';
import '../services/auth_service.dart';
import '../services/quiz_service.dart';
import '../theme/app_theme.dart';
import 'results_screen.dart';

class QuizTakingScreen extends StatefulWidget {
  const QuizTakingScreen({
    super.key,
    required this.quizId,
    required this.quizTitle,
    required this.durationMinutes,
  });

  final String quizId;
  final String quizTitle;
  final int durationMinutes;

  @override
  State<QuizTakingScreen> createState() => _QuizTakingScreenState();
}

class _QuizTakingScreenState extends State<QuizTakingScreen>
    with WidgetsBindingObserver {
  final QuizService _quizService = const QuizService();
  final AttemptService _attemptService = const AttemptService();

  final Map<String, String> _answers = <String, String>{};
  final Map<String, DateTime> _lastViolationByType = <String, DateTime>{};
  final Map<String, List<String>> _shuffledOptionsByQuestionId =
      <String, List<String>>{};

  List<QuizQuestion> _questions = const <QuizQuestion>[];

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
  _attemptSubscription;
  Timer? _timer;

  String? _attemptId;
  String _attemptStatus = 'in_progress';
  String? _errorMessage;

  int _currentQuestionIndex = 0;
  int _remainingSeconds = 0;
  int _violationCount = 0;

  bool _isLoading = true;
  bool _isSubmitting = false;
  bool _quizFinished = false;
  bool _dialogOpen = false;
  bool _isReadOnlyPreview = false;
  bool _navigatedToResults = false;
  bool _isAndroidImmersiveEnabled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_enterQuizImmersiveMode());
    _remainingSeconds = widget.durationMinutes * 60;
    _initializeSecureQuizSession();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _attemptSubscription?.cancel();
    _timer?.cancel();
    unawaited(_restoreSystemUiMode());
    _disableSecureScreen();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!kIsWeb &&
        defaultTargetPlatform == TargetPlatform.android &&
        state == AppLifecycleState.resumed &&
        !_quizFinished) {
      unawaited(_enterQuizImmersiveMode());
    }

    if (_quizFinished || _attemptId == null) {
      return;
    }

    // App lifecycle violation tracking is mobile-only.
    if (kIsWeb) {
      return;
    }

    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _logViolation(
        type: 'app_switch',
        details: 'App moved to $state during quiz attempt.',
      );
    }
  }

  Future<void> _enterQuizImmersiveMode() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return;
    }

    _isAndroidImmersiveEnabled = true;

    try {
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } catch (_) {
      // Ignore unsupported device configuration.
    }
  }

  Future<void> _restoreSystemUiMode() async {
    if (!_isAndroidImmersiveEnabled ||
        kIsWeb ||
        defaultTargetPlatform != TargetPlatform.android) {
      return;
    }

    _isAndroidImmersiveEnabled = false;

    try {
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    } catch (_) {
      // Ignore unsupported device configuration.
    }
  }

  Future<void> _initializeSecureQuizSession() async {
    try {
      await _enableSecureScreen();

      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        setState(() {
          _errorMessage = 'No active session. Please sign in again.';
          _isLoading = false;
        });
        return;
      }

      final role = await const AuthService().getRoleForUser(
        uid: currentUser.uid,
      );
      final isTeacherRole = role == AppRole.teacher;
      var isReadOnlyPreview = isTeacherRole;
      String? attemptId;

      if (!isReadOnlyPreview) {
        final userProfile = await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .get();
        final studentBatch = _normalizeBatch(
          (userProfile.data()?['batch'] as String?) ?? '',
        );
        if (studentBatch.isEmpty) {
          throw StateError(
            'Your account is missing a batch assignment. Contact your teacher/admin.',
          );
        }

        final quizDoc = await FirebaseFirestore.instance
            .collection('quizzes')
            .doc(widget.quizId)
            .get();
        final quizData = quizDoc.data() ?? const <String, dynamic>{};
        final quizBatch = _normalizeBatch((quizData['batch'] as String?) ?? '');
        if (quizBatch.isEmpty) {
          throw StateError(
            'This quiz has no batch configured. Ask your teacher to update it.',
          );
        }

        if (quizBatch != studentBatch) {
          throw StateError(
            'This quiz is for a different batch and cannot be attempted from your account.',
          );
        }
      }

      final questions = await _quizService.getQuizQuestions(widget.quizId);
      final fallbackQuestion = QuizQuestion(
        id: 'fallback_q1',
        text:
            'Question data is unavailable. Ask your teacher to verify quiz upload and parsing.',
        options: const <String>[
          'Retry later',
          'Contact teacher',
          'Continue and submit',
          'Report issue',
        ],
        points: 1,
      );

      final resolvedQuestions = questions.isEmpty
          ? <QuizQuestion>[fallbackQuestion]
          : questions;

      if (!isReadOnlyPreview) {
        try {
          attemptId = await _attemptService.startOrResumeAttempt(
            quizId: widget.quizId,
            studentId: currentUser.uid,
          );

          _attemptSubscription = _attemptService
              .watchAttempt(attemptId)
              .listen(_applyAttemptSnapshot);
        } on FirebaseException catch (error) {
          if (error.code == 'permission-denied') {
            throw FirebaseException(
              plugin: 'cloud_firestore',
              code: error.code,
              message:
                  'You do not have permission to start this quiz from this account.',
            );
          }
          rethrow;
        }
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _questions = resolvedQuestions;
        _attemptId = attemptId;
        _isReadOnlyPreview = isReadOnlyPreview;
        _shuffledOptionsByQuestionId
          ..clear()
          ..addAll(
            _buildShuffledOptionsByQuestion(
              questions: resolvedQuestions,
              userSeed: attemptId ?? currentUser.uid,
            ),
          );
        if (isReadOnlyPreview) {
          _attemptStatus = 'preview';
        }
        _isLoading = false;
      });

      if (_isReadOnlyPreview) {
        _showSnack(
          'Teacher preview mode active. Attempts and violations are not recorded.',
        );
      } else {
        _startTimer();
        _checkScreenRecordingAtStart();
      }
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = 'Failed to open quiz: $error';
        _isLoading = false;
      });
    }
  }

  void _applyAttemptSnapshot(DocumentSnapshot<Map<String, dynamic>> snapshot) {
    final data = snapshot.data();
    if (data == null || !mounted) {
      return;
    }

    final status = (data['status'] as String?) ?? 'in_progress';
    final violations = (data['violationCount'] as num?)?.toInt() ?? 0;
    final hasSubmittedAt = data['submittedAt'] != null;

    final answersMap =
        (data['answers'] as Map<String, dynamic>? ?? <String, dynamic>{}).map(
          (key, value) => MapEntry(key, value.toString()),
        );

    setState(() {
      _attemptStatus = status;
      _violationCount = violations;
      // Merge server answers into local state so recent taps stay visible while
      // async writes are settling on web.
      _answers.addAll(answersMap);
    });

    if (hasSubmittedAt) {
      _quizFinished = true;
      _timer?.cancel();
      _openResultsForAttempt(snapshot.id);
      return;
    }

    if (status == 'disqualified' && !_quizFinished) {
      _forceSubmitBecauseDisqualified();
    }
  }

  void _openResultsForAttempt(String attemptId) {
    if (!mounted || _navigatedToResults) {
      return;
    }

    _navigatedToResults = true;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => ResultsScreen(
          attemptId: attemptId,
          quizId: widget.quizId,
          quizTitle: widget.quizTitle,
        ),
      ),
    );
  }

  String _normalizeBatch(String raw) {
    return raw.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
  }

  Future<void> _enableSecureScreen() async {
    if (kIsWeb) {
      return;
    }

    try {
      await ScreenProtector.preventScreenshotOn();
      await ScreenProtector.protectDataLeakageOn();
      await ScreenProtector.protectDataLeakageWithBlur();

      ScreenProtector.addListener(
        () {
          _logViolation(
            type: 'screenshot',
            details: 'Screenshot event detected.',
          );
        },
        (isRecording) {
          if (isRecording) {
            _logViolation(
              type: 'screen_recording',
              details: 'Screen recording started.',
            );
          }
        },
      );
    } catch (_) {
      // On unsupported platforms these calls can fail; quiz continues.
    }
  }

  Future<void> _disableSecureScreen() async {
    if (kIsWeb) {
      return;
    }

    try {
      ScreenProtector.removeListener();
      await ScreenProtector.preventScreenshotOff();
      await ScreenProtector.protectDataLeakageOff();
      await ScreenProtector.protectDataLeakageWithBlurOff();
    } catch (_) {
      // Ignore cleanup errors.
    }
  }

  Future<void> _checkScreenRecordingAtStart() async {
    if (kIsWeb) {
      return;
    }

    try {
      final isRecording = await ScreenProtector.isRecording();
      if (isRecording) {
        _logViolation(
          type: 'screen_recording',
          details: 'Screen recording was active when quiz started.',
        );
      }
    } catch (_) {
      // Supported only on specific platforms.
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _quizFinished) {
        timer.cancel();
        return;
      }

      if (_remainingSeconds <= 0) {
        timer.cancel();
        _submitQuiz(
          auto: true,
          reason: 'Time is over. Quiz submitted automatically.',
        );
        return;
      }

      setState(() {
        _remainingSeconds--;
      });
    });
  }

  Future<void> _saveAnswer(String questionId, String selectedOption) async {
    final isSubmittedInMonitoredMode =
        !_isReadOnlyPreview && _attemptStatus == 'submitted';
    if (_quizFinished || _isSubmitting || isSubmittedInMonitoredMode) {
      return;
    }

    setState(() {
      _answers[questionId] = selectedOption;
    });

    final attemptId = _attemptId;
    if (attemptId == null) {
      return;
    }

    try {
      await _attemptService.saveAnswer(
        attemptId: attemptId,
        questionId: questionId,
        selectedOption: selectedOption,
      );
    } catch (_) {
      if (mounted) {
        _showSnack('Failed to save answer. Check network connection.');
      }
    }
  }

  Future<void> _logViolation({
    required String type,
    required String details,
  }) async {
    final attemptId = _attemptId;
    final user = FirebaseAuth.instance.currentUser;
    if (attemptId == null || user == null || _quizFinished) {
      return;
    }

    final now = DateTime.now();
    final lastHit = _lastViolationByType[type];
    if (lastHit != null && now.difference(lastHit).inSeconds < 3) {
      return;
    }
    _lastViolationByType[type] = now;

    try {
      final count = await _attemptService.logViolation(
        attemptId: attemptId,
        quizId: widget.quizId,
        studentId: user.uid,
        type: type,
        details: details,
      );

      if (!mounted || _quizFinished) {
        return;
      }

      if (count >= AttemptService.disqualificationThreshold) {
        await _forceSubmitBecauseDisqualified();
        return;
      }

      _showSnack(
        'Security warning recorded ($count). Repeated violations can flag or disqualify this attempt.',
      );
    } catch (_) {
      // Ignore network failures for security logging.
    }
  }

  Future<void> _forceSubmitBecauseDisqualified() async {
    if (_quizFinished || _isSubmitting || _dialogOpen) {
      return;
    }

    _dialogOpen = true;

    if (!mounted) {
      _dialogOpen = false;
      return;
    }

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Attempt Disqualified'),
        content: const Text(
          'Multiple security violations were detected. Your quiz is being submitted and marked disqualified.',
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );

    _dialogOpen = false;
    await _submitQuiz(
      auto: true,
      reason: 'Attempt disqualified due to repeated security violations.',
    );
  }

  Future<void> _submitQuiz({bool auto = false, String? reason}) async {
    if (_isSubmitting || _quizFinished) {
      return;
    }

    if (_isReadOnlyPreview) {
      if (mounted) {
        _showSnack('Preview mode ended.');
        Navigator.pop(context);
      }
      return;
    }

    final attemptId = _attemptId;
    if (attemptId == null) {
      return;
    }

    if (_attemptStatus == 'submitted') {
      _openResultsForAttempt(attemptId);
      return;
    }

    if (!auto) {
      final confirmed = await _confirmSubmit();
      if (!confirmed) {
        return;
      }
    }

    setState(() => _isSubmitting = true);

    try {
      await _attemptService.submitAttempt(
        attemptId: attemptId,
        autoSubmitted: auto,
        submitReason: reason,
      );

      _quizFinished = true;
      _timer?.cancel();

      if (!mounted) {
        return;
      }

      if (reason != null) {
        _showSnack(reason);
      }

      _openResultsForAttempt(attemptId);
    } catch (_) {
      if (mounted) {
        _showSnack('Failed to submit quiz. Please retry.');
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<bool> _confirmSubmit() async {
    final unanswered = _questions
        .where((question) => !_answers.containsKey(question.id))
        .length;

    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Submit Quiz?'),
            content: Text(
              unanswered == 0
                  ? 'All questions are answered. Submit now?'
                  : 'You still have $unanswered unanswered question(s). Submit anyway?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Submit'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _showQuestionGrid() async {
    if (_questions.isEmpty) {
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.panel,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return SizedBox(
          height: MediaQuery.of(context).size.height * 0.7,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Question Overview',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(LucideIcons.x),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _statusLegend(AppTheme.coral, 'Current'),
                    const SizedBox(width: 16),
                    _statusLegend(const Color(0xFF88A9FF), 'Answered'),
                    const SizedBox(width: 16),
                    _statusLegend(AppTheme.stroke, 'Unanswered'),
                  ],
                ),
                const SizedBox(height: 24),
                Expanded(
                  child: GridView.builder(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 5,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                        ),
                    itemCount: _questions.length,
                    itemBuilder: (context, index) {
                      final question = _questions[index];
                      final isCurrent = index == _currentQuestionIndex;
                      final isAnswered = _answers.containsKey(question.id);

                      return InkWell(
                        onTap: () {
                          setState(() => _currentQuestionIndex = index);
                          Navigator.pop(context);
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: isCurrent
                                ? const Color(0xFF2D385F)
                                : (isAnswered
                                      ? const Color(0xFF242F4E)
                                      : AppTheme.panelSoft),
                            border: Border.all(
                              color: isCurrent
                                  ? AppTheme.coral
                                  : AppTheme.stroke,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Center(
                            child: Text(
                              '${index + 1}',
                              style: GoogleFonts.plusJakartaSans(
                                fontWeight: FontWeight.bold,
                                color: isCurrent
                                    ? AppTheme.textPrimary
                                    : AppTheme.textMuted,
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
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_errorMessage != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Quiz Session')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(_errorMessage!),
          ),
        ),
      );
    }

    final question = _questions[_currentQuestionIndex];
    final selected = _answers[question.id];
    final displayOptions =
        _shuffledOptionsByQuestionId[question.id] ?? question.options;
    final totalQuestions = _questions.length;
    final progress = (_currentQuestionIndex + 1) / totalQuestions;

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppTheme.midnight,
        body: Column(
          children: [
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 10, 18, 8),
                child: Row(
                  children: [
                    Text(
                      _formatTimer(_remainingSeconds),
                      style: GoogleFonts.jetBrainsMono(
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const Spacer(),
                    _buildSecurityHearts(),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: progress,
                  backgroundColor: AppTheme.strokeSoft,
                  color: AppTheme.coral,
                  minHeight: 5,
                ),
              ),
            ),
            if (_isReadOnlyPreview ||
                _violationCount > 0 ||
                _attemptStatus == 'disqualified')
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 10, 18, 0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _isReadOnlyPreview
                        ? 'Preview mode active.'
                        : _attemptStatus == 'disqualified'
                        ? 'Attempt disqualified.'
                        : 'Security warnings: $_violationCount',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textMuted,
                    ),
                  ),
                ),
              ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(22, 28, 22, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Text(
                        'Question ${_currentQuestionIndex + 1} out of $totalQuestions',
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textMuted,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 560),
                        child: Text(
                          question.text,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 34,
                            fontWeight: FontWeight.w800,
                            height: 1.15,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 26),
                    ...displayOptions.asMap().entries.map((entry) {
                      final optionText = entry.value;
                      final isSelected = selected == optionText;
                      final isAnswerSelectionLocked =
                          _quizFinished ||
                          _isSubmitting ||
                          (!_isReadOnlyPreview &&
                              _attemptStatus == 'submitted');

                      return _buildOption(
                        text: optionText,
                        isSelected: isSelected,
                        onTap: isAnswerSelectionLocked
                            ? null
                            : () => _saveAnswer(question.id, optionText),
                      );
                    }),
                  ],
                ),
              ),
            ),
          ],
        ),
        bottomNavigationBar: _buildBottomNav(totalQuestions),
      ),
    );
  }

  Widget _buildOption({
    required String text,
    required bool isSelected,
    required VoidCallback? onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: isSelected ? const Color(0xFF656A74) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(
            color: Colors.white.withValues(alpha: isSelected ? 0.95 : 0.85),
            width: isSelected ? 1.4 : 1,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Center(
              child: Text(
                text,
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: isSelected ? Colors.white : const Color(0xFF1B2132),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNav(int totalQuestions) {
    final canGoNext = _currentQuestionIndex < totalQuestions - 1;

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 14),
      decoration: const BoxDecoration(color: AppTheme.midnight),
      child: Row(
        children: [
          TextButton(
            onPressed: _showQuestionGrid,
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              foregroundColor: AppTheme.textPrimary,
            ),
            child: Text(
              'Review (${_answers.length}/$totalQuestions)',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          const Spacer(),
          TextButton(
            onPressed: _isSubmitting
                ? null
                : canGoNext
                ? () => setState(() => _currentQuestionIndex++)
                : () => _submitQuiz(),
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              foregroundColor: Colors.white,
            ),
            child: _isSubmitting
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    canGoNext
                        ? 'Continue'
                        : (_isReadOnlyPreview ? 'Close Preview' : 'Submit'),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSecurityHearts() {
    final threshold = AttemptService.disqualificationThreshold;
    final safeLeft = (threshold - _violationCount).clamp(0, threshold);

    return Row(
      children: List<Widget>.generate(threshold, (index) {
        final isActive = index < safeLeft;
        return Padding(
          padding: EdgeInsets.only(left: index == 0 ? 0 : 4),
          child: Icon(
            Icons.favorite,
            size: 12,
            color: isActive ? Colors.white : const Color(0xFF4E556B),
          ),
        );
      }),
    );
  }

  Widget _statusLegend(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            color: AppTheme.textMuted,
          ),
        ),
      ],
    );
  }

  String _formatTimer(int remainingSeconds) {
    final minutes = remainingSeconds ~/ 60;
    final seconds = remainingSeconds % 60;
    final minutesText = minutes.toString().padLeft(2, '0');
    final secondsText = seconds.toString().padLeft(2, '0');
    return '$minutesText:$secondsText';
  }

  void _showSnack(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Map<String, List<String>> _buildShuffledOptionsByQuestion({
    required List<QuizQuestion> questions,
    required String userSeed,
  }) {
    final normalizedSeed = userSeed.trim().isEmpty ? widget.quizId : userSeed;
    final shuffled = <String, List<String>>{};

    for (final question in questions) {
      final optionEntries = question.options
          .asMap()
          .entries
          .map((entry) => (index: entry.key, text: entry.value))
          .toList(growable: false);

      optionEntries.sort((a, b) {
        final hashA = _stableHash(
          '$normalizedSeed|${question.id}|${a.index}|${a.text}',
        );
        final hashB = _stableHash(
          '$normalizedSeed|${question.id}|${b.index}|${b.text}',
        );
        if (hashA == hashB) {
          return a.index.compareTo(b.index);
        }
        return hashA.compareTo(hashB);
      });

      shuffled[question.id] = optionEntries
          .map((entry) => entry.text)
          .toList(growable: false);
    }

    return shuffled;
  }

  int _stableHash(String value) {
    var hash = 2166136261;
    for (final unit in value.codeUnits) {
      hash ^= unit;
      hash = (hash * 16777619) & 0x7fffffff;
    }

    // Keep an additional tiny mix so option ordering differs better across
    // similar seeds while remaining deterministic.
    return hash ^ (hash >> 13) ^ Random(hash).nextInt(1 << 16);
  }
}

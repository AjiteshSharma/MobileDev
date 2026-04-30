import 'package:flutter/material.dart';
import 'package:secure_quiz/theme/app_theme.dart';
import 'package:secure_quiz/screens/login_screen.dart';
import 'package:secure_quiz/screens/teacher_dashboard.dart';
import 'package:secure_quiz/screens/student_dashboard.dart';
import 'package:secure_quiz/screens/results_screen.dart';
import 'package:secure_quiz/screens/quiz_management_screen.dart';
import 'package:secure_quiz/screens/create_quiz_screen.dart';
import 'package:secure_quiz/screens/quiz_taking_screen.dart';
import 'package:secure_quiz/screens/quiz_preview_screen.dart';

void main() {
  runApp(const EduAssessApp());
}

class EduAssessApp extends StatelessWidget {
  const EduAssessApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EduAssess',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      // In a real app, you'd use a Router or switch based on auth state
      initialRoute: '/',
      routes: {
        '/': (context) => const LoginScreen(),
        '/teacher': (context) => const TeacherDashboard(),
        '/student': (context) => const StudentDashboard(),
        '/results': (context) => const ResultsScreen(),
        '/manage-quizzes': (context) => const QuizManagementScreen(),
        '/create-quiz': (context) => const CreateQuizScreen(),
        '/quiz-preview': (context) => const QuizPreviewScreen(),
        '/take-quiz': (context) => const QuizTakingScreen(),
      },
    );
  }
}
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:secure_quiz/firebase_options.dart';
import 'package:secure_quiz/models/app_role.dart';
import 'package:secure_quiz/screens/create_quiz_screen.dart';
import 'package:secure_quiz/screens/login_screen.dart';
import 'package:secure_quiz/screens/quiz_management_screen.dart';
import 'package:secure_quiz/screens/quiz_preview_screen.dart';
import 'package:secure_quiz/screens/quiz_taking_screen.dart';
import 'package:secure_quiz/screens/student_dashboard.dart';
import 'package:secure_quiz/screens/student_statistics_screen.dart';
import 'package:secure_quiz/screens/teacher_dashboard.dart';
import 'package:secure_quiz/services/auth_service.dart';
import 'package:secure_quiz/state/auth_view_model.dart';
import 'package:secure_quiz/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  Object? firebaseError;
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (error) {
    firebaseError = error;
  }

  runApp(EduAssessApp(firebaseError: firebaseError));
}

class EduAssessApp extends StatelessWidget {
  const EduAssessApp({super.key, this.firebaseError});

  final Object? firebaseError;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthViewModel>(create: (_) => AuthViewModel()),
      ],
      child: MaterialApp(
        title: 'EduAssess',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        home: AppBootstrap(firebaseError: firebaseError),
        routes: {
          '/login': (context) => const LoginScreen(),
          '/teacher': (context) => const TeacherDashboard(),
          '/student': (context) => const StudentDashboard(),
          '/results': (context) => const StudentStatisticsScreen(),
          '/manage-quizzes': (context) => const QuizManagementScreen(),
          '/create-quiz': (context) => const CreateQuizScreen(),
          '/quiz-preview': (context) => const QuizPreviewScreen(),
          '/take-quiz': (context) => const QuizTakingScreen(
            quizId: 'demo_quiz',
            quizTitle: 'Demo Quiz',
            durationMinutes: 30,
          ),
        },
      ),
    );
  }
}

class AppBootstrap extends StatelessWidget {
  const AppBootstrap({super.key, this.firebaseError});

  final Object? firebaseError;

  @override
  Widget build(BuildContext context) {
    if (firebaseError != null) {
      return FirebaseSetupErrorScreen(error: firebaseError!);
    }

    final authService = const AuthService();

    return StreamBuilder<User?>(
      stream: authService.authStateChanges(),
      builder: (context, authSnapshot) {
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return const _LoadingScaffold(label: 'Checking session...');
        }

        final user = authSnapshot.data;
        if (user == null) {
          return const LoginScreen();
        }

        return FutureBuilder<AppRole>(
          future: authService.getRoleForUser(forceRefreshToken: true),
          builder: (context, roleSnapshot) {
            if (roleSnapshot.connectionState == ConnectionState.waiting) {
              return const _LoadingScaffold(label: 'Loading dashboard...');
            }

            if (roleSnapshot.hasError) {
              return RoleLookupErrorScreen(error: roleSnapshot.error!);
            }

            final role = roleSnapshot.data ?? AppRole.unknown;
            switch (role) {
              case AppRole.teacher:
                return const TeacherDashboard();
              case AppRole.student:
                return const StudentDashboard();
              case AppRole.unknown:
                return const UnknownRoleScreen();
            }
          },
        );
      },
    );
  }
}

class _LoadingScaffold extends StatelessWidget {
  const _LoadingScaffold({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(label),
          ],
        ),
      ),
    );
  }
}

class FirebaseSetupErrorScreen extends StatelessWidget {
  const FirebaseSetupErrorScreen({super.key, required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Firebase setup required',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'This app now expects Firebase to be configured. Add Google service files and run FlutterFire setup before login.',
                    ),
                    const SizedBox(height: 16),
                    SelectableText(
                      error.toString(),
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Required files: android/app/google-services.json, ios/Runner/GoogleService-Info.plist, and web Firebase config when running web.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class UnknownRoleScreen extends StatelessWidget {
  const UnknownRoleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Role not assigned',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Your account exists but no valid role is set in Firestore/custom claims. Ask an admin to set role to teacher or student.',
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => const AuthService().signOut(),
                      child: const Text('Sign out'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class RoleLookupErrorScreen extends StatelessWidget {
  const RoleLookupErrorScreen({super.key, required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 550),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Unable to load role',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Login succeeded but role lookup failed. This is usually a Firestore rules or project mismatch issue.',
                    ),
                    const SizedBox(height: 16),
                    SelectableText(
                      error.toString(),
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => const AuthService().signOut(),
                      child: const Text('Sign out'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

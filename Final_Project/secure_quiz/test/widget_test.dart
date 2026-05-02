import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:secure_quiz/models/app_role.dart';
import 'package:secure_quiz/screens/login_screen.dart';
import 'package:secure_quiz/state/auth_view_model.dart';

Future<void> _pumpLoginScreen(WidgetTester tester) async {
  await tester.pumpWidget(
    ChangeNotifierProvider<AuthViewModel>(
      create: (_) => AuthViewModel(),
      child: const MaterialApp(home: LoginScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('login screen renders core controls', (
    WidgetTester tester,
  ) async {
    await _pumpLoginScreen(tester);

    expect(find.text('Sign in'), findsOneWidget);
    expect(find.text('Login to Dashboard'), findsOneWidget);
    expect(find.text('Create new account'), findsOneWidget);
  });

  testWidgets('forgot password option is removed', (WidgetTester tester) async {
    await _pumpLoginScreen(tester);

    expect(find.text('Forgot password?'), findsNothing);
  });

  testWidgets('create account dialog opens with student batch input', (
    WidgetTester tester,
  ) async {
    await _pumpLoginScreen(tester);

    await tester.tap(find.text('Create new account'));
    await tester.pumpAndSettle();

    expect(find.text('Create account'), findsOneWidget);
    expect(find.text('Batch / Class'), findsOneWidget);
  });

  testWidgets('batch field hides when role changes to teacher', (
    WidgetTester tester,
  ) async {
    await _pumpLoginScreen(tester);

    await tester.tap(find.text('Create new account'));
    await tester.pumpAndSettle();

    expect(find.text('Batch / Class'), findsOneWidget);

    await tester.tap(find.byType(DropdownButtonFormField<AppRole>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Teacher').last);
    await tester.pumpAndSettle();

    expect(find.text('Batch / Class'), findsNothing);
  });
}

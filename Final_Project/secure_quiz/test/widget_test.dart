import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secure_quiz/screens/login_screen.dart';

void main() {
  testWidgets('login screen renders core controls', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: LoginScreen()));

    expect(find.text('Sign in'), findsOneWidget);
    expect(find.text('Login to Dashboard'), findsOneWidget);
    expect(find.text('Forgot password?'), findsOneWidget);
  });
}

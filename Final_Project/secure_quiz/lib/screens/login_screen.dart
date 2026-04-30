import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../models/app_role.dart';
import '../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final AuthService _authService = const AuthService();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      _showSnack('Please enter both email and password.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _authService.signInWithEmailPassword(
        email: email,
        password: password,
      );
      final role = await _authService.getRoleForUser(forceRefreshToken: true);

      if (!mounted) {
        return;
      }

      switch (role) {
        case AppRole.teacher:
          Navigator.pushReplacementNamed(context, '/teacher');
          break;
        case AppRole.student:
          Navigator.pushReplacementNamed(context, '/student');
          break;
        case AppRole.unknown:
          _showSnack(
            'Account has no role assigned. Contact your administrator.',
          );
          await _authService.signOut();
          break;
      }
    } on FirebaseAuthException catch (error) {
      _showSnack(_authError(error));
    } catch (_) {
      _showSnack('Unable to sign in right now. Please try again.');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleForgotPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      _showSnack('Enter your email first to reset password.');
      return;
    }

    try {
      await _authService.sendPasswordReset(email);
      if (mounted) {
        _showSnack('Password reset email sent to $email');
      }
    } on FirebaseAuthException catch (error) {
      _showSnack(_authError(error));
    }
  }

  Future<void> _showSignupDialog() async {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final emailController = TextEditingController(text: _emailController.text);
    final passwordController = TextEditingController();
    AppRole selectedRole = AppRole.student;
    bool isSubmitting = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: !isSubmitting,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setLocalState) {
            Future<void> submit() async {
              if (!formKey.currentState!.validate()) {
                return;
              }

              setLocalState(() => isSubmitting = true);
              try {
                await _authService.signUpWithEmailPassword(
                  email: emailController.text,
                  password: passwordController.text,
                  role: selectedRole,
                  displayName: nameController.text,
                );

                if (!mounted) {
                  return;
                }

                Navigator.of(this.context, rootNavigator: true).pop();
                final route = selectedRole == AppRole.teacher
                    ? '/teacher'
                    : '/student';
                Navigator.pushReplacementNamed(this.context, route);
              } on FirebaseAuthException catch (error) {
                if (mounted) {
                  _showSnack(_authError(error));
                }
              } finally {
                if (mounted) {
                  setLocalState(() => isSubmitting = false);
                }
              }
            }

            return AlertDialog(
              title: const Text('Create account'),
              content: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: nameController,
                        decoration: const InputDecoration(
                          labelText: 'Full name',
                        ),
                        validator: (value) => (value ?? '').trim().isEmpty
                            ? 'Name is required'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: emailController,
                        decoration: const InputDecoration(labelText: 'Email'),
                        keyboardType: TextInputType.emailAddress,
                        validator: (value) {
                          final text = (value ?? '').trim();
                          if (text.isEmpty) {
                            return 'Email is required';
                          }
                          if (!text.contains('@')) {
                            return 'Enter a valid email';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: passwordController,
                        decoration: const InputDecoration(
                          labelText: 'Password',
                        ),
                        obscureText: true,
                        validator: (value) {
                          if ((value ?? '').length < 6) {
                            return 'Password must be at least 6 characters';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<AppRole>(
                        initialValue: selectedRole,
                        decoration: const InputDecoration(labelText: 'Role'),
                        items: const [
                          DropdownMenuItem(
                            value: AppRole.student,
                            child: Text('Student'),
                          ),
                          DropdownMenuItem(
                            value: AppRole.teacher,
                            child: Text('Teacher'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setLocalState(() => selectedRole = value);
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting ? null : () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isSubmitting ? null : submit,
                  child: isSubmitting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Create'),
                ),
              ],
            );
          },
        );
      },
    );

    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FF),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    LucideIcons.lock,
                    size: 32,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Sign in',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF181C20),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Access your secure assessments',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF414754),
                  ),
                ),
                const SizedBox(height: 32),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Email address',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          autofillHints: const [AutofillHints.email],
                          decoration: const InputDecoration(
                            hintText: 'name@institution.edu',
                            prefixIcon: Icon(LucideIcons.mail, size: 20),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Password',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                            TextButton(
                              onPressed: _handleForgotPassword,
                              child: const Text('Forgot password?'),
                            ),
                          ],
                        ),
                        TextField(
                          controller: _passwordController,
                          obscureText: true,
                          autofillHints: const [AutofillHints.password],
                          decoration: const InputDecoration(
                            hintText: '••••••••',
                            prefixIcon: Icon(LucideIcons.key, size: 20),
                          ),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: _isLoading ? null : _handleLogin,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(
                              context,
                            ).colorScheme.primary,
                            minimumSize: const Size(double.infinity, 56),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      'Login to Dashboard',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    SizedBox(width: 8),
                                    Icon(
                                      LucideIcons.arrowRight,
                                      size: 18,
                                      color: Colors.white,
                                    ),
                                  ],
                                ),
                        ),
                        const SizedBox(height: 16),
                        OutlinedButton(
                          onPressed: _showSignupDialog,
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 50),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text('Create new account'),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Use Firebase Authentication users with role field in Firestore users/{uid}.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _authError(FirebaseAuthException error) {
    switch (error.code) {
      case 'invalid-email':
        return 'Invalid email format.';
      case 'user-not-found':
        return 'No account found with this email.';
      case 'wrong-password':
      case 'invalid-credential':
        return 'Incorrect email or password.';
      case 'email-already-in-use':
        return 'An account already exists for this email.';
      case 'weak-password':
        return 'Please use a stronger password.';
      default:
        return error.message ?? 'Authentication failed.';
    }
  }

  void _showSnack(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

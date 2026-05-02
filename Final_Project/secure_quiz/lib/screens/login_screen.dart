import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../models/app_role.dart';
import '../state/auth_view_model.dart';
import '../widgets/press_scale.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

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

    final authViewModel = context.read<AuthViewModel>();
    if (authViewModel.isLoginLoading) {
      return;
    }
    try {
      final role = await authViewModel.login(email: email, password: password);

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
          break;
      }
    } on FirebaseAuthException catch (error) {
      _showSnack(_authError(error));
    } catch (_) {
      _showSnack('Unable to sign in right now. Please try again.');
    }
  }

  Future<void> _showSignupDialog() async {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final emailController = TextEditingController(text: _emailController.text);
    final passwordController = TextEditingController();
    final batchController = TextEditingController();
    AppRole selectedRole = AppRole.student;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setLocalState) {
            Future<void> submit() async {
              if (!formKey.currentState!.validate()) {
                return;
              }

              final authViewModel = context.read<AuthViewModel>();
              if (authViewModel.isSignupLoading) {
                return;
              }

              final dialogNavigator = Navigator.of(
                context,
                rootNavigator: true,
              );
              try {
                await authViewModel.signup(
                  email: emailController.text,
                  password: passwordController.text,
                  role: selectedRole,
                  displayName: nameController.text,
                  studentBatch: selectedRole == AppRole.student
                      ? batchController.text
                      : null,
                );

                // Close dialog immediately on successful signup.
                if (dialogNavigator.canPop()) {
                  dialogNavigator.pop();
                }

                // AppBootstrap's auth stream handles routing after signup.
                if (mounted) {
                  _showSnack('Account created successfully.');
                }
              } on FirebaseAuthException catch (error) {
                if (mounted) {
                  _showSnack(_authError(error));
                }
              } on FirebaseException catch (error) {
                if (mounted) {
                  _showSnack(
                    error.message ??
                        'Could not finish account setup. Please retry.',
                  );
                }
              } catch (_) {
                if (mounted) {
                  _showSnack('Could not finish account setup. Please retry.');
                }
              }
            }

            return Consumer<AuthViewModel>(
              builder: (context, authViewModel, _) {
                final isSubmitting = authViewModel.isSignupLoading;
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
                            decoration: const InputDecoration(
                              labelText: 'Email',
                            ),
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
                            decoration: const InputDecoration(
                              labelText: 'Role',
                            ),
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
                            onChanged: isSubmitting
                                ? null
                                : (value) {
                                    if (value != null) {
                                      setLocalState(() {
                                        selectedRole = value;
                                        if (selectedRole != AppRole.student) {
                                          batchController.clear();
                                        }
                                      });
                                    }
                                  },
                          ),
                          if (selectedRole == AppRole.student) ...[
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: batchController,
                              decoration: const InputDecoration(
                                labelText: 'Batch / Class',
                                hintText: 'e.g. bca-5a',
                              ),
                              validator: (value) {
                                if (selectedRole != AppRole.student) {
                                  return null;
                                }
                                final text = (value ?? '').trim();
                                if (text.isEmpty) {
                                  return 'Batch is required for students';
                                }
                                return null;
                              },
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: isSubmitting
                          ? null
                          : () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    PressScale(
                      onTap: isSubmitting ? null : submit,
                      child: ElevatedButton(
                        onPressed: isSubmitting ? null : submit,
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 180),
                          transitionBuilder: (child, animation) =>
                              FadeTransition(opacity: animation, child: child),
                          child: isSubmitting
                              ? const SizedBox(
                                  key: ValueKey('signup-loading'),
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text(
                                  'Create',
                                  key: ValueKey('signup-text'),
                                ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
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
                        Consumer<AuthViewModel>(
                          builder: (context, authViewModel, _) {
                            final isLoading = authViewModel.isLoginLoading;
                            return PressScale(
                              onTap: isLoading ? null : _handleLogin,
                              child: ElevatedButton(
                                onPressed: isLoading ? null : _handleLogin,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Theme.of(
                                    context,
                                  ).colorScheme.primary,
                                  minimumSize: const Size(double.infinity, 56),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 200),
                                  transitionBuilder: (child, animation) =>
                                      FadeTransition(
                                        opacity: animation,
                                        child: ScaleTransition(
                                          scale: animation,
                                          child: child,
                                        ),
                                      ),
                                  child: isLoading
                                      ? const SizedBox(
                                          key: ValueKey('login-loading'),
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Row(
                                          key: ValueKey('login-text'),
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
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
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 16),
                        PressScale(
                          onTap: _showSignupDialog,
                          child: OutlinedButton(
                            onPressed: _showSignupDialog,
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(double.infinity, 50),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text('Create new account'),
                          ),
                        ),
                      ],
                    ),
                  ),
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
      case 'invalid-batch':
        return 'Please enter a valid batch for student account.';
      case 'network-request-failed':
        return 'Network error. Check your internet connection and try again.';
      case 'too-many-requests':
        return 'Too many requests. Please wait a bit and try again.';
      case 'operation-not-allowed':
        return 'Email/password sign-in is not enabled for this project.';
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

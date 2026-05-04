import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../models/app_role.dart';
import '../state/auth_view_model.dart';
import '../theme/app_theme.dart';
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

                if (dialogNavigator.canPop()) {
                  dialogNavigator.pop();
                }

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
                              hintText: 'Example: Aditi Sharma',
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
                              hintText: 'name@institution.edu',
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
                              hintText: 'Minimum 6 characters',
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
                                hintText: 'Example: AIML-6',
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
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _OrbitalHero(),
                  const SizedBox(height: 22),
                  Text(
                    'SecureQuiz',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.4,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'A secure and intuitive quiz platform for students and teachers.',
                    textAlign: TextAlign.center,
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: AppTheme.textMuted),
                  ),

                  const SizedBox(height: 28),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppTheme.panel,
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: AppTheme.stroke),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Email address',
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          autofillHints: const [AutofillHints.email],
                          decoration: const InputDecoration(
                            hintText: 'name@institution.edu',
                            prefixIcon: Icon(LucideIcons.mail, size: 18),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Password',
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _passwordController,
                          obscureText: true,
                          autofillHints: const [AutofillHints.password],
                          decoration: const InputDecoration(
                            hintText: '********',
                            prefixIcon: Icon(LucideIcons.keyRound, size: 18),
                          ),
                        ),
                        const SizedBox(height: 22),
                        Consumer<AuthViewModel>(
                          builder: (context, authViewModel, _) {
                            final isLoading = authViewModel.isLoginLoading;
                            return PressScale(
                              onTap: isLoading ? null : _handleLogin,
                              child: ElevatedButton(
                                onPressed: isLoading ? null : _handleLogin,
                                style: ElevatedButton.styleFrom(
                                  minimumSize: const Size(double.infinity, 62),
                                ),
                                child: AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 180),
                                  transitionBuilder: (child, animation) {
                                    return FadeTransition(
                                      opacity: animation,
                                      child: child,
                                    );
                                  },
                                  child: isLoading
                                      ? const SizedBox(
                                          key: ValueKey('login-loading'),
                                          width: 18,
                                          height: 18,
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
                                            Text("Let's start"),
                                            SizedBox(width: 10),
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
                        const SizedBox(height: 14),
                        PressScale(
                          onTap: _showSignupDialog,
                          child: OutlinedButton(
                            onPressed: _showSignupDialog,
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(double.infinity, 56),
                            ),
                            child: const Text('Need an account? Sign up here'),
                          ),
                        ),
                      ],
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

class _OrbitalHero extends StatelessWidget {
  const _OrbitalHero();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 260,
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.midnight,
          borderRadius: BorderRadius.circular(36),
          border: Border.all(color: AppTheme.strokeSoft),
        ),
        child: Stack(
          children: const [
            _Ring(left: 44, top: 48, size: 58),
            _Ring(right: 34, top: 120, size: 44),
            _Ring(left: 120, bottom: 42, size: 34),
            _Dot(left: 80, top: 148, size: 12, color: Color(0xFF75809A)),
            _Dot(right: 62, top: 66, size: 18, color: Color(0xFF8F97AA)),
            _Dot(left: 196, top: 28, size: 14, color: Colors.white),
            _Dot(right: 128, bottom: 56, size: 24, color: Colors.white),
            _PlanetOrbit(),
          ],
        ),
      ),
    );
  }
}

class _PlanetOrbit extends StatelessWidget {
  const _PlanetOrbit();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: 210,
        height: 210,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 172,
              height: 172,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF73819F), width: 2),
              ),
            ),
            Container(
              width: 88,
              height: 88,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [Color(0xFF993123), Color(0xFFC2513A)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
            Positioned(
              bottom: 12,
              child: Container(
                width: 96,
                height: 96,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [Color(0xFFF8F8F8), Color(0xFFD5D7DE)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Ring extends StatelessWidget {
  const _Ring({
    this.left,
    this.right,
    this.top,
    this.bottom,
    required this.size,
  });

  final double? left;
  final double? right;
  final double? top;
  final double? bottom;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: left,
      right: right,
      top: top,
      bottom: bottom,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFF6F7B95), width: 2),
        ),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({
    this.left,
    this.right,
    this.top,
    this.bottom,
    required this.size,
    required this.color,
  });

  final double? left;
  final double? right;
  final double? top;
  final double? bottom;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: left,
      right: right,
      top: top,
      bottom: bottom,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
    );
  }
}

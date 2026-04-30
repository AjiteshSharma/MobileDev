import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FF),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(LucideIcons.lock, size: 32, color: Colors.white),
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
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Email address', style: TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        const TextField(
                          decoration: InputDecoration(
                            hintText: 'name@institution.edu',
                            prefixIcon: Icon(LucideIcons.mail, size: 20),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Password', style: TextStyle(fontWeight: FontWeight.w600)),
                            TextButton(
                              onPressed: () {},
                              child: const Text('Forgot password?'),
                            ),
                          ],
                        ),
                        const TextField(
                          obscureText: true,
                          decoration: InputDecoration(
                            hintText: '••••••••',
                            prefixIcon: Icon(LucideIcons.key, size: 20),
                          ),
                        ),
                        const SizedBox(height: 32),
                        ElevatedButton(
                          onPressed: () => Navigator.pushReplacementNamed(context, '/teacher'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(context).colorScheme.primary,
                            minimumSize: const Size(double.infinity, 56),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text('Login to Dashboard', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                              SizedBox(width: 8),
                              Icon(LucideIcons.arrowRight, size: 18, color: Colors.white),
                            ],
                          ),
                        ),
                        const SizedBox(height: 32),
                        const Row(
                          children: [
                            Expanded(child: Divider()),
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: 16),
                              child: Text('SECURE ACCESS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
                            ),
                            Expanded(child: Divider()),
                          ],
                        ),
                        const SizedBox(height: 32),
                        OutlinedButton(
                          onPressed: () {},
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 56),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(LucideIcons.contact),
                              SizedBox(width: 12),
                              Text('Sign in with SSO'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                const Text.rich(
                  TextSpan(
                    text: 'Need help? Contact ',
                    children: [
                      TextSpan(
                        text: 'Technical Support',
                        style: TextStyle(color: Color(0xFF005BBF), fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  style: TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

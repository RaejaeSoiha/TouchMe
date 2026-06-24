import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../data/auth_repository.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final email = TextEditingController();
  final token = TextEditingController();
  final password = TextEditingController();
  bool requested = false;
  bool loading = false;
  String? message;

  @override
  void dispose() {
    email.dispose();
    token.dispose();
    password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reset password')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!requested) ...[
              TextField(
                controller: email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email'),
              ),
            ] else ...[
              TextField(
                controller: token,
                decoration: const InputDecoration(labelText: 'Reset token from email'),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: password,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'New password'),
              ),
            ],
            if (message != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(message!),
              ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: loading
                  ? null
                  : () async {
                      setState(() {
                        loading = true;
                        message = null;
                      });
                      try {
                        final repo = ref.read(authRepositoryProvider);
                        if (!requested) {
                          final devToken =
                              await repo.requestPasswordReset(email.text.trim());
                          setState(() {
                            requested = true;
                            if (devToken != null) {
                              token.text = devToken;
                              message =
                                  'Local dev token filled automatically. Enter a new strong password.';
                            } else {
                              message = 'If that email exists, a reset link was sent.';
                            }
                          });
                        } else {
                          final validationError =
                              _validateStrongPassword(password.text);
                          if (validationError != null) {
                            setState(() => message = validationError);
                            return;
                          }
                          await repo.resetPassword(token.text.trim(), password.text);
                          if (context.mounted) context.go('/login');
                        }
                      } catch (_) {
                        setState(() => message = 'Reset failed. Check your token.');
                      } finally {
                        setState(() => loading = false);
                      }
                    },
              child: Text(requested ? 'Set new password' : 'Send reset email'),
            ),
          ],
        ),
      ),
    );
  }
}

String? _validateStrongPassword(String password) {
  if (password.length < 10) return 'Use at least 10 characters';
  if (!RegExp('[a-z]').hasMatch(password)) return 'Add a lowercase letter';
  if (!RegExp('[A-Z]').hasMatch(password)) return 'Add an uppercase letter';
  if (!RegExp('[0-9]').hasMatch(password)) return 'Add a number';
  if (!RegExp(r'[^A-Za-z0-9]').hasMatch(password)) return 'Add a symbol';
  return null;
}

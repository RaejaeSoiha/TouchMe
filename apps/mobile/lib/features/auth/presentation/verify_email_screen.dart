import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../data/auth_repository.dart';

class VerifyEmailScreen extends ConsumerStatefulWidget {
  const VerifyEmailScreen({super.key});

  @override
  ConsumerState<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends ConsumerState<VerifyEmailScreen> {
  final token = TextEditingController();
  bool loading = false;
  String? message;

  @override
  void dispose() {
    token.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Verify email')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Enter the verification token from your email. It expires in 30 minutes.',
            ),
            const SizedBox(height: 20),
            TextField(
              controller: token,
              decoration: const InputDecoration(
                labelText: 'Verification token',
                hintText: 'Paste token from email',
              ),
            ),
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
                      final value = token.text.trim();
                      if (value.isEmpty) {
                        setState(() => message = 'Enter the token from your email.');
                        return;
                      }
                      setState(() {
                        loading = true;
                        message = null;
                      });
                      try {
                        await ref.read(authRepositoryProvider).verifyEmail(value);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Email verified')),
                          );
                          context.go('/home');
                        }
                      } catch (_) {
                        setState(
                          () => message =
                              'Verification failed. Check the token and try again.',
                        );
                      } finally {
                        if (mounted) setState(() => loading = false);
                      }
                    },
              child: Text(loading ? 'Verifying…' : 'Verify email'),
            ),
          ],
        ),
      ),
    );
  }
}

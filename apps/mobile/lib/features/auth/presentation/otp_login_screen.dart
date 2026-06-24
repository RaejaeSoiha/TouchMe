import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../data/auth_repository.dart';
import 'auth_controller.dart';

class OtpLoginScreen extends ConsumerStatefulWidget {
  const OtpLoginScreen({super.key});

  @override
  ConsumerState<OtpLoginScreen> createState() => _OtpLoginScreenState();
}

class _OtpLoginScreenState extends ConsumerState<OtpLoginScreen> {
  final phone = TextEditingController();
  final code = TextEditingController();
  bool codeSent = false;
  bool loading = false;
  String? error;

  @override
  void dispose() {
    phone.dispose();
    code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(authControllerProvider, (_, next) {
      if (next.value == true && context.mounted) context.go('/home');
    });
    return Scaffold(
      appBar: AppBar(title: const Text('Phone sign in')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Phone number',
                hintText: '+1 555 0100',
              ),
            ),
            if (codeSent) ...[
              const SizedBox(height: 16),
              TextField(
                controller: code,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: '6-digit code'),
              ),
            ],
            if (error != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: loading
                  ? null
                  : () async {
                      setState(() {
                        loading = true;
                        error = null;
                      });
                      try {
                        if (!codeSent) {
                          await ref
                              .read(authRepositoryProvider)
                              .requestOtp(phone.text.trim());
                          setState(() => codeSent = true);
                        } else {
                          await ref
                              .read(authControllerProvider.notifier)
                              .verifyOtp(phone.text.trim(), code.text.trim());
                        }
                      } catch (_) {
                        setState(
                          () => error = 'Verification failed. Try again.',
                        );
                      } finally {
                        setState(() => loading = false);
                      }
                    },
              child: Text(
                loading
                    ? 'Please wait…'
                    : codeSent
                    ? 'Verify code'
                    : 'Send code',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

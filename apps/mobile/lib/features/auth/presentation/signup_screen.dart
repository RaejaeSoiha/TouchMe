import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'auth_controller.dart';

class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});
  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final email = TextEditingController();
  final password = TextEditingController();
  final formKey = GlobalKey<FormState>();
  String? errorMessage;

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Join TouchMe')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Icon(Icons.favorite_rounded, size: 56, color: Color(0xFFE84A72)),
          const SizedBox(height: 12),
          Text(
            'Create your TouchMe account',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          const Text(
            'Find people nearby, add friends, and chat freely.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 28),
          Form(
            key: formKey,
            child: Column(
              children: [
                TextFormField(
                  controller: email,
                  decoration: const InputDecoration(labelText: 'Email'),
                  validator: (value) => value?.contains('@') == true
                      ? null
                      : 'Valid email required',
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: password,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Password',
                    helperText:
                        '10+ characters with upper, lower, number and symbol',
                  ),
                  validator: _validateStrongPassword,
                ),
                if (errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 14),
                    child: Text(
                      errorMessage!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: auth.isLoading ? null : _submit,
                  child: const Text('Continue'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    if (!formKey.currentState!.validate()) return;
    setState(() => errorMessage = null);
    await ref
        .read(authControllerProvider.notifier)
        .signup(email.text.trim(), password.text);
    if (!mounted) return;
    final auth = ref.read(authControllerProvider);
    if (auth.hasError) {
      setState(() {
        errorMessage =
            'Could not create account. Use a new email and a strong password.';
      });
      return;
    }
    final authed = auth.value;
    if (authed == true) {
      context.go('/profile/edit');
    }
  }
}

String? _validateStrongPassword(String? value) {
  final password = value ?? '';
  if (password.length < 10) return 'Use at least 10 characters';
  if (!RegExp('[a-z]').hasMatch(password)) return 'Add a lowercase letter';
  if (!RegExp('[A-Z]').hasMatch(password)) return 'Add an uppercase letter';
  if (!RegExp('[0-9]').hasMatch(password)) return 'Add a number';
  if (!RegExp(r'[^A-Za-z0-9]').hasMatch(password)) return 'Add a symbol';
  return null;
}

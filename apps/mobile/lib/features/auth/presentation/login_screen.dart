import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import '../../../core/config/app_config.dart';
import '../../profile/data/profile_repository.dart';
import 'auth_controller.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});
  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final email = TextEditingController();
  final password = TextEditingController();
  final formKey = GlobalKey<FormState>();

  bool get _googleEnabled =>
      !kIsWeb || AppConfig.googleClientId.isNotEmpty;

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> _googleSignIn() async {
    final account = await GoogleSignIn.instance.authenticate(
      scopeHint: const ['email'],
    );
    final auth = account.authentication;
    if (auth.idToken == null) return;
    await ref.read(authControllerProvider.notifier).social('google', auth.idToken!);
  }

  Future<void> _appleSignIn() async {
    final credential = await SignInWithApple.getAppleIDCredential(
      scopes: [AppleIDAuthorizationScopes.email],
    );
    if (credential.identityToken == null) return;
    await ref.read(authControllerProvider.notifier).social(
      'apple',
      credential.identityToken!,
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    ref.listen(authControllerProvider, (_, next) {
      if (next.value == true) {
        ref.invalidate(myProfileProvider);
        context.go('/nearby');
      }
    });
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Form(
                key: formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(
                      Icons.favorite_rounded,
                      size: 64,
                      color: Color(0xFFE84A72),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'TouchMe',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineLarge
                          ?.copyWith(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Find people nearby. Add friends. Chat freely.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 40),
                    TextFormField(
                      controller: email,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      decoration: const InputDecoration(labelText: 'Email'),
                      validator: (value) => value != null && value.contains('@')
                          ? null
                          : 'Enter a valid email',
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: password,
                      obscureText: true,
                      autofillHints: const [AutofillHints.password],
                      decoration: const InputDecoration(labelText: 'Password'),
                      validator: (value) => (value?.length ?? 0) >= 10
                          ? null
                          : 'Use at least 10 characters',
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => context.go('/forgot-password'),
                        child: const Text('Forgot password?'),
                      ),
                    ),
                    if (auth.hasError)
                      Padding(
                        padding: const EdgeInsets.only(top: 14),
                        child: Text(
                          'Sign in failed. Check your credentials and that Docker API is running.',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: auth.isLoading
                          ? null
                          : () {
                              if (formKey.currentState!.validate()) {
                                ref
                                    .read(authControllerProvider.notifier)
                                    .login(email.text.trim(), password.text);
                              }
                            },
                      child: Text(auth.isLoading ? 'Signing in…' : 'Sign in'),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: auth.isLoading ? null : () => context.go('/otp-login'),
                      icon: const Icon(Icons.phone_android_outlined),
                      label: const Text('Continue with phone'),
                    ),
                    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: OutlinedButton.icon(
                          onPressed: auth.isLoading ? null : _appleSignIn,
                          icon: const Icon(Icons.apple),
                          label: const Text('Continue with Apple'),
                        ),
                      ),
                    if (_googleEnabled)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: OutlinedButton.icon(
                          onPressed: auth.isLoading ? null : _googleSignIn,
                          icon: const Icon(Icons.g_mobiledata, size: 28),
                          label: const Text('Continue with Google'),
                        ),
                      ),
                    TextButton(
                      onPressed: () => context.go('/signup'),
                      child: const Text('Create an account'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

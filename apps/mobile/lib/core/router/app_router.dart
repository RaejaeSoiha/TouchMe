import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/presentation/auth_controller.dart';
import '../../features/auth/presentation/forgot_password_screen.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/otp_login_screen.dart';
import '../../features/auth/presentation/signup_screen.dart';
import '../../features/chat/presentation/chat_screen.dart';
import '../../features/conversations/presentation/chats_screen.dart';
import '../../features/discovery/presentation/discovery_screen.dart';
import '../../features/friends/presentation/friends_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/safety/presentation/delete_account_screen.dart';
import '../../features/safety/presentation/safety_screen.dart';
import '../../features/settings/presentation/about_screen.dart';
import '../../features/settings/presentation/search_preferences_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../../features/subscriptions/presentation/passport_screen.dart';
import '../../features/subscriptions/presentation/premium_screen.dart';
import '../widgets/app_shell.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final auth = ref.watch(authControllerProvider);
  return GoRouter(
    initialLocation: '/splash',
    redirect: (context, state) {
      final loggedIn = auth.asData?.value == true;
      final authRoute = state.matchedLocation == '/login' ||
          state.matchedLocation == '/signup' ||
          state.matchedLocation == '/otp-login' ||
          state.matchedLocation == '/forgot-password';
      if (auth.isLoading) {
        return state.matchedLocation == '/splash' ? null : '/splash';
      }
      if (state.matchedLocation == '/splash') {
        return loggedIn ? '/nearby' : '/login';
      }
      if (!loggedIn && !authRoute) return '/login';
      if (loggedIn && authRoute) return '/nearby';
      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, _) => const SplashScreen()),
      GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
      GoRoute(path: '/signup', builder: (_, _) => const SignupScreen()),
      GoRoute(path: '/otp-login', builder: (_, _) => const OtpLoginScreen()),
      GoRoute(path: '/forgot-password', builder: (_, _) => const ForgotPasswordScreen()),
      GoRoute(path: '/settings/safety', builder: (_, _) => const SafetyScreen()),
      GoRoute(path: '/settings/premium', builder: (_, _) => const PremiumScreen()),
      GoRoute(path: '/settings/passport', builder: (_, _) => const PassportScreen()),
      GoRoute(path: '/settings/delete-account', builder: (_, _) => const DeleteAccountScreen()),
      GoRoute(path: '/settings/search-preferences', builder: (_, _) => const SearchPreferencesScreen()),
      GoRoute(path: '/settings/about', builder: (_, _) => const AboutScreen()),
      StatefulShellRoute.indexedStack(
        builder: (_, _, shell) => AppShell(shell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/nearby', builder: (_, _) => const DiscoveryScreen()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/friends', builder: (_, _) => const FriendsScreen()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/chats',
                builder: (_, _) => const ChatsScreen(),
                routes: [
                  GoRoute(
                    path: ':conversationId',
                    builder: (_, state) => ChatScreen(
                      conversationId: state.pathParameters['conversationId']!,
                      title: state.extra as String?,
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                builder: (_, _) => const ProfileScreen(),
                routes: [
                  GoRoute(
                    path: 'edit',
                    builder: (_, _) => const ProfileScreen(editing: true),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/settings', builder: (_, _) => const SettingsScreen()),
            ],
          ),
        ],
      ),
    ],
  );
});

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'core/config/app_config.dart';
import 'core/notifications/notifications_repository.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/notifications/push_service.dart';
import 'core/presence/presence_connection.dart';

final _shownNotificationIds = <String>{};

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _initGoogleSignIn();
  runApp(const ProviderScope(child: TouchMeApp()));
}

Future<void> _initGoogleSignIn() async {
  if (kIsWeb) {
    if (AppConfig.googleClientId.isEmpty) return;
    await GoogleSignIn.instance.initialize(clientId: AppConfig.googleClientId);
    return;
  }
  await GoogleSignIn.instance.initialize();
}

class TouchMeApp extends ConsumerWidget {
  const TouchMeApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(pushRegistrationProvider);
    ref.watch(presenceConnectionProvider);
    ref.watch(notificationPollerProvider);
    return MaterialApp.router(
      title: 'TouchMe',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: ref.watch(routerProvider),
      builder: (context, child) {
        final media = MediaQuery.of(context);
        return _NotificationPopupListener(
          child: MediaQuery(
            data: media.copyWith(
              textScaler: media.textScaler.clamp(maxScaleFactor: 1.3),
            ),
            child: child ?? const SizedBox.shrink(),
          ),
        );
      },
    );
  }
}

class _NotificationPopupListener extends ConsumerWidget {
  const _NotificationPopupListener({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(notificationPollerProvider, (_, next) {
      final notifications = next.asData?.value ?? const <AppNotification>[];
      for (final notification in notifications.reversed) {
        if (notification.readAt != null ||
            _shownNotificationIds.contains(notification.id)) {
          continue;
        }
        _shownNotificationIds.add(notification.id);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!context.mounted) return;
          final messenger = ScaffoldMessenger.maybeOf(context);
          if (messenger == null) return;
          messenger.showSnackBar(
            SnackBar(
              content: Text('${notification.title}: ${notification.body}'),
              action: SnackBarAction(
                label: 'View',
                onPressed: () => _openNotification(ref, notification),
              ),
            ),
          );
        });
      }
    });
    return child;
  }

  void _openNotification(WidgetRef ref, AppNotification notification) {
    final router = ref.read(routerProvider);
    if (notification.type == 'FRIEND_REQUEST') {
      router.go('/friends');
      return;
    }
    final conversationId = notification.data['conversationId']?.toString();
    if (notification.type == 'MESSAGE' && conversationId != null) {
      router.go('/chats/$conversationId');
      return;
    }
    router.go('/notifications');
  }
}

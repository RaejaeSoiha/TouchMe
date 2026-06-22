import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'core/config/app_config.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/notifications/push_service.dart';
import 'core/presence/presence_connection.dart';

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
    return MaterialApp.router(
      title: 'TouchMe',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: ref.watch(routerProvider),
      builder: (context, child) {
        final media = MediaQuery.of(context);
        return MediaQuery(
          data: media.copyWith(
            textScaler: media.textScaler.clamp(maxScaleFactor: 1.3),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}

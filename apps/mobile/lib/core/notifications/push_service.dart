import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/app_config.dart';
import '../network/api_client.dart';
import '../settings/app_settings.dart';

final pushRegistrationProvider = FutureProvider<void>((ref) async {
  if (kIsWeb || AppConfig.firebaseApiKey.isEmpty) return;

  final settings = await ref.watch(appSettingsProvider.future);
  if (!settings.pushNotificationsEnabled) return;

  await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: AppConfig.firebaseApiKey,
      appId: AppConfig.firebaseAppId,
      messagingSenderId: AppConfig.firebaseMessagingSenderId,
      projectId: AppConfig.firebaseProjectId,
    ),
  );
  final messaging = FirebaseMessaging.instance;
  await messaging.requestPermission(alert: true, badge: true, sound: true);
  final token = await messaging.getToken();
  if (token != null) {
    await ref.read(dioProvider).post<void>(
      '/notifications/devices',
      data: {
        'platform':
            defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android',
        'pushToken': token,
      },
    );
  }
});

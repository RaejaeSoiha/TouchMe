import 'package:flutter/foundation.dart';

class AppConfig {
  static const _apiBaseUrl = String.fromEnvironment('API_BASE_URL');
  static const _socketBaseUrl = String.fromEnvironment('SOCKET_BASE_URL');

  static String get apiBaseUrl => _apiBaseUrl.isNotEmpty
      ? _apiBaseUrl
      : kIsWeb
      ? 'http://localhost:3000/api/v1'
      : 'http://10.0.2.2:3000/api/v1';

  static String get socketBaseUrl => _socketBaseUrl.isNotEmpty
      ? _socketBaseUrl
      : kIsWeb
      ? 'http://localhost:3000'
      : 'http://10.0.2.2:3000';

  static const googleClientId = String.fromEnvironment('GOOGLE_CLIENT_ID');
  static const firebaseApiKey = String.fromEnvironment('FIREBASE_API_KEY');
  static const firebaseAppId = String.fromEnvironment('FIREBASE_APP_ID');
  static const firebaseMessagingSenderId = String.fromEnvironment(
    'FIREBASE_MESSAGING_SENDER_ID',
  );
  static const firebaseProjectId = String.fromEnvironment(
    'FIREBASE_PROJECT_ID',
  );
}

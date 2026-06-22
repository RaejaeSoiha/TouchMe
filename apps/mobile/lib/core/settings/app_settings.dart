import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppSettings {
  const AppSettings({required this.pushNotificationsEnabled});
  final bool pushNotificationsEnabled;

  AppSettings copyWith({bool? pushNotificationsEnabled}) => AppSettings(
    pushNotificationsEnabled:
        pushNotificationsEnabled ?? this.pushNotificationsEnabled,
  );
}

final appSettingsProvider =
    AsyncNotifierProvider<AppSettingsController, AppSettings>(
      AppSettingsController.new,
    );

class AppSettingsController extends AsyncNotifier<AppSettings> {
  static const _pushKey = 'push_notifications_enabled';

  @override
  Future<AppSettings> build() async {
    final prefs = await SharedPreferences.getInstance();
    return AppSettings(
      pushNotificationsEnabled: prefs.getBool(_pushKey) ?? true,
    );
  }

  Future<void> setPushNotifications(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_pushKey, enabled);
    state = AsyncData(
      (state.asData?.value ?? const AppSettings(pushNotificationsEnabled: true))
          .copyWith(pushNotificationsEnabled: enabled),
    );
  }
}

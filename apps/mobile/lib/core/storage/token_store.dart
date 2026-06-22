import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

final tokenStoreProvider = Provider<TokenStore>((ref) => TokenStore());

class TokenStore {
  static const _secure = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    webOptions: WebOptions(dbName: 'touch_me', publicKey: 'touch_me'),
  );

  Future<String?> accessToken() async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      var token = prefs.getString('access_token');
      if (token == null) {
        token = await _secure.read(key: 'access_token');
        if (token != null) await prefs.setString('access_token', token);
      }
      return token;
    }
    return _secure.read(key: 'access_token');
  }

  Future<String?> refreshToken() async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      var token = prefs.getString('refresh_token');
      if (token == null) {
        token = await _secure.read(key: 'refresh_token');
        if (token != null) await prefs.setString('refresh_token', token);
      }
      return token;
    }
    return _secure.read(key: 'refresh_token');
  }

  Future<void> save({
    required String accessToken,
    required String refreshToken,
  }) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('access_token', accessToken);
      await prefs.setString('refresh_token', refreshToken);
      return;
    }
    await _secure.write(key: 'access_token', value: accessToken);
    await _secure.write(key: 'refresh_token', value: refreshToken);
  }

  Future<void> clear() async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('access_token');
      await prefs.remove('refresh_token');
      return;
    }
    await _secure.deleteAll();
  }
}

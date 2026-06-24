import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../core/storage/token_store.dart';

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) =>
      AuthRepository(ref.watch(dioProvider), ref.watch(tokenStoreProvider)),
);

class AuthRepository {
  AuthRepository(this._dio, this._tokens);
  final Dio _dio;
  final TokenStore _tokens;
  Future<void> login(String email, String password) async {
    final response = await _dio.post<Map<String, Object?>>(
      '/auth/login',
      data: {'email': email, 'password': password},
    );
    await _save(response.data!);
  }

  Future<void> signup(String email, String password) async {
    final response = await _dio.post<Map<String, Object?>>(
      '/auth/signup',
      data: {'email': email, 'password': password},
    );
    await _save(response.data!);
  }

  Future<void> requestOtp(String phone) =>
      _dio.post<void>('/auth/otp/request', data: {'phone': phone});
  Future<void> verifyOtp(String phone, String code) async {
    final response = await _dio.post<Map<String, Object?>>(
      '/auth/otp/verify',
      data: {'phone': phone, 'code': code},
    );
    await _save(response.data!);
  }

  Future<void> social(String provider, String identityToken) async {
    final response = await _dio.post<Map<String, Object?>>(
      '/auth/social',
      data: {'provider': provider, 'identityToken': identityToken},
    );
    await _save(response.data!);
  }

  Future<String?> requestPasswordReset(String email) async {
    final response = await _dio.post<Map<String, Object?>>(
      '/auth/password/request',
      data: {'email': email},
    );
    return response.data?['devToken'] as String?;
  }

  Future<void> resetPassword(String token, String password) => _dio.post<void>(
    '/auth/password/reset',
    data: {'token': token, 'password': password},
  );

  Future<void> verifyEmail(String token) => _dio.post<void>(
    '/auth/email/verify',
    data: {'token': token},
  );

  Future<void> deleteAccount() => _dio.delete<void>('/auth/account');

  Future<bool> restoreSession() async {
    final access = await _tokens.accessToken();
    final refresh = await _tokens.refreshToken();
    if (access == null && refresh == null) return false;

    try {
      await _dio.get<dynamic>('/profiles/me');
      return true;
    } on DioException catch (error) {
      if (error.response?.statusCode == 404) return true;
      if (error.response?.statusCode == 401) {
        await _tokens.clear();
        return false;
      }
      return true;
    }
  }
  Future<void> logout() async {
    try {
      await _dio.post<void>('/auth/logout');
    } finally {
      await _tokens.clear();
    }
  }

  Future<void> _save(Map<String, Object?> data) => _tokens.save(
    accessToken: data['accessToken']! as String,
    refreshToken: data['refreshToken']! as String,
  );
}

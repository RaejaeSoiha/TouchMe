import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../auth/presentation/auth_controller.dart';
import '../domain/user_profile.dart';

final profileRepositoryProvider = Provider<ProfileRepository>(
  (ref) => ProfileRepository(ref.watch(dioProvider)),
);
final myProfileProvider = FutureProvider<UserProfile?>((ref) async {
  final loggedIn = await ref.watch(authControllerProvider.future);
  if (!loggedIn) return null;
  return ref.watch(profileRepositoryProvider).me();
});
final interestsProvider = FutureProvider<List<Map<String, Object?>>>(
  (ref) => ref.watch(profileRepositoryProvider).interests(),
);

class ProfileRepository {
  ProfileRepository(this._dio);
  final Dio _dio;

  Future<UserProfile?> me() async {
    try {
      final response = await _dio.get<dynamic>('/profiles/me');
      final data = response.data;
      if (data == null || data is! Map<String, Object?>) return null;
      return UserProfile.fromJson(data);
    } on DioException catch (error) {
      if (error.response?.statusCode == 404) return null;
      rethrow;
    }
  }

  Future<UserProfile> save(UserProfile profile) async {
    final response = await _dio.put<Map<String, Object?>>(
      '/profiles/me',
      data: profile.toJson(),
    );
    return UserProfile.fromJson(response.data!);
  }

  Future<void> location(double latitude, double longitude) => _dio.patch<void>(
    '/profiles/me/location',
    data: {'latitude': latitude, 'longitude': longitude},
  );

  Future<void> passport(double latitude, double longitude) => _dio.patch<void>(
    '/profiles/me/passport',
    data: {'latitude': latitude, 'longitude': longitude},
  );

  Future<List<Map<String, Object?>>> interests() async {
    final response = await _dio.get<List<Object?>>('/profiles/interests');
    return response.data!.cast<Map<String, Object?>>();
  }
}

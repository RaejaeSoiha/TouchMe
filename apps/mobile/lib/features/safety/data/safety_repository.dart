import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';

final safetyRepositoryProvider = Provider<SafetyRepository>(
  (ref) => SafetyRepository(ref.watch(dioProvider)),
);

class BlockedUser {
  const BlockedUser({
    required this.id,
    required this.displayName,
    this.photoUrl,
  });
  final String id;
  final String displayName;
  final String? photoUrl;
  factory BlockedUser.fromJson(Map<String, Object?> json) {
    final blocked = json['blocked'] as Map<String, Object?>?;
    final profile = blocked?['profile'] as Map<String, Object?>?;
    final photos = profile?['photos'] as List<Object?>?;
    return BlockedUser(
      id: json['blockedId']! as String,
      displayName: profile?['displayName'] as String? ?? 'User',
      photoUrl:
          photos?.cast<Map<String, Object?>>().firstOrNull?['url'] as String?,
    );
  }
}

class SafetyRepository {
  SafetyRepository(this._dio);
  final Dio _dio;

  Future<void> block(String userId) =>
      _dio.post<void>('/safety/blocks', data: {'userId': userId});
  Future<void> unblock(String userId) =>
      _dio.delete<void>('/safety/blocks/$userId');
  Future<List<BlockedUser>> blocks() async {
    final response = await _dio.get<List<Object?>>('/safety/blocks');
    return response.data!
        .cast<Map<String, Object?>>()
        .map(BlockedUser.fromJson)
        .toList();
  }

  Future<void> report({
    required String userId,
    required String reason,
    String? details,
  }) => _dio.post<void>(
    '/safety/reports',
    data: {'userId': userId, 'reason': reason, 'details': details},
  );
}

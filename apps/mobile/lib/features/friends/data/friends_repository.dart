import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';

final friendsRepositoryProvider = Provider<FriendsRepository>(
  (ref) => FriendsRepository(ref.watch(dioProvider)),
);

final friendsProvider = FutureProvider<List<FriendItem>>(
  (ref) => ref.watch(friendsRepositoryProvider).listFriends(),
);

final friendRequestsProvider = FutureProvider<List<FriendRequestItem>>(
  (ref) => ref.watch(friendsRepositoryProvider).listRequests(),
);

class FriendItem {
  const FriendItem({
    required this.userId,
    required this.displayName,
    this.photoUrl,
    this.online = false,
    this.lastActiveAt,
  });

  final String userId;
  final String displayName;
  final String? photoUrl;
  final bool online;
  final DateTime? lastActiveAt;

  factory FriendItem.fromJson(Map<String, Object?> json) => FriendItem(
    userId: json['userId']! as String,
    displayName: json['displayName']! as String,
    photoUrl: json['photoUrl'] as String?,
    online: json['online'] as bool? ?? false,
    lastActiveAt: json['lastActiveAt'] == null
        ? null
        : DateTime.parse(json['lastActiveAt']! as String),
  );
}

class FriendRequestItem {
  const FriendRequestItem({
    required this.id,
    required this.userId,
    required this.displayName,
    this.photoUrl,
  });

  final String id;
  final String userId;
  final String displayName;
  final String? photoUrl;

  factory FriendRequestItem.fromJson(Map<String, Object?> json) => FriendRequestItem(
    id: json['id']! as String,
    userId: json['userId']! as String,
    displayName: json['displayName']! as String,
    photoUrl: json['photoUrl'] as String?,
  );
}

class FriendsRepository {
  FriendsRepository(this._dio);
  final Dio _dio;

  Future<List<FriendItem>> listFriends() async {
    final response = await _dio.get<List<Object?>>('/friends');
    return response.data!
        .map((item) => FriendItem.fromJson(item! as Map<String, Object?>))
        .toList();
  }

  Future<List<FriendRequestItem>> listRequests() async {
    final response = await _dio.get<List<Object?>>('/friends/requests');
    return response.data!
        .map((item) => FriendRequestItem.fromJson(item! as Map<String, Object?>))
        .toList();
  }

  Future<void> sendRequest(String userId) =>
      _dio.post<void>('/friends/requests', data: {'userId': userId});

  Future<void> acceptRequest(String requestId) =>
      _dio.post<void>('/friends/requests/$requestId/accept');

  Future<void> rejectRequest(String requestId) =>
      _dio.post<void>('/friends/requests/$requestId/reject');

  Future<void> removeFriend(String userId) => _dio.delete<void>('/friends/$userId');
}

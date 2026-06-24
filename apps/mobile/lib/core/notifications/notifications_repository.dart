import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../network/api_client.dart';
import '../../features/auth/presentation/auth_controller.dart';
import '../../features/friends/data/friends_repository.dart';

final notificationsRepositoryProvider = Provider<NotificationsRepository>(
  (ref) => NotificationsRepository(ref.watch(dioProvider)),
);

final notificationPollerProvider = StreamProvider<List<AppNotification>>((
  ref,
) async* {
  final loggedIn = await ref.watch(authControllerProvider.future);
  if (!loggedIn) return;

  while (true) {
    try {
      final notifications = await ref
          .read(notificationsRepositoryProvider)
          .list();
      final hasFriendRequest = notifications.any(
        (notification) =>
            notification.type == 'FRIEND_REQUEST' &&
            notification.readAt == null,
      );
      if (hasFriendRequest) {
        ref.invalidate(friendRequestsProvider);
      }
      yield notifications;
    } on DioException {
      yield const <AppNotification>[];
    }
    await Future<void>.delayed(const Duration(seconds: 10));
  }
});

class AppNotification {
  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.createdAt,
    this.data = const <String, Object?>{},
    this.readAt,
  });

  final String id;
  final String type;
  final String title;
  final String body;
  final Map<String, Object?> data;
  final DateTime createdAt;
  final DateTime? readAt;

  factory AppNotification.fromJson(Map<String, Object?> json) {
    final rawData = json['data'];
    return AppNotification(
      id: json['id']! as String,
      type: json['type']! as String,
      title: json['title']! as String,
      body: json['body']! as String,
      data: rawData is Map
          ? rawData.map((key, value) => MapEntry(key.toString(), value))
          : const <String, Object?>{},
      createdAt: DateTime.parse(json['createdAt']! as String),
      readAt: json['readAt'] == null
          ? null
          : DateTime.parse(json['readAt']! as String),
    );
  }
}

class NotificationsRepository {
  NotificationsRepository(this._dio);
  final Dio _dio;

  Future<List<AppNotification>> list() async {
    final response = await _dio.get<List<Object?>>('/notifications');
    return response.data!
        .map((item) => AppNotification.fromJson(item! as Map<String, Object?>))
        .toList();
  }

  Future<void> markRead(String id) =>
      _dio.patch<void>('/notifications/$id/read');
}

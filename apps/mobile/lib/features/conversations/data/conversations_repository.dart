import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';

final conversationsRepositoryProvider = Provider<ConversationsRepository>(
  (ref) => ConversationsRepository(ref.watch(dioProvider)),
);

final conversationsProvider = FutureProvider<List<ConversationItem>>(
  (ref) => ref.watch(conversationsRepositoryProvider).list(),
);

class ConversationItem {
  const ConversationItem({
    required this.id,
    required this.otherUser,
    this.lastMessage,
  });

  final String id;
  final ConversationUser otherUser;
  final ConversationMessage? lastMessage;

  factory ConversationItem.fromJson(Map<String, Object?> json) {
    final other = json['otherUser'] as Map<String, Object?>?;
    return ConversationItem(
      id: json['id']! as String,
      otherUser: other == null
          ? const ConversationUser(id: '', displayName: 'TouchMe user')
          : ConversationUser.fromJson(other),
      lastMessage: json['lastMessage'] == null
          ? null
          : ConversationMessage.fromJson(json['lastMessage']! as Map<String, Object?>),
    );
  }
}

class ConversationUser {
  const ConversationUser({
    required this.id,
    required this.displayName,
    this.photoUrl,
    this.online = false,
    this.lastActiveAt,
  });

  final String id;
  final String displayName;
  final String? photoUrl;
  final bool online;
  final DateTime? lastActiveAt;

  factory ConversationUser.fromJson(Map<String, Object?> json) => ConversationUser(
    id: json['id']! as String,
    displayName: json['displayName']! as String,
    photoUrl: json['photoUrl'] as String?,
    online: json['online'] as bool? ?? false,
    lastActiveAt: json['lastActiveAt'] == null
        ? null
        : DateTime.parse(json['lastActiveAt']! as String),
  );
}

class ConversationMessage {
  const ConversationMessage({
    required this.body,
    required this.type,
  });

  final String? body;
  final String type;

  factory ConversationMessage.fromJson(Map<String, Object?> json) => ConversationMessage(
    body: json['body'] as String?,
    type: json['type']! as String,
  );
}

class ConversationsRepository {
  ConversationsRepository(this._dio);
  final Dio _dio;

  Future<List<ConversationItem>> list() async {
    final response = await _dio.get<List<Object?>>('/conversations');
    return response.data!
        .map((item) => ConversationItem.fromJson(item! as Map<String, Object?>))
        .toList();
  }

  Future<ConversationItem> open(String userId) async {
    final response = await _dio.post<Map<String, Object?>>(
      '/conversations',
      data: {'userId': userId},
    );
    return ConversationItem.fromJson(response.data!);
  }
}

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../domain/chat_message.dart';

final chatRepositoryProvider = Provider<ChatRepository>(
  (ref) => ChatRepository(ref.watch(dioProvider)),
);

class ChatRepository {
  ChatRepository(this._dio);
  final Dio _dio;

  Future<List<ChatMessage>> messages(String conversationId) async {
    final response = await _dio.get<Map<String, Object?>>(
      '/conversations/$conversationId/messages',
    );
    return (response.data!['items']! as List<Object?>)
        .map((item) => ChatMessage.fromJson(item! as Map<String, Object?>))
        .toList()
        .reversed
        .toList();
  }
}

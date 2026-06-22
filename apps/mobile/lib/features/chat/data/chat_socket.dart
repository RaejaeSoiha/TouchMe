import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import '../../../core/config/app_config.dart';
import '../../../core/storage/token_store.dart';
import '../../../core/presence/presence_event.dart';
import '../domain/chat_message.dart';

final chatSocketProvider = Provider<ChatSocket>((ref) {
  final socket = ChatSocket(ref.watch(tokenStoreProvider));
  ref.onDispose(socket.dispose);
  return socket;
});

class ChatSocket {
  ChatSocket(this._tokens);
  final TokenStore _tokens;
  io.Socket? _socket;
  final _messages = StreamController<ChatMessage>.broadcast();
  final _presence = StreamController<PresenceEvent>.broadcast();
  Timer? _heartbeat;

  Stream<ChatMessage> get messages => _messages.stream;
  Stream<PresenceEvent> get presence => _presence.stream;

  Future<void> connect() async {
    if (_socket?.connected == true) return;
    final token = await _tokens.accessToken();
    _socket = io.io(
      '${AppConfig.socketBaseUrl}/chat',
      io.OptionBuilder()
          .setTransports(['websocket'])
          .setAuth({'token': token})
          .disableAutoConnect()
          .build(),
    );
    _socket!.on('message:new', (Object? value) {
      if (value is Map) {
        _messages.add(ChatMessage.fromJson(Map<String, Object?>.from(value)));
      }
    });
    _socket!.on('presence', (Object? value) {
      if (value is! Map) return;
      final map = Map<String, Object?>.from(value);
      final userId = map['userId'] as String?;
      final online = map['online'] as bool?;
      final lastActiveRaw = map['lastActiveAt'] as String?;
      if (userId == null || online == null || lastActiveRaw == null) return;
      _presence.add(
        PresenceEvent(
          userId: userId,
          online: online,
          lastActiveAt: DateTime.parse(lastActiveRaw),
        ),
      );
    });
    _socket!.connect();
    _startHeartbeat();
  }

  void _startHeartbeat() {
    _heartbeat?.cancel();
    _heartbeat = Timer.periodic(const Duration(seconds: 45), (_) {
      _socket?.emit('presence:heartbeat');
    });
  }

  void stopHeartbeat() {
    _heartbeat?.cancel();
    _heartbeat = null;
  }

  void joinConversation(String conversationId) {
    _socket?.emit('conversation:join', {'conversationId': conversationId});
  }

  void send(Map<String, Object?> message) =>
      _socket?.emit('message:send', message);

  void typing(String conversationId, bool active) => _socket?.emit(
    'typing',
    {'conversationId': conversationId, 'active': active},
  );

  void receipt(String messageId, String status) => _socket?.emit(
    'message:receipt',
    {'messageId': messageId, 'status': status},
  );

  void dispose() {
    stopHeartbeat();
    _socket?.dispose();
    _messages.close();
    _presence.close();
  }
}

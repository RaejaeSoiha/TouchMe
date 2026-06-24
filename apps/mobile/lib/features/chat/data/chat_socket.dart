import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import '../../../core/config/app_config.dart';
import '../../../core/storage/token_store.dart';
import '../../../core/presence/presence_event.dart';
import '../domain/call_signal.dart';
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
  final _callOffers = StreamController<IncomingCall>.broadcast();
  final _callAnswers = StreamController<CallAnswerSignal>.broadcast();
  final _callIce = StreamController<CallIceSignal>.broadcast();
  final _callEnds = StreamController<CallEndSignal>.broadcast();
  final _callBusy = StreamController<CallBusySignal>.broadcast();
  final _typing = StreamController<TypingEvent>.broadcast();
  Timer? _heartbeat;

  Stream<ChatMessage> get messages => _messages.stream;
  Stream<TypingEvent> get typingEvents => _typing.stream;
  Stream<PresenceEvent> get presence => _presence.stream;
  Stream<IncomingCall> get callOffers => _callOffers.stream;
  Stream<CallAnswerSignal> get callAnswers => _callAnswers.stream;
  Stream<CallIceSignal> get callIceEvents => _callIce.stream;
  Stream<CallEndSignal> get callEnds => _callEnds.stream;
  Stream<CallBusySignal> get callBusy => _callBusy.stream;

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
    _socket!.on('typing', (Object? value) {
      if (value is! Map) return;
      final map = Map<String, Object?>.from(value);
      final userId = map['userId'] as String?;
      final active = map['active'] as bool?;
      if (userId == null || active == null) return;
      _typing.add(TypingEvent(userId: userId, active: active));
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
    _socket!.on('call:offer', (Object? value) {
      final map = _eventMap(value);
      if (map == null) return;
      final conversationId = map['conversationId'] as String?;
      final callId = map['callId'] as String?;
      final fromUserId = map['fromUserId'] as String?;
      final media = map['media'] as String?;
      final offer = _eventMap(map['offer']);
      if (conversationId == null ||
          callId == null ||
          fromUserId == null ||
          media == null ||
          offer == null) {
        return;
      }
      _callOffers.add(
        IncomingCall(
          conversationId: conversationId,
          callId: callId,
          fromUserId: fromUserId,
          media: media,
          offer: offer,
        ),
      );
    });
    _socket!.on('call:answer', (Object? value) {
      final map = _eventMap(value);
      final answer = _eventMap(map?['answer']);
      if (map == null || answer == null) return;
      final conversationId = map['conversationId'] as String?;
      final callId = map['callId'] as String?;
      final fromUserId = map['fromUserId'] as String?;
      if (conversationId == null || callId == null || fromUserId == null) {
        return;
      }
      _callAnswers.add(
        CallAnswerSignal(
          conversationId: conversationId,
          callId: callId,
          fromUserId: fromUserId,
          answer: answer,
        ),
      );
    });
    _socket!.on('call:ice', (Object? value) {
      final map = _eventMap(value);
      final candidate = _eventMap(map?['candidate']);
      if (map == null || candidate == null) return;
      final conversationId = map['conversationId'] as String?;
      final callId = map['callId'] as String?;
      final fromUserId = map['fromUserId'] as String?;
      if (conversationId == null || callId == null || fromUserId == null) {
        return;
      }
      _callIce.add(
        CallIceSignal(
          conversationId: conversationId,
          callId: callId,
          fromUserId: fromUserId,
          candidate: candidate,
        ),
      );
    });
    _socket!.on('call:end', (Object? value) {
      final map = _eventMap(value);
      if (map == null) return;
      final conversationId = map['conversationId'] as String?;
      final callId = map['callId'] as String?;
      final fromUserId = map['fromUserId'] as String?;
      final reason = map['reason'] as String?;
      if (conversationId == null ||
          callId == null ||
          fromUserId == null ||
          reason == null) {
        return;
      }
      _callEnds.add(
        CallEndSignal(
          conversationId: conversationId,
          callId: callId,
          fromUserId: fromUserId,
          reason: reason,
        ),
      );
    });
    _socket!.on('call:busy', (Object? value) {
      final map = _eventMap(value);
      if (map == null) return;
      final conversationId = map['conversationId'] as String?;
      final callId = map['callId'] as String?;
      final fromUserId = map['fromUserId'] as String?;
      final busy = map['busy'] as bool?;
      if (conversationId == null ||
          callId == null ||
          fromUserId == null ||
          busy == null) {
        return;
      }
      _callBusy.add(
        CallBusySignal(
          conversationId: conversationId,
          callId: callId,
          fromUserId: fromUserId,
          busy: busy,
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

  void callOffer({
    required String conversationId,
    required String callId,
    required String media,
    required Map<String, Object?> offer,
  }) {
    _socket?.emit('call:offer', {
      'conversationId': conversationId,
      'callId': callId,
      'media': media,
      'offer': offer,
    });
  }

  void callAnswer({
    required String conversationId,
    required String callId,
    required Map<String, Object?> answer,
  }) {
    _socket?.emit('call:answer', {
      'conversationId': conversationId,
      'callId': callId,
      'answer': answer,
    });
  }

  void callIce({
    required String conversationId,
    required String callId,
    required Map<String, Object?> candidate,
  }) {
    _socket?.emit('call:ice', {
      'conversationId': conversationId,
      'callId': callId,
      'candidate': candidate,
    });
  }

  void endCall({
    required String conversationId,
    required String callId,
    required String reason,
  }) {
    _socket?.emit('call:end', {
      'conversationId': conversationId,
      'callId': callId,
      'reason': reason,
    });
  }

  void busyCall({
    required String conversationId,
    required String callId,
  }) {
    _socket?.emit('call:busy', {
      'conversationId': conversationId,
      'callId': callId,
      'busy': true,
    });
  }

  void dispose() {
    stopHeartbeat();
    _socket?.dispose();
    _messages.close();
    _presence.close();
    _callOffers.close();
    _callAnswers.close();
    _callIce.close();
    _callEnds.close();
    _callBusy.close();
    _typing.close();
  }
}

class TypingEvent {
  const TypingEvent({required this.userId, required this.active});
  final String userId;
  final bool active;
}

Map<String, Object?>? _eventMap(Object? value) {
  if (value is! Map) return null;
  return value.map(
    (key, mapValue) => MapEntry(key.toString(), mapValue),
  );
}

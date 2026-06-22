import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/auth/presentation/auth_controller.dart';
import '../../features/chat/data/chat_socket.dart';
import 'presence_event.dart';
import 'presence_provider.dart';

final presenceConnectionProvider = Provider<void>((ref) {
  final auth = ref.watch(authControllerProvider);
  if (auth.asData?.value != true) {
    ref.read(presenceProvider.notifier).clear();
    return;
  }

  final socket = ref.watch(chatSocketProvider);
  StreamSubscription<PresenceEvent>? subscription;

  Future<void>(() async {
    await socket.connect();
    subscription = socket.presence.listen((event) {
      ref.read(presenceProvider.notifier).applyEvent(
        userId: event.userId,
        online: event.online,
        lastActiveAt: event.lastActiveAt,
      );
    });
  });

  ref.onDispose(() async {
    await subscription?.cancel();
    socket.stopHeartbeat();
  });
});

import 'package:flutter_riverpod/flutter_riverpod.dart';

class PresenceState {
  const PresenceState({
    required this.onlineIds,
    required this.lastActiveAt,
  });

  final Set<String> onlineIds;
  final Map<String, DateTime> lastActiveAt;

  bool isOnline(String userId) => onlineIds.contains(userId);

  DateTime? lastActiveAtOf(String userId) => lastActiveAt[userId];

  PresenceState copyWith({
    Set<String>? onlineIds,
    Map<String, DateTime>? lastActiveAt,
  }) => PresenceState(
    onlineIds: onlineIds ?? this.onlineIds,
    lastActiveAt: lastActiveAt ?? this.lastActiveAt,
  );
}

final presenceProvider =
    NotifierProvider<PresenceNotifier, PresenceState>(PresenceNotifier.new);

class PresenceNotifier extends Notifier<PresenceState> {
  @override
  PresenceState build() =>
      const PresenceState(onlineIds: {}, lastActiveAt: {});

  void seedUsers(Iterable<({String userId, bool online, DateTime? lastActiveAt})> users) {
    final online = Set<String>.from(state.onlineIds);
    final active = Map<String, DateTime>.from(state.lastActiveAt);
    for (final user in users) {
      if (user.online) {
        online.add(user.userId);
      } else {
        online.remove(user.userId);
      }
      if (user.lastActiveAt != null) {
        active[user.userId] = user.lastActiveAt!;
      }
    }
    state = state.copyWith(onlineIds: online, lastActiveAt: active);
  }

  void applyEvent({
    required String userId,
    required bool online,
    required DateTime lastActiveAt,
  }) {
    final onlineIds = Set<String>.from(state.onlineIds);
    if (online) {
      onlineIds.add(userId);
    } else {
      onlineIds.remove(userId);
    }
    final active = Map<String, DateTime>.from(state.lastActiveAt)
      ..[userId] = lastActiveAt;
    state = state.copyWith(onlineIds: onlineIds, lastActiveAt: active);
  }

  void clear() {
    state = const PresenceState(onlineIds: {}, lastActiveAt: {});
  }
}

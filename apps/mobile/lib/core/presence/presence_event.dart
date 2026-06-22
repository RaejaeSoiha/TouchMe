class PresenceEvent {
  const PresenceEvent({
    required this.userId,
    required this.online,
    required this.lastActiveAt,
  });

  final String userId;
  final bool online;
  final DateTime lastActiveAt;
}

import 'package:flutter/material.dart';

String formatPresenceLabel({
  required bool online,
  DateTime? lastActiveAt,
}) {
  if (online) return 'Online';
  if (lastActiveAt == null) return 'Offline';
  final diff = DateTime.now().difference(lastActiveAt.toLocal());
  if (diff.inMinutes < 1) return 'Active just now';
  if (diff.inMinutes < 60) return 'Active ${diff.inMinutes}m ago';
  if (diff.inHours < 24) return 'Active ${diff.inHours}h ago';
  if (diff.inDays < 7) return 'Active ${diff.inDays}d ago';
  return 'Offline';
}

Color presenceColor({required bool online, required BuildContext context}) {
  if (online) return const Color(0xFF22C55E);
  return Theme.of(context).colorScheme.outline;
}

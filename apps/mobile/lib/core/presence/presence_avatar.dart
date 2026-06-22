import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'presence_format.dart';
import 'presence_provider.dart';

class UserPresenceAvatar extends ConsumerWidget {
  const UserPresenceAvatar({
    required this.userId,
    required this.radius,
    this.photoUrl,
    this.fallback,
    this.online,
    this.lastActiveAt,
    super.key,
  });

  final String userId;
  final double radius;
  final String? photoUrl;
  final Widget? fallback;
  final bool? online;
  final DateTime? lastActiveAt;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final presence = ref.watch(presenceProvider);
    final isOnline = online ?? presence.isOnline(userId);
    final dotSize = radius * 0.34;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        CircleAvatar(
          radius: radius,
          backgroundImage: photoUrl == null ? null : NetworkImage(photoUrl!),
          child: photoUrl == null ? (fallback ?? const Icon(Icons.person)) : null,
        ),
        Positioned(
          right: 0,
          bottom: 0,
          child: Container(
            width: dotSize,
            height: dotSize,
            decoration: BoxDecoration(
              color: presenceColor(online: isOnline, context: context),
              shape: BoxShape.circle,
              border: Border.all(color: Theme.of(context).colorScheme.surface, width: 2),
            ),
          ),
        ),
      ],
    );
  }
}

class PresenceLabel extends ConsumerWidget {
  const PresenceLabel({
    required this.userId,
    this.online,
    this.lastActiveAt,
    this.style,
    super.key,
  });

  final String userId;
  final bool? online;
  final DateTime? lastActiveAt;
  final TextStyle? style;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final presence = ref.watch(presenceProvider);
    final isOnline = online ?? presence.isOnline(userId);
    final activeAt = lastActiveAt ?? presence.lastActiveAtOf(userId);
    final label = formatPresenceLabel(online: isOnline, lastActiveAt: activeAt);
    return Text(
      label,
      style: (style ?? Theme.of(context).textTheme.bodySmall)?.copyWith(
        color: isOnline
            ? const Color(0xFF22C55E)
            : Theme.of(context).colorScheme.onSurfaceVariant,
        fontWeight: isOnline ? FontWeight.w600 : FontWeight.normal,
      ),
    );
  }
}

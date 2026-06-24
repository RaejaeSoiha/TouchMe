import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../layout/responsive.dart';
import 'notifications_repository.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifications = ref.watch(notificationPollerProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Notifications',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(notificationPollerProvider),
        child: notifications.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => ListView(
            children: [
              Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Could not load notifications: $error'),
              ),
            ],
          ),
          data: (items) {
            if (items.isEmpty) {
              return ListView(
                children: const [
                  Padding(
                    padding: EdgeInsets.all(40),
                    child: Center(child: Text('No notifications yet.')),
                  ),
                ],
              );
            }
            return ResponsiveBody(
              padding: EdgeInsets.zero,
              child: ListView.separated(
                itemCount: items.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (_, index) {
                  final notification = items[index];
                  return ListTile(
                    leading: _NotificationIcon(type: notification.type),
                    title: Text(
                      notification.title,
                      style: TextStyle(
                        fontWeight: notification.readAt == null
                            ? FontWeight.w800
                            : FontWeight.w500,
                      ),
                    ),
                    subtitle: Text(
                      '${notification.body}\n${_formatTime(notification.createdAt)}',
                    ),
                    isThreeLine: true,
                    trailing: notification.readAt == null
                        ? const Icon(Icons.circle, size: 10)
                        : const Icon(Icons.chevron_right),
                    onTap: () => _open(context, ref, notification),
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _open(
    BuildContext context,
    WidgetRef ref,
    AppNotification notification,
  ) async {
    await ref.read(notificationsRepositoryProvider).markRead(notification.id);
    ref.invalidate(notificationPollerProvider);
    if (!context.mounted) return;

    if (notification.type == 'FRIEND_REQUEST') {
      context.go('/friends');
      return;
    }

    final conversationId = notification.data['conversationId']?.toString();
    if (notification.type == 'MESSAGE' && conversationId != null) {
      context.go('/chats/$conversationId');
      return;
    }
  }

  String _formatTime(DateTime value) {
    final local = value.toLocal();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '${local.month}/${local.day}/${local.year} $hour:$minute';
  }
}

class _NotificationIcon extends StatelessWidget {
  const _NotificationIcon({required this.type});

  final String type;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final icon = switch (type) {
      'FRIEND_REQUEST' => Icons.person_add_alt_1,
      'MESSAGE' => Icons.chat_bubble,
      'MATCH' => Icons.favorite,
      'LIKE' => Icons.thumb_up_alt,
      _ => Icons.notifications,
    };
    return CircleAvatar(
      backgroundColor: colorScheme.primaryContainer,
      foregroundColor: colorScheme.onPrimaryContainer,
      child: Icon(icon),
    );
  }
}

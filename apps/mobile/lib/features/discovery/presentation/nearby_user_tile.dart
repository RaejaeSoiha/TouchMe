import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/safety/user_actions_sheet.dart';
import '../../../core/presence/presence_avatar.dart';
import '../../conversations/data/conversations_repository.dart';
import '../../chat/presentation/chat_screen.dart';
import '../../friends/data/friends_repository.dart';
import '../domain/nearby_user.dart';

class NearbyUserTile extends ConsumerWidget {
  const NearbyUserTile({required this.user, super.key});
  final NearbyUser user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final photo = user.profile.photos.isEmpty ? null : user.profile.photos.first.url;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            UserPresenceAvatar(
              userId: user.userId,
              radius: 30,
              photoUrl: photo,
              online: user.online,
              lastActiveAt: user.lastActiveAt,
              fallback: photo == null ? const Icon(Icons.person) : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.profile.displayName,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  PresenceLabel(
                    userId: user.userId,
                    online: user.online,
                    lastActiveAt: user.lastActiveAt,
                  ),
                  Text(
                    '${user.age} yrs · ${user.distanceKm.toStringAsFixed(1)} km away',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  if (user.profile.city != null)
                    Text(
                      user.profile.city!,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                ],
              ),
            ),
            _FriendButton(user: user),
            IconButton(
              tooltip: 'Message',
              onPressed: () async {
                final conversation = await ref
                    .read(conversationsRepositoryProvider)
                    .open(user.userId);
                if (context.mounted) {
                  context.push(
                    '/chats/${conversation.id}',
                    extra: ChatRouteExtra(
                      title: user.profile.displayName,
                      otherUserId: user.userId,
                      otherUserName: user.profile.displayName,
                    ),
                  );
                }
              },
              icon: const Icon(Icons.chat_bubble_outline),
            ),
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'safety') {
                  showBlockReportSheet(
                    context,
                    ref,
                    userId: user.userId,
                    displayName: user.profile.displayName,
                  );
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: 'safety',
                  child: ListTile(
                    leading: Icon(Icons.shield_outlined),
                    title: Text('Block or report'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FriendButton extends ConsumerStatefulWidget {
  const _FriendButton({required this.user});
  final NearbyUser user;

  @override
  ConsumerState<_FriendButton> createState() => _FriendButtonState();
}

class _FriendButtonState extends ConsumerState<_FriendButton> {
  late String status = widget.user.friendStatus;
  bool loading = false;

  Future<void> _addFriend() async {
    setState(() => loading = true);
    try {
      await ref.read(friendsRepositoryProvider).sendRequest(widget.user.userId);
      if (mounted) setState(() => status = 'REQUEST_SENT');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _acceptRequest() async {
    setState(() => loading = true);
    try {
      final requests = await ref.read(friendsRepositoryProvider).listRequests();
      final match = requests.where((r) => r.userId == widget.user.userId).firstOrNull;
      if (match != null) {
        await ref.read(friendsRepositoryProvider).acceptRequest(match.id);
        if (mounted) setState(() => status = 'FRIENDS');
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const SizedBox(
        width: 40,
        height: 40,
        child: Padding(
          padding: EdgeInsets.all(8),
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    switch (status) {
      case 'FRIENDS':
        return const Icon(Icons.check_circle, color: Colors.green);
      case 'REQUEST_SENT':
        return IconButton(
          tooltip: 'Cancel friend request',
          onPressed: () async {
            setState(() => loading = true);
            try {
              await ref
                  .read(friendsRepositoryProvider)
                  .cancelToUser(widget.user.userId);
              if (mounted) setState(() => status = 'NONE');
            } finally {
              if (mounted) setState(() => loading = false);
            }
          },
          icon: const Icon(Icons.hourglass_top, color: Colors.orange),
        );
      case 'REQUEST_RECEIVED':
        return IconButton(
          tooltip: 'Accept friend',
          onPressed: _acceptRequest,
          icon: const Icon(Icons.person_add_alt_1, color: Colors.green),
        );
      default:
        return IconButton(
          tooltip: 'Add friend',
          onPressed: _addFriend,
          icon: const Icon(Icons.person_add_outlined),
        );
    }
  }
}

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/layout/responsive.dart';
import '../../../core/presence/presence_avatar.dart';
import '../../../core/presence/presence_provider.dart';
import '../../conversations/data/conversations_repository.dart';
import '../data/friends_repository.dart';

class FriendsScreen extends ConsumerWidget {
  const FriendsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Friends', style: TextStyle(fontWeight: FontWeight.w900)),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'My friends'),
              Tab(text: 'Requests'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _FriendsList(
              onRefresh: () async {
                ref.invalidate(friendsProvider);
              },
            ),
            _RequestsList(
              onRefresh: () async {
                ref.invalidate(friendRequestsProvider);
                ref.invalidate(friendsProvider);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _FriendsList extends ConsumerWidget {
  const _FriendsList({required this.onRefresh});
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final friends = ref.watch(friendsProvider);
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: friends.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => ListView(
          children: [Padding(padding: const EdgeInsets.all(24), child: Text('$error'))],
        ),
        data: (items) {
          if (items.isEmpty) {
            return ListView(
              children: const [
                Padding(
                  padding: EdgeInsets.all(40),
                  child: Center(child: Text('Add friends from the Nearby tab.')),
                ),
              ],
            );
          }
          ref.read(presenceProvider.notifier).seedUsers(
            items.map(
              (friend) => (
                userId: friend.userId,
                online: friend.online,
                lastActiveAt: friend.lastActiveAt,
              ),
            ),
          );
          return ResponsiveBody(
            padding: EdgeInsets.zero,
            child: ListView.separated(
            itemCount: items.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (_, index) {
              final friend = items[index];
              return ListTile(
                leading: UserPresenceAvatar(
                  userId: friend.userId,
                  radius: 22,
                  photoUrl: friend.photoUrl,
                  online: friend.online,
                  lastActiveAt: friend.lastActiveAt,
                  fallback: friend.photoUrl == null ? const Icon(Icons.person) : null,
                ),
                title: Text(friend.displayName),
                subtitle: PresenceLabel(
                  userId: friend.userId,
                  online: friend.online,
                  lastActiveAt: friend.lastActiveAt,
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chat_bubble_outline),
                      onPressed: () async {
                        final conversation = await ref
                            .read(conversationsRepositoryProvider)
                            .open(friend.userId);
                        if (context.mounted) context.push('/chats/${conversation.id}');
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.person_remove_outlined),
                      onPressed: () async {
                        await ref.read(friendsRepositoryProvider).removeFriend(friend.userId);
                        onRefresh();
                      },
                    ),
                  ],
                ),
              );
            },
          ),
          );
        },
      ),
    );
  }
}

class _RequestsList extends ConsumerWidget {
  const _RequestsList({required this.onRefresh});
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requests = ref.watch(friendRequestsProvider);
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: requests.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => ListView(
          children: [Padding(padding: const EdgeInsets.all(24), child: Text('$error'))],
        ),
        data: (items) {
          if (items.isEmpty) {
            return ListView(
              children: const [
                Padding(
                  padding: EdgeInsets.all(40),
                  child: Center(child: Text('No pending friend requests.')),
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
              final request = items[index];
              return ListTile(
                leading: CircleAvatar(
                  backgroundImage: request.photoUrl == null
                      ? null
                      : CachedNetworkImageProvider(request.photoUrl!),
                  child: request.photoUrl == null ? const Icon(Icons.person) : null,
                ),
                title: Text(request.displayName),
                subtitle: const Text('Wants to be your friend'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.check_circle, color: Colors.green),
                      onPressed: () async {
                        await ref.read(friendsRepositoryProvider).acceptRequest(request.id);
                        onRefresh();
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.cancel_outlined, color: Colors.red),
                      onPressed: () async {
                        await ref.read(friendsRepositoryProvider).rejectRequest(request.id);
                        onRefresh();
                      },
                    ),
                  ],
                ),
              );
            },
          ),
          );
        },
      ),
    );
  }
}

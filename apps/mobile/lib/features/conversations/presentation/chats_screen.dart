import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/layout/responsive.dart';
import '../../../core/presence/presence_avatar.dart';
import '../../../core/presence/presence_provider.dart';
import '../../chat/presentation/chat_screen.dart';
import '../data/conversations_repository.dart';

class ChatsScreen extends ConsumerWidget {
  const ChatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chats = ref.watch(conversationsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Messages', style: TextStyle(fontWeight: FontWeight.w900)),
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(conversationsProvider),
        child: chats.when(
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
                    child: Center(
                      child: Text('Message anyone nearby — no friend request required.'),
                    ),
                  ),
                ],
              );
            }
            scheduleWidgetPresenceSeed(ref,
              items.map(
                (chat) => (
                  userId: chat.otherUser.id,
                  online: chat.otherUser.online,
                  lastActiveAt: chat.otherUser.lastActiveAt,
                ),
              ),
            );
            return ResponsiveBody(
              padding: EdgeInsets.zero,
              child: ListView.separated(
                itemCount: items.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (_, index) {
                final chat = items[index];
                final preview = chat.lastMessage?.type == 'TEXT'
                    ? (chat.lastMessage?.body ?? '')
                    : chat.lastMessage?.type == 'IMAGE'
                        ? 'Photo'
                        : chat.lastMessage?.type == 'VOICE'
                            ? 'Voice note'
                            : 'Start chatting';
                return ListTile(
                  onTap: () => context.push(
                    '/chats/${chat.id}',
                    extra: ChatRouteExtra(
                      title: chat.otherUser.displayName,
                      otherUserId: chat.otherUser.id,
                      otherUserName: chat.otherUser.displayName,
                    ),
                  ),
                  leading: UserPresenceAvatar(
                    userId: chat.otherUser.id,
                    radius: 22,
                    photoUrl: chat.otherUser.photoUrl,
                    online: chat.otherUser.online,
                    lastActiveAt: chat.otherUser.lastActiveAt,
                    fallback: chat.otherUser.photoUrl == null
                        ? const Icon(Icons.person)
                        : null,
                  ),
                  title: Text(chat.otherUser.displayName),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      PresenceLabel(
                        userId: chat.otherUser.id,
                        online: chat.otherUser.online,
                        lastActiveAt: chat.otherUser.lastActiveAt,
                      ),
                      Text(preview, maxLines: 1, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                  trailing: const Icon(Icons.chevron_right),
                );
              },
            ),
            );
          },
        ),
      ),
    );
  }
}

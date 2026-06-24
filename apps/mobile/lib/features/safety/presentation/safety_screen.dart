import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/layout/responsive.dart';
import '../../../core/safety/user_actions_sheet.dart';
import '../data/safety_repository.dart';

final blockedUsersProvider = FutureProvider<List<BlockedUser>>(
  (ref) => ref.watch(safetyRepositoryProvider).blocks(),
);

class SafetyScreen extends ConsumerWidget {
  const SafetyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final blocks = ref.watch(blockedUsersProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Safety center', style: TextStyle(fontWeight: FontWeight.w900)),
      ),
      body: ResponsiveBody(
        child: ListView(
        children: [
          const Text(
            'Blocked accounts',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          blocks.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Text('Could not load blocks: $error'),
            data: (users) => users.isEmpty
                ? const Text('You have not blocked anyone.')
                : Column(
                    children: users
                        .map(
                          (user) => ListTile(
                            leading: CircleAvatar(
                              backgroundImage: user.photoUrl == null
                                  ? null
                                  : NetworkImage(user.photoUrl!),
                              child: user.photoUrl == null
                                  ? const Icon(Icons.person)
                                  : null,
                            ),
                            title: Text(user.displayName),
                            trailing: TextButton(
                              onPressed: () async {
                                await ref
                                    .read(safetyRepositoryProvider)
                                    .unblock(user.id);
                                ref.invalidate(blockedUsersProvider);
                              },
                              child: const Text('Unblock'),
                            ),
                          ),
                        )
                        .toList(),
                  ),
          ),
          const Divider(height: 40),
          ListTile(
            leading: const Icon(Icons.policy_outlined),
            title: const Text('Community guidelines'),
            subtitle: const Text('Be respectful. Report harassment or fake profiles from chat.'),
            onTap: () => showCommunityGuidelines(context),
          ),
          ListTile(
            leading: const Icon(Icons.delete_forever_outlined, color: Colors.red),
            title: const Text('Delete account'),
            subtitle: const Text('Permanently remove your profile and data'),
            onTap: () => context.push('/settings/delete-account'),
          ),
        ],
      ),
      ),
    );
  }
}

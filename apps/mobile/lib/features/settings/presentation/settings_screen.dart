import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/layout/responsive.dart';
import '../../../core/notifications/push_service.dart';
import '../../../core/settings/app_settings.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../profile/data/profile_repository.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({this.embedded = false, super.key});

  final bool embedded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(myProfileProvider);
    final settings = ref.watch(appSettingsProvider);

    return Scaffold(
      appBar: embedded
          ? null
          : AppBar(
              title: const Text(
                'Settings',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
      body: ResponsiveBody(
        child: ListView(
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: Theme.of(
                        context,
                      ).colorScheme.primaryContainer,
                      child: const Icon(
                        Icons.favorite_rounded,
                        color: Color(0xFFE84A72),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'TouchMe',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(height: 4),
                          profile.when(
                            loading: () => const Text('Loading profile…'),
                            error: (_, _) => const Text('Version 1.0.0'),
                            data: (data) => Text(
                              data == null
                                  ? 'Complete your profile'
                                  : '${data.displayName} · v1.0.0',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SectionHeader('ACCOUNT'),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.person_outline),
                    title: const Text('Edit profile'),
                    subtitle: const Text('Photos, bio, interests'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.go('/profile/edit'),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.tune),
                    title: const Text('Default search preferences'),
                    subtitle: const Text('Gender, age range, and distance'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push('/settings/search-preferences'),
                  ),
                ],
              ),
            ),
            const SectionHeader('PRIVACY'),
            Card(
              child: Column(
                children: [
                  profile.when(
                    loading: () => const ListTile(
                      title: Text('Show me on Nearby'),
                      subtitle: Text('Loading…'),
                    ),
                    error: (_, _) => const SizedBox.shrink(),
                    data: (data) {
                      if (data == null) return const SizedBox.shrink();
                      return SwitchListTile(
                        secondary: const Icon(Icons.visibility_outlined),
                        title: const Text('Show me on Nearby'),
                        subtitle: const Text(
                          'When off, others cannot find you in search',
                        ),
                        value: data.discoverable,
                        onChanged: (value) async {
                          await ref
                              .read(profileRepositoryProvider)
                              .save(data.copyWith(discoverable: value));
                          ref.invalidate(myProfileProvider);
                        },
                      );
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.shield_outlined),
                    title: const Text('Safety center'),
                    subtitle: const Text(
                      'Blocked users, reports, delete account',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push('/settings/safety'),
                  ),
                ],
              ),
            ),
            const SectionHeader('NOTIFICATIONS'),
            Card(
              child: settings.when(
                loading: () => const ListTile(
                  title: Text('Push notifications'),
                  subtitle: Text('Loading…'),
                ),
                error: (_, _) => const SizedBox.shrink(),
                data: (prefs) => SwitchListTile(
                  secondary: const Icon(Icons.notifications_outlined),
                  title: const Text('Push notifications'),
                  subtitle: Text(
                    prefs.pushNotificationsEnabled
                        ? 'Messages and friend requests'
                        : 'Disabled on this device',
                  ),
                  value: prefs.pushNotificationsEnabled,
                  onChanged: (value) async {
                    await ref
                        .read(appSettingsProvider.notifier)
                        .setPushNotifications(value);
                    ref.invalidate(pushRegistrationProvider);
                  },
                ),
              ),
            ),
            const SectionHeader('TOUCHME PLUS'),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.workspace_premium_outlined),
                    title: const Text('TouchMe Plus'),
                    subtitle: const Text(
                      'Wider search, featured nearby, explore cities',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push('/settings/premium'),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.public),
                    title: const Text('Explore another city'),
                    subtitle: const Text(
                      'Change your location on the nearby list',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push('/settings/passport'),
                  ),
                ],
              ),
            ),
            const SectionHeader('SUPPORT'),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.info_outline),
                    title: const Text('About TouchMe'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push('/settings/about'),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.policy_outlined),
                    title: const Text('Community guidelines'),
                    subtitle: const Text(
                      'Be kind, report abuse, respect privacy',
                    ),
                    onTap: () => showDialog<void>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Community guidelines'),
                        content: const Text(
                          'TouchMe is for genuine nearby connections.\n\n'
                          '• Be respectful in messages\n'
                          '• Do not harass or spam\n'
                          '• Report fake profiles or abuse\n'
                          '• Block anyone who makes you uncomfortable',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Got it'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.logout),
                    title: const Text('Sign out'),
                    onTap: () async {
                      await ref.read(authControllerProvider.notifier).logout();
                      if (context.mounted) context.go('/login');
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(
                      Icons.delete_forever_outlined,
                      color: Colors.red,
                    ),
                    title: const Text(
                      'Delete account',
                      style: TextStyle(color: Colors.red),
                    ),
                    onTap: () => context.push('/settings/delete-account'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

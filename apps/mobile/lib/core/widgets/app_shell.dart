import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../notifications/notifications_repository.dart';
import '../../features/friends/data/friends_repository.dart';

class AppShell extends ConsumerWidget {
  const AppShell({required this.shell, super.key});
  final StatefulNavigationShell shell;

  static const _destinations = [
    (icon: Icons.home_outlined, selected: Icons.home, label: 'Home'),
    (icon: Icons.near_me_outlined, selected: Icons.near_me, label: 'Nearby'),
    (icon: Icons.people_outline, selected: Icons.people, label: 'Friends'),
    (
      icon: Icons.chat_bubble_outline,
      selected: Icons.chat_bubble,
      label: 'Messages',
    ),
    (
      icon: Icons.notifications_outlined,
      selected: Icons.notifications,
      label: 'Alerts',
    ),
    (icon: Icons.person_outline, selected: Icons.person, label: 'Account'),
  ];

  void _go(int index) =>
      shell.goBranch(index, initialLocation: index == shell.currentIndex);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final width = MediaQuery.sizeOf(context).width;
    final useRail = width >= 600;
    final requestCount = ref
        .watch(friendRequestsProvider)
        .maybeWhen(data: (items) => items.length, orElse: () => 0);
    final unreadNotificationCount = ref
        .watch(notificationPollerProvider)
        .maybeWhen(
          data: (items) =>
              items.where((notification) => notification.readAt == null).length,
          orElse: () => 0,
        );

    if (useRail) {
      final extended = width >= 1100;
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              extended: extended,
              selectedIndex: shell.currentIndex,
              onDestinationSelected: _go,
              labelType: extended
                  ? NavigationRailLabelType.none
                  : NavigationRailLabelType.selected,
              destinations: _destinations
                  .map(
                    (item) => NavigationRailDestination(
                      icon: _NavIcon(
                        icon: item.icon,
                        badgeCount: _badgeCountFor(
                          item.label,
                          requestCount,
                          unreadNotificationCount,
                        ),
                      ),
                      selectedIcon: _NavIcon(
                        icon: item.selected,
                        badgeCount: _badgeCountFor(
                          item.label,
                          requestCount,
                          unreadNotificationCount,
                        ),
                      ),
                      label: Text(item.label),
                    ),
                  )
                  .toList(),
            ),
            const VerticalDivider(width: 1),
            Expanded(child: shell),
          ],
        ),
      );
    }

    return Scaffold(
      body: shell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: shell.currentIndex,
        onDestinationSelected: _go,
        destinations: _destinations
            .map(
              (item) => NavigationDestination(
                icon: _NavIcon(
                  icon: item.icon,
                  badgeCount: _badgeCountFor(
                    item.label,
                    requestCount,
                    unreadNotificationCount,
                  ),
                ),
                selectedIcon: _NavIcon(
                  icon: item.selected,
                  badgeCount: _badgeCountFor(
                    item.label,
                    requestCount,
                    unreadNotificationCount,
                  ),
                ),
                label: item.label,
              ),
            )
            .toList(),
      ),
    );
  }

  int _badgeCountFor(
    String label,
    int requestCount,
    int unreadNotificationCount,
  ) {
    if (label == 'Friends') return requestCount;
    if (label == 'Alerts') return unreadNotificationCount;
    return 0;
  }
}

class _NavIcon extends StatelessWidget {
  const _NavIcon({required this.icon, required this.badgeCount});

  final IconData icon;
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    if (badgeCount <= 0) return Icon(icon);
    return Badge.count(count: badgeCount, child: Icon(icon));
  }
}

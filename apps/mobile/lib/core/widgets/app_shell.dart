import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AppShell extends StatelessWidget {
  const AppShell({required this.shell, super.key});
  final StatefulNavigationShell shell;

  static const _destinations = [
    (icon: Icons.near_me_outlined, selected: Icons.near_me, label: 'Nearby'),
    (icon: Icons.people_outline, selected: Icons.people, label: 'Friends'),
    (icon: Icons.chat_bubble_outline, selected: Icons.chat_bubble, label: 'Messages'),
    (icon: Icons.person_outline, selected: Icons.person, label: 'Profile'),
    (icon: Icons.settings_outlined, selected: Icons.settings, label: 'Settings'),
  ];

  void _go(int index) =>
      shell.goBranch(index, initialLocation: index == shell.currentIndex);

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final useRail = width >= 600;

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
                      icon: Icon(item.icon),
                      selectedIcon: Icon(item.selected),
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
                icon: Icon(item.icon),
                selectedIcon: Icon(item.selected),
                label: item.label,
              ),
            )
            .toList(),
      ),
    );
  }
}

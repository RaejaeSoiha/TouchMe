import 'package:flutter/material.dart';
import '../../profile/presentation/profile_screen.dart';
import '../../settings/presentation/settings_screen.dart';

class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AccountAppBar(),
        body: TabBarView(
          children: [
            ProfileScreen(embedded: true),
            SettingsScreen(embedded: true),
          ],
        ),
      ),
    );
  }
}

class AccountAppBar extends StatelessWidget implements PreferredSizeWidget {
  const AccountAppBar({super.key});

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight + 48);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: const Text(
        'Account',
        style: TextStyle(fontWeight: FontWeight.w900),
      ),
      bottom: const TabBar(
        tabs: [
          Tab(icon: Icon(Icons.person_outline), text: 'Profile'),
          Tab(icon: Icon(Icons.settings_outlined), text: 'Settings'),
        ],
      ),
    );
  }
}

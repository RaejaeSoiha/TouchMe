import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/layout/responsive.dart';
import '../../profile/data/profile_repository.dart';
import '../data/discovery_repository.dart';
import 'discovery_controller.dart';
import 'discovery_filters_sheet.dart';
import 'nearby_user_tile.dart';

class DiscoveryScreen extends ConsumerWidget {
  const DiscoveryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(discoveryControllerProvider);
    final filters = ref.watch(discoveryFiltersProvider);
    final columns = Responsive.gridColumns(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('TouchMe', style: TextStyle(fontWeight: FontWeight.w900)),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Filters',
            onPressed: () async {
              final profile = await ref.read(myProfileProvider.future);
              if (profile == null || !context.mounted) return;
              final current = filters ??
                  DiscoveryFilters(
                    minAge: profile.minAge,
                    maxAge: profile.maxAge,
                    maxDistanceKm: profile.maxDistanceKm,
                    genders: profile.showMe.toList(),
                  );
              final next = await showDiscoveryFiltersSheet(context, current);
              if (next != null) {
                await ref.read(discoveryControllerProvider.notifier).applyFilters(next);
              }
            },
            icon: const Icon(Icons.tune),
          ),
        ],
      ),
      body: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) {
          final message = error.toString();
          if (message.contains('PROFILE_INCOMPLETE')) {
            return Center(
              child: ResponsiveBody(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.person_outline, size: 64),
                    const SizedBox(height: 16),
                    const Text(
                      'Set up your profile to find people nearby.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: () => context.go('/profile/edit'),
                      child: const Text('Set up profile'),
                    ),
                  ],
                ),
              ),
            );
          }
          return Center(child: Text('Could not load nearby people: $error'));
        },
        data: (items) {
          if (items.isEmpty) {
            return const Center(child: Text('No one nearby matches your filters.'));
          }
          return RefreshIndicator(
            onRefresh: () => ref.read(discoveryControllerProvider.notifier).refresh(),
            child: NotificationListener<ScrollNotification>(
              onNotification: (notification) {
                if (notification.metrics.pixels >=
                    notification.metrics.maxScrollExtent - 200) {
                  ref.read(discoveryControllerProvider.notifier).loadMore();
                }
                return false;
              },
              child: columns == 1
                  ? ListView.builder(
                      padding: Responsive.pagePadding(context),
                      itemCount: items.length,
                      itemBuilder: (_, index) => NearbyUserTile(user: items[index]),
                    )
                  : ResponsiveBody(
                      padding: Responsive.pagePadding(context),
                      child: GridView.builder(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: columns,
                          mainAxisExtent: 108,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 8,
                        ),
                        itemCount: items.length,
                        itemBuilder: (_, index) => NearbyUserTile(user: items[index]),
                      ),
                    ),
            ),
          );
        },
      ),
    );
  }
}

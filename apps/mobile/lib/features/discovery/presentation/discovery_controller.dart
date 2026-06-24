import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import '../../../core/presence/presence_provider.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../profile/data/profile_repository.dart';
import '../data/discovery_repository.dart';
import '../domain/nearby_user.dart';

final discoveryFiltersProvider =
    NotifierProvider<DiscoveryFiltersNotifier, DiscoveryFilters?>(
      DiscoveryFiltersNotifier.new,
    );

class DiscoveryFiltersNotifier extends Notifier<DiscoveryFilters?> {
  @override
  DiscoveryFilters? build() => null;

  void set(DiscoveryFilters? value) => state = value;
}

final discoveryControllerProvider =
    AsyncNotifierProvider<DiscoveryController, List<NearbyUser>>(
      DiscoveryController.new,
    );

class DiscoveryController extends AsyncNotifier<List<NearbyUser>> {
  String? cursor;

  @override
  Future<List<NearbyUser>> build() async {
    final loggedIn = await ref.watch(authControllerProvider.future);
    if (!loggedIn) return [];

    final profile = await ref.read(profileRepositoryProvider).me();
    if (profile == null) {
      throw StateError('PROFILE_INCOMPLETE');
    }

    final filters = ref.watch(discoveryFiltersProvider) ??
        DiscoveryFilters(
          minAge: profile.minAge,
          maxAge: profile.maxAge,
          maxDistanceKm: profile.maxDistanceKm,
          genders: profile.showMe.toList(),
        );

    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always) {
        final position = await Geolocator.getCurrentPosition();
        await ref
            .read(profileRepositoryProvider)
            .location(position.latitude, position.longitude);
      }
    } catch (_) {}

    final page = await ref.read(discoveryRepositoryProvider).fetch(
      filters: filters,
    );
    cursor = page.nextCursor;
    schedulePresenceSeed(ref,
      page.items.map(
        (user) => (
          userId: user.userId,
          online: user.online,
          lastActiveAt: user.lastActiveAt,
        ),
      ),
    );
    return page.items;
  }

  Future<void> applyFilters(DiscoveryFilters filters) async {
    ref.read(discoveryFiltersProvider.notifier).set(filters);
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      cursor = null;
      final page = await ref.read(discoveryRepositoryProvider).fetch(
        filters: filters,
      );
      cursor = page.nextCursor;
      schedulePresenceSeed(ref,
        page.items.map(
          (user) => (
            userId: user.userId,
            online: user.online,
            lastActiveAt: user.lastActiveAt,
          ),
        ),
      );
      return page.items;
    });
  }

  Future<void> loadMore() async {
    if (cursor == null || state.isLoading) return;
    final filters = ref.read(discoveryFiltersProvider);
    final page = await ref.read(discoveryRepositoryProvider).fetch(
      cursor: cursor,
      filters: filters,
    );
    cursor = page.nextCursor;
    schedulePresenceSeed(ref,
      page.items.map(
        (user) => (
          userId: user.userId,
          online: user.online,
          lastActiveAt: user.lastActiveAt,
        ),
      ),
    );
    state = AsyncData([...?state.asData?.value, ...page.items]);
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
  }
}

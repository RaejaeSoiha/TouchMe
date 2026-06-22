import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../domain/nearby_user.dart';

class DiscoveryFilters {
  const DiscoveryFilters({
    required this.minAge,
    required this.maxAge,
    required this.maxDistanceKm,
    required this.genders,
  });

  final int minAge;
  final int maxAge;
  final int maxDistanceKm;
  final List<String> genders;

  Map<String, Object?> toQuery() => {
    'minAge': minAge,
    'maxAge': maxAge,
    'maxDistanceKm': maxDistanceKm,
    'genders': genders,
  };
}

final discoveryRepositoryProvider = Provider<DiscoveryRepository>(
  (ref) => DiscoveryRepository(ref.watch(dioProvider)),
);

class DiscoveryPage {
  const DiscoveryPage(this.items, this.nextCursor);
  final List<NearbyUser> items;
  final String? nextCursor;
}

class DiscoveryRepository {
  DiscoveryRepository(this._dio);
  final Dio _dio;

  Future<DiscoveryPage> fetch({
    String? cursor,
    DiscoveryFilters? filters,
  }) async {
    final response = await _dio.get<Map<String, Object?>>(
      '/discovery',
      queryParameters: {
        if (cursor != null) 'cursor': cursor,
        ...?filters?.toQuery(),
      },
    );
    final data = response.data!;
    return DiscoveryPage(
      (data['items']! as List<Object?>)
          .map((item) => NearbyUser.fromJson(item! as Map<String, Object?>))
          .toList(),
      data['nextCursor'] as String?,
    );
  }
}

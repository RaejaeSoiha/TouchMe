import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';

final subscriptionsRepositoryProvider = Provider<SubscriptionsRepository>(
  (ref) => SubscriptionsRepository(ref.watch(dioProvider)),
);

class SubscriptionPlan {
  const SubscriptionPlan({
    required this.code,
    required this.name,
    required this.priceCents,
    required this.unlimitedLikes,
    required this.passportMode,
    required this.monthlyBoosts,
  });
  final String code;
  final String name;
  final int priceCents;
  final bool unlimitedLikes;
  final bool passportMode;
  final int monthlyBoosts;
  factory SubscriptionPlan.fromJson(Map<String, Object?> json) =>
      SubscriptionPlan(
        code: json['code']! as String,
        name: json['name']! as String,
        priceCents: json['priceCents']! as int,
        unlimitedLikes: json['unlimitedLikes']! as bool,
        passportMode: json['passportMode']! as bool,
        monthlyBoosts: json['monthlyBoosts']! as int,
      );
}

class UserSubscription {
  const UserSubscription({
    required this.status,
    required this.plan,
    required this.currentPeriodEnd,
  });
  final String status;
  final SubscriptionPlan plan;
  final DateTime currentPeriodEnd;
  factory UserSubscription.fromJson(Map<String, Object?> json) =>
      UserSubscription(
        status: json['status']! as String,
        plan: SubscriptionPlan.fromJson(
          json['plan']! as Map<String, Object?>,
        ),
        currentPeriodEnd: DateTime.parse(json['currentPeriodEnd']! as String),
      );
}

class SubscriptionsRepository {
  SubscriptionsRepository(this._dio);
  final Dio _dio;

  Future<List<SubscriptionPlan>> plans() async {
    final response = await _dio.get<List<Object?>>('/subscriptions/plans');
    return response.data!
        .cast<Map<String, Object?>>()
        .map(SubscriptionPlan.fromJson)
        .toList();
  }

  Future<UserSubscription?> mine() async {
    final response = await _dio.get<Map<String, Object?>>('/subscriptions/me');
    return response.data == null
        ? null
        : UserSubscription.fromJson(response.data!);
  }

  Future<String> checkout(String planCode) async {
    final response = await _dio.post<Map<String, Object?>>(
      '/subscriptions/checkout',
      data: {'planCode': planCode},
    );
    return response.data!['url']! as String;
  }

  Future<void> activateBoost() => _dio.post<void>('/subscriptions/boost');
}

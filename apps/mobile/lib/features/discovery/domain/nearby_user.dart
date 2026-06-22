import '../../profile/domain/user_profile.dart';

class NearbyUser {
  const NearbyUser({
    required this.userId,
    required this.distanceKm,
    required this.sharedInterests,
    required this.friendStatus,
    required this.age,
    required this.profile,
    required this.online,
    this.lastActiveAt,
  });

  final String userId;
  final double distanceKm;
  final int sharedInterests;
  final String friendStatus;
  final int age;
  final UserProfile profile;
  final bool online;
  final DateTime? lastActiveAt;

  factory NearbyUser.fromJson(Map<String, Object?> json) => NearbyUser(
    userId: json['id']! as String,
    distanceKm: (json['distanceKm']! as num).toDouble(),
    sharedInterests: json['sharedInterests']! as int,
    friendStatus: json['friendStatus']! as String,
    age: (json['age']! as num).toInt(),
    profile: UserProfile.fromJson(json['profile']! as Map<String, Object?>),
    online: json['online'] as bool? ?? false,
    lastActiveAt: json['lastActiveAt'] == null
        ? null
        : DateTime.parse(json['lastActiveAt']! as String),
  );
}

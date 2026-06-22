class ProfilePhoto {
  const ProfilePhoto({
    required this.id,
    required this.url,
    required this.position,
  });
  final String id;
  final String url;
  final int position;
  factory ProfilePhoto.fromJson(Map<String, Object?> json) => ProfilePhoto(
    id: json['id']! as String,
    url: json['url']! as String,
    position: json['position']! as int,
  );
}

class UserProfile {
  const UserProfile({
    required this.displayName,
    required this.birthDate,
    required this.gender,
    required this.showMe,
    required this.bio,
    required this.city,
    required this.minAge,
    required this.maxAge,
    required this.maxDistanceKm,
    required this.discoverable,
    required this.photos,
    required this.interestIds,
  });
  final String displayName;
  final DateTime birthDate;
  final String gender;
  final List<String> showMe;
  final String? bio;
  final String? city;
  final int minAge;
  final int maxAge;
  final int maxDistanceKm;
  final bool discoverable;
  final List<ProfilePhoto> photos;
  final List<String> interestIds;
  factory UserProfile.fromJson(Map<String, Object?> json) => UserProfile(
    displayName: json['displayName']! as String,
    birthDate: DateTime.parse(json['birthDate']! as String),
    gender: json['gender']! as String,
    showMe: (json['showMe']! as List<Object?>).cast<String>(),
    bio: json['bio'] as String?,
    city: json['city'] as String?,
    minAge: json['minAge']! as int,
    maxAge: json['maxAge']! as int,
    maxDistanceKm: json['maxDistanceKm']! as int,
    discoverable: json['discoverable'] as bool? ?? true,
    photos: ((json['photos'] as List<Object?>?) ?? [])
        .map((item) => ProfilePhoto.fromJson(item! as Map<String, Object?>))
        .toList(),
    interestIds: ((json['interests'] as List<Object?>?) ?? [])
        .map(
          (item) =>
              ((item! as Map<String, Object?>)['interest']!
                      as Map<String, Object?>)['id']!
                  as String,
        )
        .toList(),
  );
  Map<String, Object?> toJson() => {
    'displayName': displayName,
    'birthDate': birthDate.toIso8601String(),
    'gender': gender,
    'showMe': showMe,
    'bio': bio,
    'city': city,
    'minAge': minAge,
    'maxAge': maxAge,
    'maxDistanceKm': maxDistanceKm,
    'discoverable': discoverable,
    'interestIds': interestIds,
  };

  UserProfile copyWith({
    String? displayName,
    DateTime? birthDate,
    String? gender,
    List<String>? showMe,
    String? bio,
    String? city,
    int? minAge,
    int? maxAge,
    int? maxDistanceKm,
    bool? discoverable,
    List<ProfilePhoto>? photos,
    List<String>? interestIds,
  }) => UserProfile(
    displayName: displayName ?? this.displayName,
    birthDate: birthDate ?? this.birthDate,
    gender: gender ?? this.gender,
    showMe: showMe ?? this.showMe,
    bio: bio ?? this.bio,
    city: city ?? this.city,
    minAge: minAge ?? this.minAge,
    maxAge: maxAge ?? this.maxAge,
    maxDistanceKm: maxDistanceKm ?? this.maxDistanceKm,
    discoverable: discoverable ?? this.discoverable,
    photos: photos ?? this.photos,
    interestIds: interestIds ?? this.interestIds,
  );
}

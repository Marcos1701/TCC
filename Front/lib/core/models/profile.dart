class ProfileModel {
  const ProfileModel({
    required this.level,
    required this.experiencePoints,
    required this.nextLevelThreshold,
    required this.targetTps,
    required this.targetRdr,
  });

  final int level;
  final int experiencePoints;
  final int nextLevelThreshold;
  final int targetTps;
  final int targetRdr;

  factory ProfileModel.fromMap(Map<String, dynamic> map) {
    return ProfileModel(
      level: map['level'] as int,
      experiencePoints: map['experience_points'] as int,
      nextLevelThreshold: map['next_level_threshold'] as int,
      targetTps: map['target_tps'] as int,
      targetRdr: map['target_rdr'] as int,
    );
  }
}

class UserHeader {
  const UserHeader({required this.id, required this.name, required this.email});

  final int id;
  final String name;
  final String email;

  factory UserHeader.fromMap(Map<String, dynamic> map) {
    return UserHeader(
      id: map['id'] as int,
      name: (map['name'] as String?)?.isNotEmpty == true
          ? map['name'] as String
          : map['email'] as String,
      email: map['email'] as String,
    );
  }
}

class ProfileModel {
  const ProfileModel({
    required this.level,
    required this.experiencePoints,
    required this.nextLevelThreshold,
    required this.targetTps,
    required this.targetRdr,
    required this.targetIli,
    required this.isFirstAccess,
  });

  final int level;
  final int experiencePoints;
  final int nextLevelThreshold;
  final int targetTps;
  final int targetRdr;
  final double targetIli;
  final bool isFirstAccess;

  factory ProfileModel.fromMap(Map<String, dynamic> map) {
    if (map.isEmpty) {
      return const ProfileModel(
        level: 1,
        experiencePoints: 0,
        nextLevelThreshold: 150,
        targetTps: 0,
        targetRdr: 0,
        targetIli: 0.0,
        isFirstAccess: true,
      );
    }

    return ProfileModel(
      level: int.parse(map['level']?.toString() ?? '1'),
      experiencePoints: int.parse(map['experience_points']?.toString() ?? '0'),
      nextLevelThreshold: int.parse(map['next_level_threshold']?.toString() ?? '150'),  // Corrigido fallback
      targetTps: int.parse(map['target_tps']?.toString() ?? '0'),
      targetRdr: int.parse(map['target_rdr']?.toString() ?? '0'),
      targetIli: double.parse(map['target_ili']?.toString() ?? '0'),
      isFirstAccess: map['is_first_access'] as bool? ?? true,
    );
  }
}

class UserHeader {
  const UserHeader({
    required this.id,
    required this.name,
    required this.email,
    this.isStaff = false,
    this.isSuperuser = false,
  });

  final int id;
  final String name;
  final String email;
  
  final bool isStaff;
  
  final bool isSuperuser;

  bool get isAdmin => isStaff || isSuperuser;

  factory UserHeader.fromMap(Map<String, dynamic> map) {
    return UserHeader(
      id: int.parse(map['id'].toString()),
      name: (map['name'] as String?)?.isNotEmpty == true
          ? map['name'] as String
          : map['email'] as String,
      email: map['email'] as String,
      isStaff: map['is_staff'] as bool? ?? false,
      isSuperuser: map['is_superuser'] as bool? ?? false,
    );
  }
}

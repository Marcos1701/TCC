/// Modelo para resultado de busca de usuários.
class UserSearchModel {
  const UserSearchModel({
    required this.id,
    required this.username,
    required this.name,
    required this.email,
    required this.level,
    required this.xp,
    required this.isFriend,
    required this.hasPendingRequest,
  });

  final int id;
  final String username;
  final String name;
  final String email;
  final int level;
  final int xp;
  final bool isFriend;
  final bool hasPendingRequest;

  factory UserSearchModel.fromMap(Map<String, dynamic> map) {
    return UserSearchModel(
      id: int.parse(map['id'].toString()),
      username: map['username'] as String,
      name: map['name'] as String,
      email: map['email'] as String,
      level: int.parse(map['level'].toString()),
      xp: int.parse(map['xp'].toString()),
      isFriend: map['is_friend'] as bool,
      hasPendingRequest: map['has_pending_request'] as bool,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'username': username,
      'name': name,
      'email': email,
      'level': level,
      'xp': xp,
      'is_friend': isFriend,
      'has_pending_request': hasPendingRequest,
    };
  }

  UserSearchModel copyWith({
    int? id,
    String? username,
    String? name,
    String? email,
    int? level,
    int? xp,
    bool? isFriend,
    bool? hasPendingRequest,
  }) {
    return UserSearchModel(
      id: id ?? this.id,
      username: username ?? this.username,
      name: name ?? this.name,
      email: email ?? this.email,
      level: level ?? this.level,
      xp: xp ?? this.xp,
      isFriend: isFriend ?? this.isFriend,
      hasPendingRequest: hasPendingRequest ?? this.hasPendingRequest,
    );
  }
}

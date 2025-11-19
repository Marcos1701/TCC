/// Modelo para relacionamento de amizade entre usuários.
class FriendshipModel {
  const FriendshipModel({
    required this.id,
    required this.userId,
    required this.friendId,
    required this.userInfo,
    required this.friendInfo,
    required this.status,
    required this.createdAt,
    this.acceptedAt,
  });

  final String id;
  final int userId;
  final int friendId;
  final UserInfoModel userInfo;
  final UserInfoModel friendInfo;
  final FriendshipStatus status;
  final DateTime createdAt;
  final DateTime? acceptedAt;

  factory FriendshipModel.fromMap(Map<String, dynamic> map) {
    return FriendshipModel(
      id: map['id'].toString(),
      userId: map['user'] as int,
      friendId: map['friend'] as int,
      userInfo: UserInfoModel.fromMap(map['user_info'] as Map<String, dynamic>),
      friendInfo:
          UserInfoModel.fromMap(map['friend_info'] as Map<String, dynamic>),
      status: FriendshipStatus.fromString(map['status'] as String),
      createdAt: DateTime.parse(map['created_at'] as String),
      acceptedAt: map['accepted_at'] != null
          ? DateTime.parse(map['accepted_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user': userId,
      'friend': friendId,
      'status': status.value,
      'created_at': createdAt.toIso8601String(),
      'accepted_at': acceptedAt?.toIso8601String(),
    };
  }

  FriendshipModel copyWith({
    String? id,
    int? userId,
    int? friendId,
    UserInfoModel? userInfo,
    UserInfoModel? friendInfo,
    FriendshipStatus? status,
    DateTime? createdAt,
    DateTime? acceptedAt,
  }) {
    return FriendshipModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      friendId: friendId ?? this.friendId,
      userInfo: userInfo ?? this.userInfo,
      friendInfo: friendInfo ?? this.friendInfo,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      acceptedAt: acceptedAt ?? this.acceptedAt,
    );
  }

  /// Retorna o identificador preferencial
  String get identifier => id;
  
  /// Verifica se possui UUID
  bool get hasUuid => true;
}

/// Informações básicas de um usuário na amizade.
class UserInfoModel {
  const UserInfoModel({
    required this.id,
    required this.username,
    required this.name,
    required this.email,
    required this.level,
    required this.xp,
  });

  final int id;
  final String username;
  final String name;
  final String email;
  final int level;
  final int xp;

  factory UserInfoModel.fromMap(Map<String, dynamic> map) {
    return UserInfoModel(
      id: int.parse(map['id'].toString()),
      username: map['username'] as String,
      name: map['name'] as String,
      email: map['email'] as String,
      level: int.parse(map['level'].toString()),
      xp: int.parse(map['xp'].toString()),
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
    };
  }
}

/// Status da solicitação de amizade.
enum FriendshipStatus {
  pending('PENDING', 'Pendente'),
  accepted('ACCEPTED', 'Aceito'),
  rejected('REJECTED', 'Rejeitado');

  const FriendshipStatus(this.value, this.label);

  final String value;
  final String label;

  static FriendshipStatus fromString(String value) {
    return FriendshipStatus.values.firstWhere(
      (status) => status.value == value,
      orElse: () => FriendshipStatus.pending,
    );
  }
}

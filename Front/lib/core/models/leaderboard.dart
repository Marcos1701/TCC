/// Modelo para entrada no ranking de usuários.
class LeaderboardEntryModel {
  const LeaderboardEntryModel({
    required this.rank,
    required this.userId,
    required this.username,
    required this.name,
    required this.level,
    required this.xp,
    required this.isCurrentUser,
  });

  final int rank;
  final int userId;
  final String username;
  final String name;
  final int level;
  final int xp;
  final bool isCurrentUser;

  factory LeaderboardEntryModel.fromMap(Map<String, dynamic> map) {
    return LeaderboardEntryModel(
      rank: map['rank'] as int,
      userId: map['user_id'] as int,
      username: map['username'] as String,
      name: map['name'] as String,
      level: map['level'] as int,
      xp: map['xp'] as int,
      isCurrentUser: map['is_current_user'] as bool,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'rank': rank,
      'user_id': userId,
      'username': username,
      'name': name,
      'level': level,
      'xp': xp,
      'is_current_user': isCurrentUser,
    };
  }
}

/// Resposta do endpoint de leaderboard.
class LeaderboardResponse {
  const LeaderboardResponse({
    required this.count,
    required this.leaderboard,
    this.page,
    this.pageSize,
    this.currentUserRank,
  });

  final int count;
  final List<LeaderboardEntryModel> leaderboard;
  final int? page;
  final int? pageSize;
  final int? currentUserRank;

  factory LeaderboardResponse.fromMap(Map<String, dynamic> map) {
    return LeaderboardResponse(
      count: map['count'] as int,
      leaderboard: (map['leaderboard'] as List<dynamic>)
          .map((e) => LeaderboardEntryModel.fromMap(e as Map<String, dynamic>))
          .toList(),
      page: map['page'] as int?,
      pageSize: map['page_size'] as int?,
      currentUserRank: map['current_user_rank'] as int?,
    );
  }
}

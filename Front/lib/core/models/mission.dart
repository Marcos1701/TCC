class MissionModel {
  const MissionModel({
    required this.id,
    required this.title,
    required this.description,
    required this.rewardPoints,
    required this.difficulty,
    this.targetTps,
    this.targetRdr,
    required this.durationDays,
  });

  final int id;
  final String title;
  final String description;
  final int rewardPoints;
  final String difficulty;
  final int? targetTps;
  final int? targetRdr;
  final int durationDays;

  factory MissionModel.fromMap(Map<String, dynamic> map) {
    return MissionModel(
      id: map['id'] as int,
      title: map['title'] as String,
      description: map['description'] as String,
      rewardPoints: map['reward_points'] as int,
      difficulty: map['difficulty'] as String,
      targetTps: map['target_tps'] as int?,
      targetRdr: map['target_rdr'] as int?,
      durationDays: map['duration_days'] as int,
    );
  }
}

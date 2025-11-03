class MissionModel {
  const MissionModel({
    required this.id,
    required this.title,
    required this.description,
    required this.rewardPoints,
    required this.difficulty,
    required this.missionType,
    required this.priority,
    this.targetTps,
    this.targetRdr,
    this.minIli,
    this.maxIli,
    this.minTransactions,
    required this.durationDays,
  });

  final int id;
  final String title;
  final String description;
  final int rewardPoints;
  final String difficulty;
  final String missionType;
  final int priority;
  final int? targetTps;
  final int? targetRdr;
  final double? minIli;
  final double? maxIli;
  final int? minTransactions;
  final int durationDays;

  factory MissionModel.fromMap(Map<String, dynamic> map) {
    return MissionModel(
      id: map['id'] as int,
      title: map['title'] as String,
      description: map['description'] as String,
      rewardPoints: map['reward_points'] as int,
      difficulty: map['difficulty'] as String,
      missionType: map['mission_type'] as String? ?? 'ONBOARDING',
      priority: map['priority'] as int? ?? 1,
      targetTps: map['target_tps'] as int?,
      targetRdr: map['target_rdr'] as int?,
      minIli: map['min_ili'] != null
          ? double.parse(map['min_ili'].toString())
          : null,
      maxIli: map['max_ili'] != null
          ? double.parse(map['max_ili'].toString())
          : null,
      minTransactions: map['min_transactions'] as int?,
      durationDays: map['duration_days'] as int,
    );
  }

  /// Retorna uma descrição amigável do tipo de missão
  String get missionTypeLabel {
    switch (missionType) {
      case 'ONBOARDING':
        return 'Iniciante';
      case 'TPS_IMPROVEMENT':
        return 'Poupança';
      case 'RDR_REDUCTION':
        return 'Dívidas';
      case 'ILI_BUILDING':
        return 'Reserva';
      case 'ADVANCED':
        return 'Avançado';
      default:
        return 'Geral';
    }
  }
}

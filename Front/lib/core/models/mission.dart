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
    // Novos campos de validação avançada
    required this.validationType,
    this.requiresConsecutiveDays,
    this.minConsecutiveDays,
    this.targetCategory,
    this.targetReductionPercent,
    this.categorySpendingLimit,
    this.targetGoal,
    this.goalProgressTarget,
    this.savingsIncreaseAmount,
    this.requiresDailyAction,
    this.minDailyActions,
    this.impacts,
    this.tips,
    // Campos de display da API
    this.typeDisplay,
    this.difficultyDisplay,
    this.validationTypeDisplay,
    this.source,
    this.targetInfo,
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
  
  // Novos campos
  final String validationType;
  final bool? requiresConsecutiveDays;
  final int? minConsecutiveDays;
  final int? targetCategory;
  final double? targetReductionPercent;
  final double? categorySpendingLimit;
  final int? targetGoal;
  final double? goalProgressTarget;
  final double? savingsIncreaseAmount;
  final bool? requiresDailyAction;
  final int? minDailyActions;
  
  // Gamificação contextual
  final List<Map<String, dynamic>>? impacts;
  final List<Map<String, dynamic>>? tips;
  
  // Campos de display da API
  final String? typeDisplay;
  final String? difficultyDisplay;
  final String? validationTypeDisplay;
  final String? source; // 'template', 'ai', 'system'
  final Map<String, dynamic>? targetInfo;

  factory MissionModel.fromMap(Map<String, dynamic> map) {
    return MissionModel(
      id: int.parse(map['id'].toString()),
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
      // Novos campos
      validationType: map['validation_type'] as String? ?? 'SNAPSHOT',
      requiresConsecutiveDays: map['requires_consecutive_days'] as bool?,
      minConsecutiveDays: map['min_consecutive_days'] as int?,
      targetCategory: map['target_category'] as int?,
      targetReductionPercent: map['target_reduction_percent'] != null
          ? double.parse(map['target_reduction_percent'].toString())
          : null,
      categorySpendingLimit: map['category_spending_limit'] != null
          ? double.parse(map['category_spending_limit'].toString())
          : null,
      targetGoal: map['target_goal'] as int?,
      goalProgressTarget: map['goal_progress_target'] != null
          ? double.parse(map['goal_progress_target'].toString())
          : null,
      savingsIncreaseAmount: map['savings_increase_amount'] != null
          ? double.parse(map['savings_increase_amount'].toString())
          : null,
      requiresDailyAction: map['requires_daily_action'] as bool?,
      minDailyActions: map['min_daily_actions'] as int?,
      impacts: (map['impacts'] as List<dynamic>?)
          ?.map((e) => Map<String, dynamic>.from(e as Map))
          .toList(),
      tips: (map['tips'] as List<dynamic>?)
          ?.map((e) => Map<String, dynamic>.from(e as Map))
          .toList(),
      // Campos de display da API
      typeDisplay: map['type_display'] as String?,
      difficultyDisplay: map['difficulty_display'] as String?,
      validationTypeDisplay: map['validation_type_display'] as String?,
      source: map['source'] as String?,
      targetInfo: map['target_info'] != null 
          ? Map<String, dynamic>.from(map['target_info'] as Map)
          : null,
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
  
  /// Retorna uma descrição amigável do tipo de validação
  String get validationTypeLabel {
    switch (validationType) {
      case 'SNAPSHOT':
        return 'Comparação pontual';
      case 'TEMPORAL':
        return 'Manter por período';
      case 'CATEGORY_REDUCTION':
        return 'Reduzir categoria';
      case 'CATEGORY_LIMIT':
        return 'Limite de categoria';
      case 'GOAL_PROGRESS':
        return 'Progresso em meta';
      case 'SAVINGS_INCREASE':
        return 'Aumentar poupança';
      case 'CONSISTENCY':
        return 'Consistência';
      default:
        return validationType;
    }
  }
}


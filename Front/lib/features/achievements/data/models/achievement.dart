/// Model para critérios de conquista
/// 
/// Tipos suportados:
/// - count: Contagem de elementos (transações, missões, amigos)
/// - value: Valores numéricos (TPS, ILI, RDR, savings)
/// - streak: Dias consecutivos de atividade
class AchievementCriteria {
  final String type;
  final int target;
  final String metric;
  final int? duration;

  const AchievementCriteria({
    required this.type,
    required this.target,
    required this.metric,
    this.duration,
  });

  factory AchievementCriteria.fromJson(Map<String, dynamic> json) {
    return AchievementCriteria(
      type: json['type'] as String,
      target: json['target'] as int,
      metric: json['metric'] as String,
      duration: json['duration'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'target': target,
      'metric': metric,
      if (duration != null) 'duration': duration,
    };
  }

  String get description {
    switch (type) {
      case 'count':
        return _getCountDescription();
      case 'value':
        return _getValueDescription();
      case 'streak':
        return _getStreakDescription();
      default:
        return 'Meta: $target';
    }
  }

  String _getCountDescription() {
    final metricName = _getMetricName(metric);
    return '$target $metricName';
  }

  String _getValueDescription() {
    final metricName = _getMetricName(metric);
    if (duration != null) {
      return '$metricName ≥ $target por $duration dias';
    }
    return '$metricName ≥ $target';
  }

  String _getStreakDescription() {
    final activityName = _getMetricName(metric);
    return '$target dias consecutivos de $activityName';
  }

  String _getMetricName(String metric) {
    const metricNames = {
      'transactions': 'transações',
      'income_transactions': 'receitas',
      'expense_transactions': 'despesas',
      'missions': 'missões',
      'goals': 'metas',
      'friends': 'amigos',
      'categories': 'categorias',
      'tps': 'TPS',
      'ili': 'ILI',
      'rdr': 'RDR',
      'total_income': 'receita total',
      'total_expense': 'despesa total',
      'savings': 'poupança',
      'xp': 'XP',
      'level': 'nível',
      'login': 'login',
      'transaction': 'transação',
      'mission': 'missão',
    };
    return metricNames[metric] ?? metric;
  }
}

/// Model para conquista
class Achievement {
  final int id;
  final String title;
  final String description;
  final String category;
  final String tier;
  final int xpReward;
  final String icon;
  final AchievementCriteria criteria;
  final bool isActive;
  final bool isAiGenerated;
  final int priority;
  final DateTime createdAt;

  const Achievement({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.tier,
    required this.xpReward,
    required this.icon,
    required this.criteria,
    required this.isActive,
    required this.isAiGenerated,
    required this.priority,
    required this.createdAt,
  });

  factory Achievement.fromJson(Map<String, dynamic> json) {
    return Achievement(
      id: json['id'] as int,
      title: json['title'] as String,
      description: json['description'] as String,
      category: json['category'] as String,
      tier: json['tier'] as String,
      xpReward: json['xp_reward'] as int,
      icon: json['icon'] as String,
      criteria: AchievementCriteria.fromJson(json['criteria'] as Map<String, dynamic>),
      isActive: json['is_active'] as bool,
      isAiGenerated: json['is_ai_generated'] as bool,
      priority: json['priority'] as int,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'category': category,
      'tier': tier,
      'xp_reward': xpReward,
      'icon': icon,
      'criteria': criteria.toJson(),
      'is_active': isActive,
      'is_ai_generated': isAiGenerated,
      'priority': priority,
      'created_at': createdAt.toIso8601String(),
    };
  }

  String get categoryName {
    const categoryNames = {
      'FINANCIAL': 'Financeiro',
      'SOCIAL': 'Social',
      'MISSION': 'Missões',
      'STREAK': 'Sequência',
      'GENERAL': 'Geral',
    };
    return categoryNames[category] ?? category;
  }

  String get tierName {
    const tierNames = {
      'BEGINNER': 'Iniciante',
      'INTERMEDIATE': 'Intermediário',
      'ADVANCED': 'Avançado',
    };
    return tierNames[tier] ?? tier;
  }
}

/// Model para progresso do usuário em conquista
class UserAchievement {
  final int id;
  final Achievement achievement;
  final bool isUnlocked;
  final int progress;
  final int progressMax;
  final int progressPercentage;
  final DateTime? unlockedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  const UserAchievement({
    required this.id,
    required this.achievement,
    required this.isUnlocked,
    required this.progress,
    required this.progressMax,
    required this.progressPercentage,
    this.unlockedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory UserAchievement.fromJson(Map<String, dynamic> json) {
    return UserAchievement(
      id: json['id'] as int,
      achievement: Achievement.fromJson(json['achievement'] as Map<String, dynamic>),
      isUnlocked: json['is_unlocked'] as bool,
      progress: json['progress'] as int,
      progressMax: json['progress_max'] as int,
      progressPercentage: json['progress_percentage'] as int,
      unlockedAt: json['unlocked_at'] != null 
          ? DateTime.parse(json['unlocked_at'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'achievement': achievement.toJson(),
      'is_unlocked': isUnlocked,
      'progress': progress,
      'progress_max': progressMax,
      'progress_percentage': progressPercentage,
      'unlocked_at': unlockedAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  /// Retorna descrição do progresso atual
  String get progressDescription {
    if (isUnlocked) {
      return 'Desbloqueada!';
    }
    return '$progress / $progressMax ($progressPercentage%)';
  }

  /// Retorna true se está próximo de desbloquear (≥80%)
  bool get isCloseToUnlock => progressPercentage >= 80 && !isUnlocked;
}

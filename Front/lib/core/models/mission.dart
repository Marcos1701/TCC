import 'category.dart';

class MissionModel {
  const MissionModel({
    required this.id,
    required this.title,
    required this.description,
    required this.rewardPoints,
    required this.difficulty,
    required this.missionType,
    required this.priority,
    required this.isActive,
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
    this.targetCategoryData,
    this.targetCategories = const [],
    this.targetReductionPercent,
    this.categorySpendingLimit,
    this.targetGoal,
    this.goalProgressTarget,
    this.savingsIncreaseAmount,
    this.requiresDailyAction,
    this.minDailyActions,
    this.impacts,
    this.tips,
    this.minTransactionFrequency,
    this.transactionTypeFilter,
    this.requiresPaymentTracking = false,
    this.minPaymentsCount,
    this.isSystemGenerated = false,
    this.generationContext,
    // Campos de display da API
    this.typeDisplay,
    this.difficultyDisplay,
    this.validationTypeDisplay,
    this.source,
    this.targetInfo,
    required this.createdAt,
    required this.updatedAt,
  });

  final int id;
  final String title;
  final String description;
  final int rewardPoints;
  final String difficulty;
  final String missionType;
  final int priority;
  final bool isActive;
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
  final CategoryModel? targetCategoryData;
  final List<CategoryModel> targetCategories;
  final double? targetReductionPercent;
  final double? categorySpendingLimit;
  final int? targetGoal;
  final double? goalProgressTarget;
  final double? savingsIncreaseAmount;
  final bool? requiresDailyAction;
  final int? minDailyActions;
  final int? minTransactionFrequency;
  final String? transactionTypeFilter;
  final bool requiresPaymentTracking;
  final int? minPaymentsCount;
  final bool isSystemGenerated;
  final Map<String, dynamic>? generationContext;
  
  // Gamificação contextual
  final List<Map<String, dynamic>>? impacts;
  final List<Map<String, dynamic>>? tips;
  
  // Campos de display da API
  final String? typeDisplay;
  final String? difficultyDisplay;
  final String? validationTypeDisplay;
  final String? source; // 'template', 'ai', 'system'
  final Map<String, dynamic>? targetInfo;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory MissionModel.fromMap(Map<String, dynamic> map) {
    final dynamic targetCategoryRaw = map['target_category'];
    final CategoryModel? targetCategoryData = _parseCategory(targetCategoryRaw);
    final int? targetCategoryId = _parseId(targetCategoryRaw);

    final List<CategoryModel> multipleTargets = _parseCategoryList(
      map['target_categories'],
    );

    return MissionModel(
      id: int.parse(map['id'].toString()),
      title: map['title'] as String,
      description: map['description'] as String,
      rewardPoints: map['reward_points'] as int,
      difficulty: map['difficulty'] as String,
      missionType: map['mission_type'] as String? ?? 'ONBOARDING',
      priority: map['priority'] as int? ?? 1,
      isActive: (map['is_active'] as bool?) ?? true,
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
      targetCategory: targetCategoryId,
      targetCategoryData: targetCategoryData,
      targetCategories: multipleTargets,
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
      minTransactionFrequency: _parseInt(map['min_transaction_frequency']),
      transactionTypeFilter: map['transaction_type_filter'] as String?,
      requiresPaymentTracking:
          (map['requires_payment_tracking'] as bool?) ?? false,
      minPaymentsCount: _parseInt(map['min_payments_count']),
      isSystemGenerated: (map['is_system_generated'] as bool?) ?? false,
      generationContext: map['generation_context'] != null
          ? Map<String, dynamic>.from(map['generation_context'] as Map)
          : null,
      // Campos de display da API
      typeDisplay: map['type_display'] as String?,
      difficultyDisplay: map['difficulty_display'] as String?,
      validationTypeDisplay: map['validation_type_display'] as String?,
      source: map['source'] as String?,
      targetInfo: map['target_info'] != null 
          ? Map<String, dynamic>.from(map['target_info'] as Map)
          : null,
      createdAt: _parseDate(map['created_at']),
      updatedAt: _parseDate(map['updated_at']),
    );
  }

  /// Retorna uma descrição amigável do tipo de missão
  String get missionTypeLabel {
    switch (missionType) {
      case 'ONBOARDING_TRANSACTIONS':
        return 'Primeiros passos: transações';
      case 'ONBOARDING_CATEGORIES':
        return 'Primeiros passos: categorias';
      case 'ONBOARDING_GOALS':
        return 'Primeiros passos: metas';
      case 'ONBOARDING':
        return 'Iniciante';
      case 'TPS_IMPROVEMENT':
        return 'Poupança';
      case 'RDR_REDUCTION':
        return 'Dívidas';
      case 'ILI_BUILDING':
        return 'Reserva';
      case 'CATEGORY_REDUCTION':
        return 'Reduzir gastos em categoria';
      case 'CATEGORY_SPENDING_LIMIT':
        return 'Manter limite da categoria';
      case 'CATEGORY_ELIMINATION':
        return 'Eliminar gastos supérfluos';
      case 'GOAL_ACHIEVEMENT':
        return 'Completar meta';
      case 'GOAL_CONSISTENCY':
        return 'Contribuir com metas';
      case 'GOAL_ACCELERATION':
        return 'Acelerar meta';
      case 'SAVINGS_STREAK':
        return 'Sequência de poupança';
      case 'EXPENSE_CONTROL':
        return 'Controle de gastos';
      case 'INCOME_TRACKING':
        return 'Registrar receitas';
      case 'PAYMENT_DISCIPLINE':
        return 'Disciplina de pagamentos';
      case 'FINANCIAL_HEALTH':
        return 'Saúde financeira';
      case 'WEALTH_BUILDING':
        return 'Construção de patrimônio';
      case 'ADVANCED':
        return 'Avançado';
      default:
        return 'Missão financeira';
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
      case 'GOAL_CONTRIBUTION':
        return 'Contribuir para meta';
      case 'SAVINGS_INCREASE':
        return 'Aumentar poupança';
      case 'CONSISTENCY':
        return 'Consistência';
      case 'TRANSACTION_COUNT':
        return 'Registrar transações';
      case 'TRANSACTION_CONSISTENCY':
        return 'Consistência de transações';
      case 'PAYMENT_COUNT':
        return 'Registrar pagamentos';
      case 'INDICATOR_THRESHOLD':
        return 'Atingir indicador';
      case 'INDICATOR_IMPROVEMENT':
        return 'Melhorar indicador';
      case 'INDICATOR_MAINTENANCE':
        return 'Manter indicador';
      case 'MULTI_CRITERIA':
        return 'Critérios combinados';
      default:
        return validationType;
    }
  }

  static CategoryModel? _parseCategory(dynamic data) {
    if (data is Map<String, dynamic>) {
      return CategoryModel.fromMap(data);
    }
    if (data is Map) {
      return CategoryModel.fromMap(Map<String, dynamic>.from(data));
    }
    return null;
  }

  static List<CategoryModel> _parseCategoryList(dynamic rawList) {
    if (rawList is List) {
      return rawList
          .whereType<Map>()
          .map((item) => CategoryModel.fromMap(
                Map<String, dynamic>.from(item),
              ))
          .toList();
    }
    return const [];
  }

  static int? _parseId(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    if (value is Map) {
      final dynamic rawId = value['id'];
      if (rawId == null) return null;
      if (rawId is int) return rawId;
      return int.tryParse(rawId.toString());
    }
    return null;
  }

  static int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.toInt();
    return int.tryParse(value.toString());
  }

  static DateTime _parseDate(dynamic value) {
    if (value is DateTime) return value;
    if (value == null) {
      return DateTime.now();
    }
    return DateTime.parse(value.toString());
  }

  /// Valida se a missão contém placeholders não substituídos
  bool hasPlaceholders() {
    final placeholderPattern = RegExp(r'\{[^}]+\}');
    return placeholderPattern.hasMatch(title) || 
           placeholderPattern.hasMatch(description);
  }

  /// Lista de placeholders encontrados (para debug)
  List<String> getPlaceholders() {
    final placeholderPattern = RegExp(r'\{([^}]+)\}');
    final placeholders = <String>{};
    
    placeholderPattern.allMatches(title).forEach((match) {
      if (match.group(1) != null) placeholders.add(match.group(1)!);
    });
    
    placeholderPattern.allMatches(description).forEach((match) {
      if (match.group(1) != null) placeholders.add(match.group(1)!);
    });
    
    return placeholders.toList();
  }

  /// Indica se a missão é válida para exibição
  bool get isValid => !hasPlaceholders() && title.isNotEmpty && description.isNotEmpty;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'reward_points': rewardPoints,
      'difficulty': difficulty,
      'mission_type': missionType,
      'priority': priority,
      'is_active': isActive,
      'target_tps': targetTps,
      'target_rdr': targetRdr,
      'min_ili': minIli,
      'max_ili': maxIli,
      'min_transactions': minTransactions,
      'duration_days': durationDays,
      'validation_type': validationType,
      'requires_consecutive_days': requiresConsecutiveDays,
      'min_consecutive_days': minConsecutiveDays,
      'target_category': targetCategory,
      'target_categories': targetCategories.map((c) => c.toMap()).toList(),
      'target_reduction_percent': targetReductionPercent,
      'category_spending_limit': categorySpendingLimit,
      'target_goal': targetGoal,
      'goal_progress_target': goalProgressTarget,
      'savings_increase_amount': savingsIncreaseAmount,
      'requires_daily_action': requiresDailyAction,
      'min_daily_actions': minDailyActions,
      'impacts': impacts,
      'tips': tips,
      'min_transaction_frequency': minTransactionFrequency,
      'transaction_type_filter': transactionTypeFilter,
      'requires_payment_tracking': requiresPaymentTracking,
      'min_payments_count': minPaymentsCount,
      'is_system_generated': isSystemGenerated,
      'generation_context': generationContext,
      'type_display': typeDisplay,
      'difficulty_display': difficultyDisplay,
      'validation_type_display': validationTypeDisplay,
      'source': source,
      'target_info': targetInfo,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}

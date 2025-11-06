/// Tipos de metas financeiras
enum GoalType {
  savings('SAVINGS', 'Juntar Dinheiro', '💰'),
  categoryExpense('CATEGORY_EXPENSE', 'Reduzir Gastos', '📉'),
  categoryIncome('CATEGORY_INCOME', 'Aumentar Receita', '📈'),
  debtReduction('DEBT_REDUCTION', 'Reduzir Despesas', '💳'),
  custom('CUSTOM', 'Personalizada', '✏️');

  const GoalType(this.value, this.label, this.icon);
  final String value;
  final String label;
  final String icon;
}

/// Período de rastreamento da meta
enum TrackingPeriod {
  monthly('MONTHLY', 'Mensal'),
  quarterly('QUARTERLY', 'Trimestral'),
  total('TOTAL', 'Total');

  const TrackingPeriod(this.value, this.label);
  final String value;
  final String label;
}

/// Categoria monitorada em uma meta
class TrackedCategory {
  const TrackedCategory({
    required this.id,
    required this.name,
    required this.color,
    required this.type,
    this.group,
  });

  final int id;
  final String name;
  final String color;
  final String type;
  final String? group;

  factory TrackedCategory.fromMap(Map<String, dynamic> map) {
    return TrackedCategory(
      id: map['id'] as int,
      name: map['name'] as String,
      color: (map['color'] as String?) ?? '#808080',
      type: map['type'] as String,
      group: map['group'] as String?,
    );
  }
}

/// Modelo de Meta Financeira
class GoalModel {
  const GoalModel({
    required this.id,
    this.uuid,
    required this.title,
    required this.description,
    required this.targetAmount,
    required this.currentAmount,
    this.initialAmount = 0.0,
    this.deadline,
    required this.goalType,
    this.targetCategory,
    this.categoryName,
    this.trackedCategories = const [],
    required this.autoUpdate,
    required this.trackingPeriod,
    required this.isReductionGoal,
    required this.progressPercentage,
    required this.createdAt,
    required this.updatedAt,
  });

  final int id;
  final String? uuid;  // UUID para identificação segura
  final String title;
  final String description;
  final double targetAmount;
  final double currentAmount;
  final double initialAmount;
  final DateTime? deadline;
  final GoalType goalType;
  final int? targetCategory;
  final String? categoryName;
  final List<TrackedCategory> trackedCategories;
  final bool autoUpdate;
  final TrackingPeriod trackingPeriod;
  final bool isReductionGoal;
  final double progressPercentage;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory GoalModel.fromMap(Map<String, dynamic> map) {
    // Parse tracked categories
    List<TrackedCategory> trackedCats = [];
    if (map['tracked_categories_data'] != null) {
      final List<dynamic> catsData = map['tracked_categories_data'] as List<dynamic>;
      trackedCats = catsData
          .map((cat) => TrackedCategory.fromMap(cat as Map<String, dynamic>))
          .toList();
    }

    return GoalModel(
      id: map['id'] as int,
      uuid: map['uuid'] as String?,  // Aceita UUID do backend
      title: map['title'] as String,
      description: (map['description'] as String?) ?? '',
      targetAmount: double.parse(map['target_amount'].toString()),
      currentAmount: double.parse(map['current_amount'].toString()),
      initialAmount: map['initial_amount'] != null
          ? double.parse(map['initial_amount'].toString())
          : 0.0,
      deadline: map['deadline'] != null
          ? DateTime.parse(map['deadline'] as String)
          : null,
      goalType: _parseGoalType(map['goal_type'] as String?),
      targetCategory: map['target_category'] as int?,
      categoryName: map['category_name'] as String?,
      trackedCategories: trackedCats,
      autoUpdate: (map['auto_update'] as bool?) ?? false,
      trackingPeriod: _parseTrackingPeriod(map['tracking_period'] as String?),
      isReductionGoal: (map['is_reduction_goal'] as bool?) ?? false,
      progressPercentage:
          double.parse(map['progress_percentage']?.toString() ?? '0'),
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  static GoalType _parseGoalType(String? value) {
    switch (value?.toUpperCase()) {
      case 'SAVINGS':
        return GoalType.savings;
      case 'CATEGORY_EXPENSE':
        return GoalType.categoryExpense;
      case 'CATEGORY_INCOME':
        return GoalType.categoryIncome;
      case 'DEBT_REDUCTION':
        return GoalType.debtReduction;
      default:
        return GoalType.custom;
    }
  }

  static TrackingPeriod _parseTrackingPeriod(String? value) {
    switch (value?.toUpperCase()) {
      case 'MONTHLY':
        return TrackingPeriod.monthly;
      case 'QUARTERLY':
        return TrackingPeriod.quarterly;
      default:
        return TrackingPeriod.total;
    }
  }

  double get progress =>
      targetAmount == 0 ? 0 : (currentAmount / targetAmount).clamp(0, 1);

  /// Retorna o identificador preferencial (UUID se disponível, senão ID)
  dynamic get identifier => uuid ?? id;
  
  /// Verifica se possui UUID
  bool get hasUuid => uuid != null;

  /// Verifica se a meta está completa
  bool get isCompleted => progressPercentage >= 100;

  /// Verifica se o prazo expirou
  bool get isExpired {
    if (deadline == null) return false;
    return DateTime.now().isAfter(deadline!);
  }

  /// Dias restantes até o prazo
  int? get daysRemaining {
    if (deadline == null) return null;
    final diff = deadline!.difference(DateTime.now());
    return diff.inDays;
  }

  /// Valor restante para atingir a meta
  double get amountRemaining => (targetAmount - currentAmount).clamp(0, double.infinity);
}

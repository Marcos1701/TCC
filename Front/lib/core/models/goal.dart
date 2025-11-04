/// Tipos de metas financeiras
enum GoalType {
  savings('SAVINGS', 'Juntar Dinheiro', '💰'),
  categoryExpense('CATEGORY_EXPENSE', 'Reduzir Gastos', '📉'),
  categoryIncome('CATEGORY_INCOME', 'Aumentar Receita', '📈'),
  debtReduction('DEBT_REDUCTION', 'Reduzir Dívidas', '💳'),
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

/// Modelo de Meta Financeira
class GoalModel {
  const GoalModel({
    required this.id,
    required this.title,
    required this.description,
    required this.targetAmount,
    required this.currentAmount,
    this.deadline,
    required this.goalType,
    this.targetCategory,
    this.categoryName,
    required this.autoUpdate,
    required this.trackingPeriod,
    required this.isReductionGoal,
    required this.progressPercentage,
    required this.createdAt,
    required this.updatedAt,
  });

  final int id;
  final String title;
  final String description;
  final double targetAmount;
  final double currentAmount;
  final DateTime? deadline;
  final GoalType goalType;
  final int? targetCategory;
  final String? categoryName;
  final bool autoUpdate;
  final TrackingPeriod trackingPeriod;
  final bool isReductionGoal;
  final double progressPercentage;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory GoalModel.fromMap(Map<String, dynamic> map) {
    return GoalModel(
      id: map['id'] as int,
      title: map['title'] as String,
      description: (map['description'] as String?) ?? '',
      targetAmount: double.parse(map['target_amount'].toString()),
      currentAmount: double.parse(map['current_amount'].toString()),
      deadline: map['deadline'] != null
          ? DateTime.parse(map['deadline'] as String)
          : null,
      goalType: _parseGoalType(map['goal_type'] as String?),
      targetCategory: map['target_category'] as int?,
      categoryName: map['category_name'] as String?,
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

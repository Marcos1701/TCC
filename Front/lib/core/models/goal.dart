/// Tipos de metas financeiras
enum GoalType {
  savings('SAVINGS', 'Juntar Dinheiro', '💰'),
  expenseReduction('EXPENSE_REDUCTION', 'Reduzir Gastos', '📉'),
  incomeIncrease('INCOME_INCREASE', 'Aumentar Receita', '📈'),
  emergencyFund('EMERGENCY_FUND', 'Fundo de Emergência', '🛡️'),
  custom('CUSTOM', 'Personalizada', '✏️');

  const GoalType(this.value, this.label, this.icon);
  final String value;
  final String label;
  final String icon;
}

/// Modelo de Meta Financeira
class GoalModel {
  const GoalModel({
    required this.id,
    required this.title,
    required this.description,
    required this.targetAmount,
    required this.currentAmount,
    this.initialAmount = 0.0,
    this.deadline,
    required this.goalType,
    required this.progressPercentage,
    required this.createdAt,
    required this.updatedAt,
    this.targetCategory,
    this.targetCategoryName,
    this.baselineAmount,
    this.trackingPeriodMonths = 3,
  });

  final String id;
  final String title;
  final String description;
  final double targetAmount;
  final double currentAmount;
  final double initialAmount;
  final DateTime? deadline;
  final GoalType goalType;
  final double progressPercentage;
  final DateTime createdAt;
  final DateTime updatedAt;
  
  // Novos campos para tipos específicos de meta
  final String? targetCategory;       // UUID da categoria (para EXPENSE_REDUCTION)
  final String? targetCategoryName;   // Nome da categoria (read-only da API)
  final double? baselineAmount;       // Valor de referência inicial
  final int trackingPeriodMonths;     // Período de cálculo em meses (padrão 3)

  factory GoalModel.fromMap(Map<String, dynamic> map) {
    return GoalModel(
      id: map['id'].toString(),
      title: (map['title'] as String?) ?? '',
      description: (map['description'] as String?) ?? '',
      targetAmount: double.tryParse(map['target_amount']?.toString() ?? '0') ?? 0.0,
      currentAmount: double.tryParse(map['current_amount']?.toString() ?? '0') ?? 0.0,
      initialAmount: map['initial_amount'] != null
          ? double.tryParse(map['initial_amount'].toString()) ?? 0.0
          : 0.0,
      deadline: map['deadline'] != null
          ? DateTime.tryParse(map['deadline'] as String)
          : null,
      goalType: _parseGoalType(map['goal_type'] as String?),
      progressPercentage:
          double.tryParse(map['progress_percentage']?.toString() ?? '0') ?? 0.0,
      createdAt: map['created_at'] != null 
          ? DateTime.tryParse(map['created_at'] as String) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: map['updated_at'] != null
          ? DateTime.tryParse(map['updated_at'] as String) ?? DateTime.now()
          : DateTime.now(),
      // Novos campos
      targetCategory: map['target_category'] as String?,
      targetCategoryName: map['target_category_name'] as String?,
      baselineAmount: map['baseline_amount'] != null
          ? double.tryParse(map['baseline_amount'].toString())
          : null,
      trackingPeriodMonths: map['tracking_period_months'] as int? ?? 3,
    );
  }

  static GoalType _parseGoalType(String? value) {
    switch (value?.toUpperCase()) {
      case 'SAVINGS':
        return GoalType.savings;
      case 'EXPENSE_REDUCTION':
        return GoalType.expenseReduction;
      case 'INCOME_INCREASE':
        return GoalType.incomeIncrease;
      case 'EMERGENCY_FUND':
        return GoalType.emergencyFund;
      default:
        return GoalType.custom;
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'goal_type': goalType.value,
      'target_amount': targetAmount.toString(),
      if (initialAmount > 0) 'initial_amount': initialAmount.toString(),
      if (deadline != null) 
        'deadline': deadline!.toIso8601String().split('T')[0],
      // Novos campos (condicionais)
      if (targetCategory != null) 'target_category': targetCategory,
      if (baselineAmount != null) 'baseline_amount': baselineAmount.toString(),
      'tracking_period_months': trackingPeriodMonths,
    };
  }

  double get progress =>
      targetAmount == 0 ? 0 : (currentAmount / targetAmount).clamp(0, 1);

  /// Retorna o identificador preferencial
  String get identifier => id;
  
  /// Verifica se possui UUID
  bool get hasUuid => true;

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

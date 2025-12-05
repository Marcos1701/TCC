/// Tipos de metas financeiras
enum GoalType {
  savings('SAVINGS', 'Economizar', '💰'),
  expenseReduction('EXPENSE_REDUCTION', 'Reduzir Gastos', '📉'),
  incomeIncrease('INCOME_INCREASE', 'Aumentar Receita', '📈'),
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
    this.targetCategories = const [],
    this.targetCategoryNames = const [],
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
  
  // Suporte a múltiplas categorias
  final List<String> targetCategories;     // Lista de IDs de categorias
  final List<String> targetCategoryNames;  // Lista de nomes (read-only)
  final double? baselineAmount;            // Valor de referência inicial
  final int trackingPeriodMonths;          // Período de cálculo em meses

  /// Compatibilidade retroativa: primeira categoria
  String? get targetCategory => targetCategories.isNotEmpty ? targetCategories.first : null;
  
  /// Compatibilidade retroativa: nome da primeira categoria
  String? get targetCategoryName => targetCategoryNames.isNotEmpty ? targetCategoryNames.first : null;

  factory GoalModel.fromMap(Map<String, dynamic> map) {
    // Parse target_categories (lista de IDs)
    List<String> categories = [];
    if (map['target_categories'] != null) {
      categories = (map['target_categories'] as List)
          .map((e) => e.toString())
          .toList();
    } else if (map['target_category'] != null) {
      // Compatibilidade retroativa
      categories = [map['target_category'].toString()];
    }
    
    // Parse target_category_names (lista de nomes)
    List<String> categoryNames = [];
    if (map['target_category_names'] != null) {
      categoryNames = (map['target_category_names'] as List)
          .map((e) => e.toString())
          .toList();
    } else if (map['target_category_name'] != null) {
      // Compatibilidade retroativa
      categoryNames = [map['target_category_name'].toString()];
    }
    
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
      // Múltiplas categorias
      targetCategories: categories,
      targetCategoryNames: categoryNames,
      baselineAmount: map['baseline_amount'] != null
          ? double.tryParse(map['baseline_amount'].toString())
          : null,
      trackingPeriodMonths: map['tracking_period_months'] as int? ?? 3,
    );
  }

  static GoalType _parseGoalType(String? value) {
    switch (value?.toUpperCase()) {
      case 'SAVINGS':
      case 'EMERGENCY_FUND':  // Compatibilidade: tratar como SAVINGS
        return GoalType.savings;
      case 'EXPENSE_REDUCTION':
        return GoalType.expenseReduction;
      case 'INCOME_INCREASE':
        return GoalType.incomeIncrease;
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
      // Múltiplas categorias
      if (targetCategories.isNotEmpty) 'target_categories': targetCategories,
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
  
  /// Nome(s) das categorias formatado para exibição
  String get categoriesDisplayName {
    if (targetCategoryNames.isEmpty) return '';
    if (targetCategoryNames.length == 1) return targetCategoryNames.first;
    return '${targetCategoryNames.first} +${targetCategoryNames.length - 1}';
  }
}

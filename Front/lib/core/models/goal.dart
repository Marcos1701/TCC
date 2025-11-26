/// Tipos de metas financeiras
enum GoalType {
  savings('SAVINGS', 'Juntar Dinheiro', '💰'),
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

  factory GoalModel.fromMap(Map<String, dynamic> map) {
    return GoalModel(
      id: map['id'].toString(),
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
      default:
        return GoalType.custom;
    }
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

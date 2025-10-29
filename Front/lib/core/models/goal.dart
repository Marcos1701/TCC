class GoalModel {
  const GoalModel({
    required this.id,
    required this.title,
    required this.description,
    required this.targetAmount,
    required this.currentAmount,
    this.deadline,
  });

  final int id;
  final String title;
  final String description;
  final double targetAmount;
  final double currentAmount;
  final DateTime? deadline;

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
    );
  }

  double get progress =>
      targetAmount == 0 ? 0 : (currentAmount / targetAmount).clamp(0, 1);
}

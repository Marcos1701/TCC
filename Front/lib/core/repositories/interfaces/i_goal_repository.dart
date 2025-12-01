import '../../models/goal.dart';
import '../../models/transaction.dart';

abstract class IGoalRepository {
  Future<List<GoalModel>> fetchGoals();

  Future<GoalModel> createGoal({
    required String title,
    required double targetAmount,
    String description = '',
    double currentAmount = 0,
    double initialAmount = 0,
    DateTime? deadline,
    String goalType = 'CUSTOM',
  });

  Future<GoalModel> updateGoal({
    required String goalId,
    String? title,
    String? description,
    double? targetAmount,
    double? currentAmount,
    double? initialAmount,
    DateTime? deadline,
    String? goalType,
  });

  Future<void> deleteGoal(String id);

  Future<List<TransactionModel>> fetchGoalTransactions(String goalId);

  Future<GoalModel> refreshGoalProgress(String goalId);

  Future<Map<String, dynamic>> fetchGoalInsights(String goalId);
}

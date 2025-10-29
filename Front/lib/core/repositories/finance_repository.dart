import '../models/dashboard.dart';
import '../models/goal.dart';
import '../models/mission.dart';
import '../models/mission_progress.dart';
import '../models/category.dart';
import '../models/transaction.dart';
import '../network/api_client.dart';
import '../network/endpoints.dart';

class FinanceRepository {
  FinanceRepository({ApiClient? client}) : _client = client ?? ApiClient();

  final ApiClient _client;

  Future<DashboardData> fetchDashboard() async {
    final response = await _client.client.get<Map<String, dynamic>>(ApiEndpoints.dashboard);
    return DashboardData.fromMap(response.data ?? <String, dynamic>{});
  }

  Future<List<CategoryModel>> fetchCategories({String? type}) async {
    final queryType = type == 'DEBT_PAYMENT' ? 'DEBT' : type;
    final response = await _client.client.get<List<dynamic>>(
      ApiEndpoints.categories,
      queryParameters: queryType != null ? {'type': queryType} : null,
    );
    final items = response.data ?? <dynamic>[];
    return items
        .map((e) => CategoryModel.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<TransactionModel>> fetchTransactions({String? type}) async {
    final response = await _client.client.get<List<dynamic>>(
      ApiEndpoints.transactions,
      queryParameters: type != null ? {'type': type} : null,
    );
    final items = response.data ?? <dynamic>[];
    return items
        .map((e) => TransactionModel.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  Future<TransactionModel> createTransaction({
    required String type,
    required String description,
    required double amount,
    required DateTime date,
    int? categoryId,
  }) async {
    final payload = {
      'type': type,
      'description': description,
      'amount': amount,
      'date': date.toIso8601String().split('T').first,
      if (categoryId != null) 'category_id': categoryId,
    };
    final response = await _client.client.post<Map<String, dynamic>>(
      ApiEndpoints.transactions,
      data: payload,
    );
    return TransactionModel.fromMap(response.data ?? <String, dynamic>{});
  }

  Future<void> deleteTransaction(int id) async {
    await _client.client.delete('${ApiEndpoints.transactions}$id/');
  }

  Future<MissionProgressModel> startMission(int missionId) async {
    final response = await _client.client.post<Map<String, dynamic>>(
      ApiEndpoints.missionProgress,
      data: {'mission_id': missionId},
    );
    return MissionProgressModel.fromMap(response.data ?? <String, dynamic>{});
  }

  Future<MissionProgressModel> updateMission({
    required int progressId,
    String? status,
    double? progress,
  }) async {
    final payload = <String, dynamic>{};
    if (status != null) payload['status'] = status;
    if (progress != null) payload['progress'] = progress;
    final response = await _client.client.patch<Map<String, dynamic>>(
      '${ApiEndpoints.missionProgress}$progressId/',
      data: payload,
    );
    return MissionProgressModel.fromMap(response.data ?? <String, dynamic>{});
  }

  Future<List<MissionModel>> fetchMissions() async {
    final response = await _client.client.get<List<dynamic>>(ApiEndpoints.missions);
    final data = response.data ?? <dynamic>[];
    return data.map((e) => MissionModel.fromMap(e as Map<String, dynamic>)).toList();
  }

  Future<List<GoalModel>> fetchGoals() async {
    final response = await _client.client.get<List<dynamic>>(ApiEndpoints.goals);
    final data = response.data ?? <dynamic>[];
    return data.map((e) => GoalModel.fromMap(e as Map<String, dynamic>)).toList();
  }

  Future<GoalModel> createGoal({
    required String title,
    String description = '',
    required double targetAmount,
    double currentAmount = 0,
    DateTime? deadline,
  }) async {
    final payload = {
      'title': title,
      'description': description,
      'target_amount': targetAmount,
      'current_amount': currentAmount,
      if (deadline != null) 'deadline': deadline.toIso8601String().split('T').first,
    };
    final response = await _client.client.post<Map<String, dynamic>>(
      ApiEndpoints.goals,
      data: payload,
    );
    return GoalModel.fromMap(response.data ?? <String, dynamic>{});
  }

  Future<GoalModel> updateGoal({
    required int goalId,
    String? title,
    String? description,
    double? targetAmount,
    double? currentAmount,
    DateTime? deadline,
  }) async {
    final payload = <String, dynamic>{};
    if (title != null) payload['title'] = title;
    if (description != null) payload['description'] = description;
    if (targetAmount != null) payload['target_amount'] = targetAmount;
    if (currentAmount != null) payload['current_amount'] = currentAmount;
    if (deadline != null) {
      payload['deadline'] = deadline.toIso8601String().split('T').first;
    }
    final response = await _client.client.patch<Map<String, dynamic>>(
      '${ApiEndpoints.goals}$goalId/',
      data: payload,
    );
    return GoalModel.fromMap(response.data ?? <String, dynamic>{});
  }

  Future<void> deleteGoal(int id) async {
    await _client.client.delete('${ApiEndpoints.goals}$id/');
  }
}

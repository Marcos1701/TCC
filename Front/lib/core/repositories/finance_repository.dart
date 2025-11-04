import '../models/dashboard.dart';
import '../models/goal.dart';
import '../models/mission.dart';
import '../models/mission_progress.dart';
import '../models/category.dart';
import '../models/transaction.dart';
import '../models/transaction_link.dart';
import '../network/api_client.dart';
import '../network/endpoints.dart';

class FinanceRepository {
  FinanceRepository({ApiClient? client}) : _client = client ?? ApiClient();

  final ApiClient _client;

  Future<DashboardData> fetchDashboard() async {
    final response =
        await _client.client.get<Map<String, dynamic>>(ApiEndpoints.dashboard);
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

  Future<CategoryModel> createCategory({
    required String name,
    required String type,
    String? color,
    String? group,
  }) async {
    final normalizedType = type == 'DEBT_PAYMENT' ? 'DEBT' : type;
    final payload = {
      'name': name,
      'type': normalizedType,
      if (color != null) 'color': color,
      if (group != null) 'group': group,
    };
    final response = await _client.client.post<Map<String, dynamic>>(
      ApiEndpoints.categories,
      data: payload,
    );
    return CategoryModel.fromMap(response.data ?? <String, dynamic>{});
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
    bool isRecurring = false,
    int? recurrenceValue,
    String? recurrenceUnit,
    DateTime? recurrenceEndDate,
  }) async {
    final payload = {
      'type': type,
      'description': description,
      'amount': amount,
      'date': date.toIso8601String().split('T').first,
      if (categoryId != null) 'category_id': categoryId,
      if (isRecurring) 'is_recurring': true,
      if (isRecurring && recurrenceValue != null)
        'recurrence_value': recurrenceValue,
      if (isRecurring && recurrenceUnit != null)
        'recurrence_unit': recurrenceUnit,
      if (isRecurring && recurrenceEndDate != null)
        'recurrence_end_date':
            recurrenceEndDate.toIso8601String().split('T').first,
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

  Future<Map<String, dynamic>> fetchTransactionDetails(int id) async {
    final response = await _client.client
        .get<Map<String, dynamic>>('${ApiEndpoints.transactions}$id/details/');
    return response.data ?? <String, dynamic>{};
  }

  Future<TransactionModel> updateTransaction({
    required int id,
    String? type,
    String? description,
    double? amount,
    DateTime? date,
    int? categoryId,
    bool? isRecurring,
    int? recurrenceValue,
    String? recurrenceUnit,
    DateTime? recurrenceEndDate,
  }) async {
    final payload = <String, dynamic>{};
    if (type != null) payload['type'] = type;
    if (description != null) payload['description'] = description;
    if (amount != null) payload['amount'] = amount;
    if (date != null) {
      payload['date'] = date.toIso8601String().split('T').first;
    }
    if (categoryId != null) {
      payload['category_id'] = categoryId;
    }
    if (isRecurring != null) payload['is_recurring'] = isRecurring;
    if (recurrenceValue != null) payload['recurrence_value'] = recurrenceValue;
    if (recurrenceUnit != null) payload['recurrence_unit'] = recurrenceUnit;
    if (recurrenceEndDate != null) {
      payload['recurrence_end_date'] =
          recurrenceEndDate.toIso8601String().split('T').first;
    }

    final response = await _client.client.patch<Map<String, dynamic>>(
      '${ApiEndpoints.transactions}$id/',
      data: payload,
    );
    return TransactionModel.fromMap(response.data ?? <String, dynamic>{});
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
    final response =
        await _client.client.get<List<dynamic>>(ApiEndpoints.missions);
    final data = response.data ?? <dynamic>[];
    return data
        .map((e) => MissionModel.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<GoalModel>> fetchGoals() async {
    final response =
        await _client.client.get<List<dynamic>>(ApiEndpoints.goals);
    final data = response.data ?? <dynamic>[];
    return data
        .map((e) => GoalModel.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  Future<GoalModel> createGoal({
    required String title,
    String description = '',
    required double targetAmount,
    double currentAmount = 0,
    DateTime? deadline,
    String goalType = 'CUSTOM',
    int? targetCategoryId,
    List<int>? trackedCategoryIds,
    bool autoUpdate = false,
    String trackingPeriod = 'TOTAL',
    bool isReductionGoal = false,
  }) async {
    final payload = {
      'title': title,
      'description': description,
      'target_amount': targetAmount,
      'current_amount': currentAmount,
      if (deadline != null)
        'deadline': deadline.toIso8601String().split('T').first,
      'goal_type': goalType,
      if (targetCategoryId != null) 'target_category': targetCategoryId,
      if (trackedCategoryIds != null && trackedCategoryIds.isNotEmpty)
        'tracked_category_ids': trackedCategoryIds,
      'auto_update': autoUpdate,
      'tracking_period': trackingPeriod,
      'is_reduction_goal': isReductionGoal,
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
    String? goalType,
    int? targetCategoryId,
    List<int>? trackedCategoryIds,
    bool? autoUpdate,
    String? trackingPeriod,
    bool? isReductionGoal,
  }) async {
    final payload = <String, dynamic>{};
    if (title != null) payload['title'] = title;
    if (description != null) payload['description'] = description;
    if (targetAmount != null) payload['target_amount'] = targetAmount;
    if (currentAmount != null) payload['current_amount'] = currentAmount;
    if (deadline != null) {
      payload['deadline'] = deadline.toIso8601String().split('T').first;
    }
    if (goalType != null) payload['goal_type'] = goalType;
    if (targetCategoryId != null) payload['target_category'] = targetCategoryId;
    if (trackedCategoryIds != null) {
      payload['tracked_category_ids'] = trackedCategoryIds;
    }
    if (autoUpdate != null) payload['auto_update'] = autoUpdate;
    if (trackingPeriod != null) payload['tracking_period'] = trackingPeriod;
    if (isReductionGoal != null) payload['is_reduction_goal'] = isReductionGoal;
    
    final response = await _client.client.patch<Map<String, dynamic>>(
      '${ApiEndpoints.goals}$goalId/',
      data: payload,
    );
    return GoalModel.fromMap(response.data ?? <String, dynamic>{});
  }

  Future<void> deleteGoal(int id) async {
    await _client.client.delete('${ApiEndpoints.goals}$id/');
  }

  /// Buscar transações relacionadas a uma meta
  Future<List<TransactionModel>> fetchGoalTransactions(int goalId) async {
    final response = await _client.client
        .get<List<dynamic>>('${ApiEndpoints.goals}$goalId/transactions/');
    final data = response.data ?? <dynamic>[];
    return data
        .map((e) => TransactionModel.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  /// Atualizar progresso da meta manualmente
  Future<GoalModel> refreshGoalProgress(int goalId) async {
    final response = await _client.client
        .post<Map<String, dynamic>>('${ApiEndpoints.goals}$goalId/refresh/');
    return GoalModel.fromMap(response.data ?? <String, dynamic>{});
  }

  /// Buscar insights sobre a meta
  Future<Map<String, dynamic>> fetchGoalInsights(int goalId) async {
    final response = await _client.client
        .get<Map<String, dynamic>>('${ApiEndpoints.goals}$goalId/insights/');
    return response.data ?? <String, dynamic>{};
  }

  Future<Map<String, dynamic>> fetchMissionProgressDetails(int id) async {
    final response = await _client.client.get<Map<String, dynamic>>(
        '${ApiEndpoints.missionProgress}$id/details/');
    return response.data ?? <String, dynamic>{};
  }

  // ============================================================================
  // TRANSACTION LINK METHODS
  // ============================================================================

  /// Buscar receitas com saldo disponível
  Future<List<TransactionModel>> fetchAvailableIncomes({double? minAmount}) async {
    final queryParams = <String, dynamic>{};
    if (minAmount != null) {
      queryParams['min_amount'] = minAmount.toString();
    }
    
    final response = await _client.client.get<List<dynamic>>(
      '${ApiEndpoints.transactionLinks}available_sources/',
      queryParameters: queryParams.isNotEmpty ? queryParams : null,
    );
    
    final items = response.data ?? <dynamic>[];
    return items
        .map((e) => TransactionModel.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  /// Buscar dívidas pendentes
  Future<List<TransactionModel>> fetchPendingDebts({double? maxAmount}) async {
    final queryParams = <String, dynamic>{};
    if (maxAmount != null) {
      queryParams['max_amount'] = maxAmount.toString();
    }
    
    final response = await _client.client.get<List<dynamic>>(
      '${ApiEndpoints.transactionLinks}available_targets/',
      queryParameters: queryParams.isNotEmpty ? queryParams : null,
    );
    
    final items = response.data ?? <dynamic>[];
    return items
        .map((e) => TransactionModel.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  /// Criar vinculação
  Future<TransactionLinkModel> createTransactionLink(
      CreateTransactionLinkRequest request) async {
    final response = await _client.client.post<Map<String, dynamic>>(
      '${ApiEndpoints.transactionLinks}quick_link/',
      data: request.toMap(),
    );
    
    return TransactionLinkModel.fromMap(response.data ?? <String, dynamic>{});
  }

  /// Deletar vinculação
  Future<void> deleteTransactionLink(int linkId) async {
    await _client.client.delete('${ApiEndpoints.transactionLinks}$linkId/');
  }

  /// Listar vinculações
  Future<List<TransactionLinkModel>> fetchTransactionLinks({
    String? linkType,
    String? dateFrom,
    String? dateTo,
  }) async {
    final queryParams = <String, dynamic>{};
    if (linkType != null) queryParams['link_type'] = linkType;
    if (dateFrom != null) queryParams['date_from'] = dateFrom;
    if (dateTo != null) queryParams['date_to'] = dateTo;
    
    final response = await _client.client.get<List<dynamic>>(
      ApiEndpoints.transactionLinks,
      queryParameters: queryParams.isNotEmpty ? queryParams : null,
    );
    
    final items = response.data ?? <dynamic>[];
    return items
        .map((e) => TransactionLinkModel.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  /// Buscar relatório de pagamentos
  Future<Map<String, dynamic>> fetchPaymentReport({
    String? startDate,
    String? endDate,
    int? categoryId,
  }) async {
    final queryParams = <String, dynamic>{};
    if (startDate != null) queryParams['start_date'] = startDate;
    if (endDate != null) queryParams['end_date'] = endDate;
    if (categoryId != null) queryParams['category'] = categoryId.toString();
    
    final response = await _client.client.get<Map<String, dynamic>>(
      '${ApiEndpoints.transactionLinks}payment_report/',
      queryParameters: queryParams.isNotEmpty ? queryParams : null,
    );
    
    return response.data ?? <String, dynamic>{};
  }

  // ============ USER PROFILE ENDPOINTS ============

  Future<Map<String, dynamic>> fetchUserProfile() async {
    final response = await _client.client.get<Map<String, dynamic>>(
      '${ApiEndpoints.user}me/',
    );
    return response.data ?? {};
  }

  Future<Map<String, dynamic>> updateUserProfile({
    required String name,
    required String email,
  }) async {
    final response = await _client.client.patch<Map<String, dynamic>>(
      '${ApiEndpoints.user}update_profile/',
      data: {
        'name': name,
        'email': email,
      },
    );
    return response.data ?? {};
  }

  Future<Map<String, dynamic>> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final response = await _client.client.post<Map<String, dynamic>>(
      '${ApiEndpoints.user}change_password/',
      data: {
        'current_password': currentPassword,
        'new_password': newPassword,
      },
    );
    return response.data ?? {};
  }

  Future<Map<String, dynamic>> deleteAccount({
    required String password,
  }) async {
    final response = await _client.client.delete<Map<String, dynamic>>(
      '${ApiEndpoints.user}delete_account/',
      data: {
        'password': password,
      },
    );
    return response.data ?? {};
  }
}

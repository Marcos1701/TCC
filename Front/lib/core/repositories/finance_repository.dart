import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';

import '../models/dashboard.dart';
import '../models/goal.dart';
import '../models/mission.dart';
import '../models/mission_progress.dart';
import '../models/category.dart';
import '../models/transaction.dart';
import '../models/transaction_link.dart';
import '../models/friendship.dart';
import '../models/leaderboard.dart';
import '../models/user_search.dart';
import '../network/api_client.dart';
import '../network/endpoints.dart';
import '../services/cache_service.dart';
import '../errors/failures.dart';
import '../utils/date_formatter.dart';

class FinanceRepository {
  FinanceRepository({ApiClient? client}) : _client = client ?? ApiClient();

  final ApiClient _client;

  Failure _handleError(dynamic error) {
    if (error is DioException) {
      switch (error.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
        case DioExceptionType.connectionError:
          return const NetworkFailure('Verifique sua conexão com a internet');
        
        case DioExceptionType.badResponse:
          final statusCode = error.response?.statusCode;
          final data = error.response?.data;
          
          if (statusCode == 401) {
            return const UnauthorizedFailure();
          }
          
          if (statusCode == 404) {
            return const NotFoundFailure();
          }
          
          if (statusCode == 400 && data is Map<String, dynamic>) {
            final message = data['detail'] ?? 
                           data['error'] ?? 
                           data['message'] ?? 
                           'Dados inválidos';
            return ValidationFailure(message.toString(), errors: data);
          }
          
          if (data is Map<String, dynamic>) {
            final message = data['detail'] ?? data['error'] ?? 'Erro no servidor';
            return ServerFailure(message.toString(), statusCode: statusCode);
          }
          
          return ServerFailure(
            'Erro no servidor (${statusCode ?? "desconhecido"})',
            statusCode: statusCode,
          );
        
        default:
          return NetworkFailure(error.message ?? 'Erro de conexão');
      }
    }
    
    return ServerFailure(error.toString());
  }

  List<dynamic> _extractListFromResponse(dynamic data) {
    if (data == null) {
      debugPrint('⚠️ _extractListFromResponse: data é null');
      return [];
    }
    
    if (data is Map<String, dynamic>) {
      if (data.containsKey('results')) {
        final results = data['results'];
        
        if (results is List<dynamic>) {
          return results;
        } else {
          return [];
        }
      }
      
      if (data.containsKey('detail') || data.containsKey('error')) {
        debugPrint('🚨 Resposta de erro detectada: $data');
      }
      return [];
    }
    
    if (data is List<dynamic>) {
      return data;
    }
    
    return [];
  }

  Future<DashboardData> fetchDashboard() async {
    try {
      final cached = CacheService.getCachedDashboard();
      if (cached != null) {
        return DashboardData.fromMap(cached);
      }
      
      final response =
          await _client.client.get<Map<String, dynamic>>(ApiEndpoints.dashboard);
      final data = response.data ?? <String, dynamic>{};
      
      await CacheService.cacheDashboard(data);
      return DashboardData.fromMap(data);
    } catch (e) {
      if (e is Failure) rethrow;
      throw _handleError(e);
    }
  }

  Future<List<CategoryModel>> fetchCategories({String? type}) async {
    try {
      if (type == null) {
        final cached = CacheService.getCachedCategories();
        if (cached != null) {
          return cached.map((e) => CategoryModel.fromMap(e)).toList();
        }
      }
      
      final response = await _client.client.get<dynamic>(
        ApiEndpoints.categories,
        queryParameters: type != null ? {'type': type} : null,
      );
      final items = _extractListFromResponse(response.data);
      final categories = items
          .map((e) => CategoryModel.fromMap(e as Map<String, dynamic>))
          .toList();
      
      if (type == null) {
        await CacheService.cacheCategories(
          categories.map((c) => c.toMap()).toList(),
        );
      }
      
      return categories;
    } catch (e) {
      if (e is Failure) rethrow;
      throw _handleError(e);
    }
  }

  Future<CategoryModel> createCategory({
    required String name,
    required String type,
    String? color,
    String? group,
  }) async {
    final payload = {
      'name': name,
      'type': type,
      if (color != null) 'color': color,
      if (group != null) 'group': group,
    };
    final response = await _client.client.post<Map<String, dynamic>>(
      ApiEndpoints.categories,
      data: payload,
    );
    await CacheService.invalidateCategories();
    return CategoryModel.fromMap(response.data ?? <String, dynamic>{});
  }

  Future<CategoryModel> updateCategory({
    required String id,
    required String name,
    required String type,
    String? color,
    String? group,
  }) async {
    final payload = {
      'name': name,
      'type': type,
      if (color != null) 'color': color,
      if (group != null) 'group': group,
    };
    final response = await _client.client.put<Map<String, dynamic>>(
      '${ApiEndpoints.categories}$id/',
      data: payload,
    );
    await CacheService.invalidateCategories();
    return CategoryModel.fromMap(response.data ?? <String, dynamic>{});
  }

  Future<void> deleteCategory(String id) async {
    try {
      await _client.client.delete('${ApiEndpoints.categories}$id/');
      await CacheService.invalidateCategories();
    } catch (e) {
      throw _handleError(e);
    }
  }

  Future<List<TransactionModel>> fetchTransactions({String? type}) async {
    try {
      final response = await _client.client.get<dynamic>(
        ApiEndpoints.transactions,
        queryParameters: type != null ? {'type': type} : null,
      );
      
      final items = _extractListFromResponse(response.data);
      
      return items
          .map((e) {
            if (e is! Map<String, dynamic>) {
              throw const ParseFailure('Formato de transação inválido');
            }
            return TransactionModel.fromMap(e);
          })
          .toList();
    } catch (e) {
      if (e is Failure) rethrow;
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> createTransaction({
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
      'date': DateFormatter.toApiFormat(date),
      if (categoryId != null) 'category_id': categoryId,
      if (isRecurring) 'is_recurring': true,
      if (isRecurring && recurrenceValue != null)
        'recurrence_value': recurrenceValue,
      if (isRecurring && recurrenceUnit != null)
        'recurrence_unit': recurrenceUnit,
      if (isRecurring && recurrenceEndDate != null)
        'recurrence_end_date': DateFormatter.toApiFormat(recurrenceEndDate),
    };
    final response = await _client.client.post<Map<String, dynamic>>(
      ApiEndpoints.transactions,
      data: payload,
    );
    await CacheService.invalidateDashboard();
    await CacheService.invalidateMissions();
    return response.data ?? <String, dynamic>{};
  }

  Future<void> deleteTransaction(String id) async {
    await _client.client.delete('${ApiEndpoints.transactions}$id/');
    await CacheService.invalidateDashboard();
    await CacheService.invalidateMissions();
  }

  Future<Map<String, dynamic>> fetchTransactionDetails(String id) async {
    final response = await _client.client
        .get<Map<String, dynamic>>('${ApiEndpoints.transactions}$id/details/');
    return response.data ?? <String, dynamic>{};
  }

  Future<TransactionModel> updateTransaction({
    required String id,
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
      payload['date'] = DateFormatter.toApiFormat(date);
    }
    if (categoryId != null) {
      payload['category_id'] = categoryId;
    }
    if (isRecurring != null) payload['is_recurring'] = isRecurring;
    if (recurrenceValue != null) payload['recurrence_value'] = recurrenceValue;
    if (recurrenceUnit != null) payload['recurrence_unit'] = recurrenceUnit;
    if (recurrenceEndDate != null) {
      payload['recurrence_end_date'] = DateFormatter.toApiFormat(recurrenceEndDate);
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
    final cached = CacheService.getCachedMissions();
    if (cached != null) {
      return cached.map((e) => MissionModel.fromMap(e)).toList();
    }
    
    final response =
        await _client.client.get<dynamic>(ApiEndpoints.missions);
    final items = _extractListFromResponse(response.data);
    final missions = items
        .map((e) => MissionModel.fromMap(e as Map<String, dynamic>))
        .toList();
    
    final invalidMissions = missions.where((m) => m.hasPlaceholders()).toList();
    if (invalidMissions.isNotEmpty) {
      debugPrint(
        '⚠️ API retornou ${invalidMissions.length} missão(ões) com placeholders:\n'
        '${invalidMissions.map((m) => '  - ID ${m.id}: "${m.title}" -> ${m.getPlaceholders()}').join('\n')}'
      );
    }
    
    await CacheService.cacheMissions(
      missions.map((m) => m.toMap()).toList(),
    );
    
    return missions;
  }

  Future<List<MissionModel>> fetchRecommendedMissions({
    String? missionType,
    String? difficulty,
    int? limit,
  }) async {
    final query = <String, dynamic>{};
    if (missionType != null && missionType.isNotEmpty) {
      query['type'] = missionType;
    }
    if (difficulty != null && difficulty.isNotEmpty) {
      query['difficulty'] = difficulty;
    }
    if (limit != null && limit > 0) {
      query['limit'] = limit;
    }

    final response = await _client.client.get<dynamic>(
      ApiEndpoints.missionsRecommend,
      queryParameters: query.isEmpty ? null : query,
    );

    final items = _extractListFromResponse(response.data);
    return items
        .map((e) => MissionModel.fromMap(
              Map<String, dynamic>.from(e as Map),
            ))
        .toList();
  }

  Future<List<MissionModel>> fetchMissionsByCategory(
    int categoryId, {
    String? difficulty,
    bool includeInactive = false,
  }) async {
    final query = <String, dynamic>{};
    if (difficulty != null && difficulty.isNotEmpty) {
      query['difficulty'] = difficulty;
    }
    if (includeInactive) {
      query['include_inactive'] = true;
    }

    final response = await _client.client.get<dynamic>(
      '${ApiEndpoints.missionsByCategory}$categoryId/',
      queryParameters: query.isEmpty ? null : query,
    );

    final items = _extractListFromResponse(response.data);
    return items
        .map((e) => MissionModel.fromMap(
              Map<String, dynamic>.from(e as Map),
            ))
        .toList();
  }

  Future<List<MissionModel>> fetchMissionsByGoal(
    int goalId, {
    String? missionType,
    bool includeCompleted = false,
  }) async {
    final query = <String, dynamic>{};
    if (missionType != null && missionType.isNotEmpty) {
      query['type'] = missionType;
    }
    if (includeCompleted) {
      query['include_completed'] = true;
    }

    final response = await _client.client.get<dynamic>(
      '${ApiEndpoints.missionsByGoal}$goalId/',
      queryParameters: query.isEmpty ? null : query,
    );

    final items = _extractListFromResponse(response.data);
    return items
        .map((e) => MissionModel.fromMap(
              Map<String, dynamic>.from(e as Map),
            ))
        .toList();
  }

  Future<Map<String, dynamic>?> fetchMissionContextAnalysis({
    bool forceRefresh = false,
  }) async {
    try {
      final query = forceRefresh ? {'force_refresh': true} : null;
      final response = await _client.client.get<Map<String, dynamic>>(
        ApiEndpoints.missionsContextAnalysis,
        queryParameters: query,
      );
      return response.data != null
          ? Map<String, dynamic>.from(response.data!)
          : null;
    } on DioException catch (e) {
      // Se endpoint não existe (404), retorna null silenciosamente
      if (e.response?.statusCode == 404) {
        debugPrint('⚠️ Análise contextual não disponível (404)');
        return null;
      }
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> fetchMissionTemplates({
    bool includeInactive = false,
  }) async {
    final response = await _client.client.get<dynamic>(
      ApiEndpoints.missionsTemplates,
      queryParameters: includeInactive ? {'include_inactive': true} : null,
    );
    final items = _extractListFromResponse(response.data);
    return items
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  Future<MissionModel> generateMissionFromTemplate({
    required String templateKey,
    Map<String, dynamic>? overrides,
  }) async {
    final payload = {
      'template_key': templateKey,
      if (overrides != null && overrides.isNotEmpty) 'overrides': overrides,
    };
    final response = await _client.client.post<Map<String, dynamic>>(
      ApiEndpoints.missionsGenerateFromTemplate,
      data: payload,
    );
    return MissionModel.fromMap(response.data ?? <String, dynamic>{});
  }

  Future<List<GoalModel>> fetchGoals() async {
    final response =
        await _client.client.get<dynamic>(ApiEndpoints.goals);
    final items = _extractListFromResponse(response.data);
    return items
        .map((e) => GoalModel.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  Future<GoalModel> createGoal({
    required String title,
    String description = '',
    required double targetAmount,
    double currentAmount = 0,
    double initialAmount = 0,
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
      'initial_amount': initialAmount,
      if (deadline != null)
        'deadline': DateFormatter.toApiFormat(deadline),
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

  /// Atualizar meta por ID ou UUID
  Future<GoalModel> updateGoal({
    required String goalId,
    String? title,
    String? description,
    double? targetAmount,
    double? currentAmount,
    double? initialAmount,
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
    if (initialAmount != null) payload['initial_amount'] = initialAmount;
    if (deadline != null) {
      payload['deadline'] = DateFormatter.toApiFormat(deadline);
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

  /// Deletar meta por ID ou UUID
  Future<void> deleteGoal(String id) async {
    await _client.client.delete('${ApiEndpoints.goals}$id/');
  }

  /// Buscar transações relacionadas a uma meta por ID ou UUID
  Future<List<TransactionModel>> fetchGoalTransactions(String goalId) async {
    final response = await _client.client
        .get<dynamic>('${ApiEndpoints.goals}$goalId/transactions/');
    
    final items = _extractListFromResponse(response.data);
    return items
        .map((e) => TransactionModel.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  /// Atualizar progresso da meta manualmente
  Future<GoalModel> refreshGoalProgress(String goalId) async {
    final response = await _client.client
        .post<Map<String, dynamic>>('${ApiEndpoints.goals}$goalId/refresh/');
    return GoalModel.fromMap(response.data ?? <String, dynamic>{});
  }

  /// Buscar insights sobre a meta
  Future<Map<String, dynamic>> fetchGoalInsights(String goalId) async {
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
    
    final response = await _client.client.get<dynamic>(
      '${ApiEndpoints.transactionLinks}available_sources/',
      queryParameters: queryParams.isNotEmpty ? queryParams : null,
    );
    
    final items = _extractListFromResponse(response.data);
    return items
        .map((e) => TransactionModel.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  /// Buscar despesas pendentes
  Future<List<TransactionModel>> fetchPendingExpenses({double? maxAmount}) async {
    final queryParams = <String, dynamic>{};
    if (maxAmount != null) {
      queryParams['max_amount'] = maxAmount.toString();
    }
    
    final response = await _client.client.get<dynamic>(
      '${ApiEndpoints.transactionLinks}available_targets/',
      queryParameters: queryParams.isNotEmpty ? queryParams : null,
    );
    
    final items = _extractListFromResponse(response.data);
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

  /// Deletar vinculação por ID ou UUID
  Future<void> deleteTransactionLink(String linkId) async {
    await _client.client.delete('${ApiEndpoints.transactionLinks}$linkId/');
  }

  /// Buscar resumo de despesas pendentes
  Future<Map<String, dynamic>> fetchPendingSummary({
    String sortBy = 'urgency',
  }) async {
    final response = await _client.client.get<Map<String, dynamic>>(
      '${ApiEndpoints.transactionLinks}pending_summary/',
      queryParameters: {'sort_by': sortBy},
    );
    return response.data ?? <String, dynamic>{};
  }

  /// Criar pagamento em lote (múltiplas vinculações)
  Future<Map<String, dynamic>> createBulkPayment({
    required List<Map<String, dynamic>> payments,
    String? description,
  }) async {
    final response = await _client.client.post<Map<String, dynamic>>(
      '${ApiEndpoints.transactionLinks}bulk_payment/',
      data: {
        'payments': payments,
        if (description != null) 'description': description,
      },
    );
    return response.data ?? <String, dynamic>{};
  }

  /// Listar vinculações
  Future<List<TransactionLinkModel>> fetchTransactionLinks({
    String? linkType,
    String? dateFrom,
    String? dateTo,
  }) async {
    try {
      debugPrint('🔗 Buscando transaction links...');
      
      final queryParams = <String, dynamic>{};
      if (linkType != null) queryParams['link_type'] = linkType;
      if (dateFrom != null) queryParams['date_from'] = dateFrom;
      if (dateTo != null) queryParams['date_to'] = dateTo;
      
      final response = await _client.client.get<dynamic>(
        ApiEndpoints.transactionLinks,
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
      );
      
      debugPrint('✅ Resposta de links recebida - Status: ${response.statusCode}');
      debugPrint('📦 Tipo de response.data: ${response.data.runtimeType}');
      
      final items = _extractListFromResponse(response.data);
      debugPrint('🔗 ${items.length} links encontrados');
      
      return items
          .map((e) {
            if (e is! Map<String, dynamic>) {
              debugPrint('⚠️ Item de link não é Map<String, dynamic>: ${e.runtimeType}');
              throw Exception('Formato de link inválido');
            }
            return TransactionLinkModel.fromMap(e);
          })
          .toList();
    } catch (e, stackTrace) {
      debugPrint('🚨 Erro ao buscar transaction links: $e');
      debugPrint('Stack trace: $stackTrace');
      rethrow;
    }
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

  /// Marca o primeiro acesso como concluído no backend
  Future<void> completeFirstAccess() async {
    await _client.client.patch<Map<String, dynamic>>(
      ApiEndpoints.profile,
      data: {
        'complete_first_access': true,
      },
    );
  }

  // ======= Métodos de Leaderboard =======

  /// Busca o ranking geral de usuários
  Future<LeaderboardResponse> fetchLeaderboard({
    int page = 1,
    int pageSize = 50,
  }) async {
    final response = await _client.client.get<Map<String, dynamic>>(
      ApiEndpoints.leaderboard,
      queryParameters: {
        'page': page.toString(),
        'page_size': pageSize.toString(),
      },
    );
    return LeaderboardResponse.fromMap(response.data ?? <String, dynamic>{});
  }

  /// Busca o ranking de amigos
  Future<LeaderboardResponse> fetchFriendsLeaderboard() async {
    final response = await _client.client.get<Map<String, dynamic>>(
      '${ApiEndpoints.leaderboard}friends/',
    );
    return LeaderboardResponse.fromMap(response.data ?? <String, dynamic>{});
  }

  // ======= Métodos de Amizade =======

  /// Lista amigos aceitos
  Future<List<FriendshipModel>> fetchFriends() async {
    final response = await _client.client.get<dynamic>(
      ApiEndpoints.friendships,
    );
    final items = _extractListFromResponse(response.data);
    return items
        .map((e) => FriendshipModel.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  /// Lista solicitações pendentes recebidas
  Future<List<FriendshipModel>> fetchFriendRequests() async {
    final response = await _client.client.get<dynamic>(
      '${ApiEndpoints.friendships}requests/',
    );
    final items = _extractListFromResponse(response.data);
    return items
        .map((e) => FriendshipModel.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  /// Envia solicitação de amizade
  Future<FriendshipModel> sendFriendRequest({required int friendId}) async {
    final response = await _client.client.post<Map<String, dynamic>>(
      '${ApiEndpoints.friendships}send_request/',
      data: {'friend_id': friendId},
    );
    return FriendshipModel.fromMap(response.data ?? <String, dynamic>{});
  }

  /// Aceita solicitação de amizade
  Future<FriendshipModel> acceptFriendRequest({required String requestId}) async {
    final response = await _client.client.post<Map<String, dynamic>>(
      '${ApiEndpoints.friendships}$requestId/accept/',
    );
    return FriendshipModel.fromMap(response.data ?? <String, dynamic>{});
  }

  /// Rejeita solicitação de amizade
  Future<void> rejectFriendRequest({required String requestId}) async {
    await _client.client.post(
      '${ApiEndpoints.friendships}$requestId/reject/',
    );
  }

  /// Remove amizade por ID ou UUID
  Future<void> removeFriend({required String friendshipId}) async {
    await _client.client.delete(
      '${ApiEndpoints.friendships}$friendshipId/',
    );
  }

  /// Busca usuários por nome ou email
  Future<List<UserSearchModel>> searchUsers({required String query}) async {
    if (query.trim().length < 2) {
      return [];
    }

    final response = await _client.client.get<List<dynamic>>(
      '${ApiEndpoints.friendships}search_users/',
      queryParameters: {'q': query},
    );
    final items = response.data ?? <dynamic>[];
    return items
        .map((e) => UserSearchModel.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  Future<Map<String, dynamic>> completeSimplifiedOnboarding({
    required double monthlyIncome,
    required double essentialExpenses,
  }) async {
    final response = await _client.client.post<Map<String, dynamic>>(
      ApiEndpoints.simplifiedOnboarding,
      data: {
        'monthly_income': monthlyIncome,
        'essential_expenses': essentialExpenses,
      },
    );
    return response.data ?? {};
  }

  Future<Map<String, dynamic>> devResetAccount() async {
    final response = await _client.client.post<Map<String, dynamic>>(
      '${ApiEndpoints.user}dev_reset_account/',
    );
    return response.data ?? {};
  }

  Future<Map<String, dynamic>> devAddXp(int xp) async {
    final response = await _client.client.post<Map<String, dynamic>>(
      '${ApiEndpoints.user}dev_add_xp/',
      data: {'xp': xp},
    );
    return response.data ?? {};
  }

  Future<Map<String, dynamic>> devCompleteMissions() async {
    final response = await _client.client.post<Map<String, dynamic>>(
      '${ApiEndpoints.user}dev_complete_missions/',
    );
    return response.data ?? {};
  }

  Future<Map<String, dynamic>> devClearCache() async {
    final response = await _client.client.post<Map<String, dynamic>>(
      '${ApiEndpoints.user}dev_clear_cache/',
    );
    return response.data ?? {};
  }

  Future<Map<String, dynamic>> devAddTestData(int count) async {
    final response = await _client.client.post<Map<String, dynamic>>(
      '${ApiEndpoints.user}dev_add_test_data/',
      data: {'count': count},
    );
    return response.data ?? {};
  }
}

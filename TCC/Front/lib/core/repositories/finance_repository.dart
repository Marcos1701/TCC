import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';

import '../models/dashboard.dart';
import '../models/mission.dart';
import '../models/mission_progress.dart';
import '../models/category.dart';
import '../models/transaction.dart';
import '../models/transaction_link.dart';
import '../models/analytics.dart';
import '../network/api_client.dart';
import '../network/endpoints.dart';
import '../services/cache_service.dart';
import '../errors/failures.dart';
import '../utils/date_formatter.dart';
import '../services/cache_manager.dart';

class FinanceRepository {
  FinanceRepository({ApiClient? client}) : _client = client ?? ApiClient();

  final ApiClient _client;
  
  // Request deduplication - prevents duplicate concurrent requests
  final Map<String, Future<dynamic>> _pendingRequests = {};

  Failure _handleError(dynamic error) {
    if (error is DioException) {
      switch (error.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
        case DioExceptionType.connectionError:
          return const NetworkFailure('Check your internet connection');
        
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
                           'Invalid data';
            return ValidationFailure(message.toString(), errors: data);
          }
          
          if (data is Map<String, dynamic>) {
            final message = data['detail'] ?? data['error'] ?? 'Server error';
            return ServerFailure(message.toString(), statusCode: statusCode);
          }
          
          return ServerFailure(
            'Server error (${statusCode ?? "unknown"})',
            statusCode: statusCode,
          );
        
        default:
          return NetworkFailure(error.message ?? 'Connection error');
      }
    }
    
    return ServerFailure(error.toString());
  }

  List<dynamic> _extractListFromResponse(dynamic data) {
    if (data == null) {
      debugPrint('Warning: _extractListFromResponse: data is null');
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
        debugPrint('Error response detected: $data');
      }
      return [];
    }
    
    if (data is List<dynamic>) {
      return data;
    }
    
    return [];
  }

  /// Fetches dashboard data with request deduplication.
  /// If a dashboard request is already in-flight, returns the pending future.
  Future<DashboardData> fetchDashboard() async {
    const cacheKey = 'fetchDashboard';
    
    // Return existing request if already in-flight (deduplication)
    if (_pendingRequests.containsKey(cacheKey)) {
      return await _pendingRequests[cacheKey] as DashboardData;
    }
    
    final future = _doFetchDashboard();
    _pendingRequests[cacheKey] = future;
    
    try {
      return await future;
    } finally {
      _pendingRequests.remove(cacheKey);
    }
  }
  
  Future<DashboardData> _doFetchDashboard() async {
    try {
      final cached = CacheService.getCachedDashboard(
        invalidatedAfter: CacheManager().lastInvalidation,
      );
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

  Future<AnalyticsData> fetchAnalytics() async {
    try {
      final response = await _client.client.get<Map<String, dynamic>>(
        ApiEndpoints.dashboardAnalytics,
      );
      final data = response.data ?? <String, dynamic>{};
      return AnalyticsData.fromJson(data);
    } catch (e) {
      if (e is Failure) rethrow;
      throw _handleError(e);
    }
  }

  Future<List<CategoryModel>> fetchCategories({String? type}) async {
    try {
      if (type == null) {
        final cached = CacheService.getCachedCategories(
          invalidatedAfter: CacheManager().lastInvalidation,
        );
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

  Future<List<TransactionModel>> fetchTransactions({
    String? type,
    int? limit,
    int? offset,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      if (type != null) queryParams['type'] = type;
      if (limit != null) queryParams['limit'] = limit;
      if (offset != null) queryParams['offset'] = offset;
      
      final response = await _client.client.get<dynamic>(
        ApiEndpoints.transactions,
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
      );
      
      final items = _extractListFromResponse(response.data);
      
      return items
          .map((e) {
            if (e is! Map<String, dynamic>) {
              throw const ParseFailure('Invalid transaction format');
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
    try {
      await _client.client.delete('${ApiEndpoints.transactions}$id/');
      await CacheService.invalidateDashboard();
      await CacheService.invalidateMissions();
    } catch (e) {
      throw _handleError(e);
    }
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
    
    await CacheService.invalidateDashboard();
    await CacheService.invalidateMissions();
    
    return TransactionModel.fromMap(response.data ?? <String, dynamic>{});
  }

  Future<MissionProgressModel> startMission(int missionId) async {
    final response = await _client.client.post<Map<String, dynamic>>(
      ApiEndpoints.missionProgress,
      data: {'mission_id': missionId},
    );
    return MissionProgressModel.fromMap(response.data ?? <String, dynamic>{});
  }

  Future<MissionProgressModel> startMissionAction(int missionId) async {
    final response = await _client.client.post<Map<String, dynamic>>(
      '${ApiEndpoints.missions}$missionId/start/',
    );
    return MissionProgressModel.fromMap(response.data ?? <String, dynamic>{});
  }

  Future<MissionProgressModel> skipMissionAction(int missionId) async {
    final response = await _client.client.post<Map<String, dynamic>>(
      '${ApiEndpoints.missions}$missionId/skip/',
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
    final cached = CacheService.getCachedMissions(
      invalidatedAfter: CacheManager().lastInvalidation,
    );
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
        '⚠️ API returned ${invalidMissions.length} mission(s) with placeholders:\n'
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
      if (e.response?.statusCode == 404) {
        debugPrint('⚠️ Context analysis not available (404)');
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

  Future<Map<String, dynamic>> fetchMissionProgressDetails(int id) async {
    final response = await _client.client.get<Map<String, dynamic>>(
        '${ApiEndpoints.missionProgress}$id/details/');
    return response.data ?? <String, dynamic>{};
  }


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

  Future<TransactionLinkModel> createTransactionLink(
      CreateTransactionLinkRequest request) async {
    final response = await _client.client.post<Map<String, dynamic>>(
      '${ApiEndpoints.transactionLinks}quick_link/',
      data: request.toMap(),
    );
    
    return TransactionLinkModel.fromMap(response.data ?? <String, dynamic>{});
  }

  Future<void> deleteTransactionLink(String linkId) async {
    await _client.client.delete('${ApiEndpoints.transactionLinks}$linkId/');
  }

  Future<Map<String, dynamic>> fetchPendingSummary({
    String sortBy = 'urgency',
  }) async {
    final response = await _client.client.get<Map<String, dynamic>>(
      '${ApiEndpoints.transactionLinks}pending_summary/',
      queryParameters: {'sort_by': sortBy},
    );
    return response.data ?? <String, dynamic>{};
  }

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

  Future<List<TransactionLinkModel>> fetchTransactionLinks({
    String? linkType,
    String? dateFrom,
    String? dateTo,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      if (linkType != null) queryParams['link_type'] = linkType;
      if (dateFrom != null) queryParams['date_from'] = dateFrom;
      if (dateTo != null) queryParams['date_to'] = dateTo;
      
      final response = await _client.client.get<dynamic>(
        ApiEndpoints.transactionLinks,
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
      );
      
      final items = _extractListFromResponse(response.data);
      
      return items
          .map((e) {
            if (e is! Map<String, dynamic>) {
              throw Exception('Invalid link format');
            }
            return TransactionLinkModel.fromMap(e);
          })
          .toList();
    } catch (e) {
      debugPrint('🚨 Error fetching transaction links: $e');
      rethrow;
    }
  }

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

  Future<void> completeFirstAccess() async {
    await _client.client.patch<Map<String, dynamic>>(
      ApiEndpoints.profile,
      data: {
        'complete_first_access': true,
      },
    );
  }

  Future<Map<String, dynamic>> updateFinancialTargets({
    required int targetTps,
    required int targetRdr,
    required double targetIli,
  }) async {
    final response = await _client.client.patch<Map<String, dynamic>>(
      ApiEndpoints.profile,
      data: {
        'target_tps': targetTps,
        'target_rdr': targetRdr,
        'target_ili': targetIli,
      },
    );
    return response.data ?? {};
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

class MonthlySummary {
  final String month;
  
  final double total;
  
  final List<CategoryTotal> byCategory;
  
  const MonthlySummary({
    required this.month,
    required this.total,
    required this.byCategory,
  });
  
  factory MonthlySummary.fromMap(Map<String, dynamic> map) {
    return MonthlySummary(
      month: map['month'] as String? ?? '',
      total: (map['total'] as num?)?.toDouble() ?? 0.0,
      byCategory: (map['by_category'] as List?)
          ?.map((e) => CategoryTotal.fromMap(e as Map<String, dynamic>))
          .toList() ?? [],
    );
  }
  
  static MonthlySummary empty() {
    return const MonthlySummary(month: '', total: 0, byCategory: []);
  }
}

class CategoryTotal {
  final String id;
  final String name;
  final double total;
  
  const CategoryTotal({
    required this.id,
    required this.name,
    required this.total,
  });
  
  factory CategoryTotal.fromMap(Map<String, dynamic> map) {
    return CategoryTotal(
      id: map['id'] as String? ?? '',
      name: map['name'] as String? ?? '',
      total: (map['total'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

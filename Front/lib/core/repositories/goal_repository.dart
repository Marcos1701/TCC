import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../database/app_database.dart';
import '../models/goal.dart';
import '../models/transaction.dart';
import '../network/api_client.dart';
import '../network/endpoints.dart';
import '../services/cache_manager.dart';
import '../utils/date_formatter.dart';
import 'base_repository.dart';

import 'interfaces/i_goal_repository.dart';

/// Repository for goal-related operations.
///
/// Handles CRUD operations for financial goals, transactions
/// associated with goals, progress tracking and insights.
class GoalRepository extends BaseRepository implements IGoalRepository {
  /// Creates a [GoalRepository] instance.
  ///
  /// Optionally accepts an [ApiClient] for dependency injection.
  GoalRepository({super.client, AppDatabase? db}) 
      : _db = db ?? AppDatabase();

  final AppDatabase _db;
  
  /// Flag to track if DB operations should be attempted
  /// Disabled on web (kIsWeb) since sql.js is not configured
  static bool get _dbAvailable => !kIsWeb;

  // ===========================================================================
  // GOAL CRUD OPERATIONS
  // ===========================================================================

  /// Fetches all goals for the current user.
  @override
  Future<List<GoalModel>> fetchGoals() async {
    try {
      if (kDebugMode) {
        debugPrint('📡 GoalRepository: Fetching goals from API...');
      }
      
      final response = await client.client.get<dynamic>(ApiEndpoints.goals);
      final items = extractListFromResponse(response.data);
      final goals = items
          .map((e) => GoalModel.fromMap(e as Map<String, dynamic>))
          .toList();
      
      if (kDebugMode) {
        debugPrint('✅ GoalRepository: ${goals.length} goals loaded');
      }
      
      // Save to DB (non-blocking, only if available)
      if (_dbAvailable) {
        _saveGoalsToDb(goals).catchError((e) {
          if (kDebugMode) debugPrint('⚠️ GoalRepository: DB save error (ignored): $e');
        });
      }
      
      return goals;
    } catch (e, stackTrace) {
      if (kDebugMode) {
        debugPrint('❌ GoalRepository: Error fetching goals: $e');
        debugPrint('Stack trace: $stackTrace');
      }
      
      if (_dbAvailable && e is DioException && 
          (e.type == DioExceptionType.connectionTimeout || 
           e.type == DioExceptionType.connectionError)) {
        final dbGoals = await _db.goalsDao.getAllGoals();
        return dbGoals.map(_mapToModel).toList();
      }
      rethrow;
    }
  }

  /// Creates a new goal.
  @override
  Future<GoalModel> createGoal({
    required String title,
    required double targetAmount,
    String description = '',
    double currentAmount = 0,
    double initialAmount = 0,
    DateTime? deadline,
    String goalType = 'CUSTOM',
    String? targetCategory,  // Compatibilidade retroativa
    List<String>? targetCategories,  // Nova: múltiplas categorias
    double? baselineAmount,
    int trackingPeriodMonths = 3,
  }) async {
    // Combina categorias: prioriza lista, fallback para única
    final categories = targetCategories ?? (targetCategory != null ? [targetCategory] : null);
    
    final payload = {
      'title': title,
      'description': description,
      'target_amount': targetAmount,
      'current_amount': currentAmount,
      'initial_amount': initialAmount,
      if (deadline != null) 'deadline': DateFormatter.toApiFormat(deadline),
      'goal_type': goalType,
      if (categories != null && categories.isNotEmpty) 'target_categories': categories,
      if (baselineAmount != null) 'baseline_amount': baselineAmount,
      'tracking_period_months': trackingPeriodMonths,
    };

    if (kDebugMode) {
      debugPrint('🎯 [GoalRepository.createGoal] Payload: $payload');
    }

    try {
      final response = await client.client.post<Map<String, dynamic>>(
        ApiEndpoints.goals,
        data: payload,
      );
      
      // Invalida cache após criar meta
      CacheManager().invalidateAfterGoalUpdate();
      
      final data = response.data ?? <String, dynamic>{};
      final goal = GoalModel.fromMap(data);
      
      // Save to local DB if available (non-blocking)
      if (_dbAvailable) {
        _db.goalsDao.insertGoal(_mapToCompanion(goal)).catchError((e) {
          if (kDebugMode) debugPrint('⚠️ GoalRepository: DB insert error (ignored): $e');
          return 0;
        });
      }
      
      return goal;
    } catch (e) {
      if (_dbAvailable && e is DioException && 
          (e.type == DioExceptionType.connectionTimeout || 
           e.type == DioExceptionType.connectionError)) {
        // Offline creation
        final id = const Uuid().v4();
        final goal = GoalModel(
          id: id,
          title: title,
          description: description,
          targetAmount: targetAmount,
          currentAmount: currentAmount,
          initialAmount: initialAmount,
          deadline: deadline,
          goalType: _parseGoalType(goalType),
          progressPercentage: targetAmount > 0 ? (currentAmount / targetAmount) * 100 : 0,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        
        await _db.goalsDao.insertGoal(
          _mapToCompanion(goal).copyWith(isSynced: const Value(false))
        );
        
        return goal;
      }
      rethrow;
    }
  }

  /// Updates a goal.
  @override
  Future<GoalModel> updateGoal({
    required String goalId,
    String? title,
    String? description,
    double? targetAmount,
    double? currentAmount,
    double? initialAmount,
    DateTime? deadline,
    String? goalType,
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

    try {
      final response = await client.client.patch<Map<String, dynamic>>(
        '${ApiEndpoints.goals}$goalId/',
        data: payload,
      );
      final data = response.data ?? <String, dynamic>{};
      final goal = GoalModel.fromMap(data);
      
      // Update local DB if available (non-blocking)
      if (_dbAvailable) {
        _db.goalsDao.updateGoal(_mapToCompanion(goal)).catchError((e) {
          if (kDebugMode) debugPrint('⚠️ GoalRepository: DB update error (ignored): $e');
          return false;
        });
      }
      
      return goal;
    } catch (e) {
      if (_dbAvailable && e is DioException && 
          (e.type == DioExceptionType.connectionTimeout || 
           e.type == DioExceptionType.connectionError)) {
        // Offline update
        final current = await _db.goalsDao.getGoalById(goalId);
        if (current != null) {
          final updated = current.copyWith(
            title: title ?? current.title,
            description: description ?? current.description,
            targetAmount: targetAmount ?? current.targetAmount,
            currentAmount: currentAmount ?? current.currentAmount,
            initialAmount: initialAmount ?? current.initialAmount,
            deadline: Value(deadline ?? current.deadline),
            goalType: goalType ?? current.goalType,
            isSynced: false,
          );
          
          await _db.goalsDao.updateGoal(
            GoalsCompanion(
              id: Value(updated.id),
              title: Value(updated.title),
              description: Value(updated.description),
              targetAmount: Value(updated.targetAmount),
              currentAmount: Value(updated.currentAmount),
              initialAmount: Value(updated.initialAmount),
              deadline: Value<DateTime?>(updated.deadline),
              goalType: Value(updated.goalType),
              progressPercentage: Value(updated.targetAmount > 0 ? (updated.currentAmount / updated.targetAmount) * 100 : 0),
              isSynced: const Value(false),
            )
          );
          return _mapToModel(updated);
        }
      }
      rethrow;
    }
  }

  /// Deletes a goal.
  @override
  Future<void> deleteGoal(String id) async {
    try {
      await client.client.delete('${ApiEndpoints.goals}$id/');
      
      // Delete from local DB if available (non-blocking)
      if (_dbAvailable) {
        _db.goalsDao.deleteGoal(id).catchError((e) {
          if (kDebugMode) debugPrint('⚠️ GoalRepository: DB delete error (ignored): $e');
          return 0;
        });
      }
    } catch (e) {
      if (_dbAvailable && e is DioException && 
          (e.type == DioExceptionType.connectionTimeout || 
           e.type == DioExceptionType.connectionError)) {
        // Offline deletion (soft delete)
        await (_db.update(_db.goals)..where((g) => g.id.equals(id)))
            .write(const GoalsCompanion(
              isDeleted: Value(true),
              isSynced: Value(false),
            ));
        return;
      }
      rethrow;
    }
  }

  // ===========================================================================
  // GOAL TRANSACTIONS
  // ===========================================================================

  /// Fetches transactions related to a specific goal.
  @override
  Future<List<TransactionModel>> fetchGoalTransactions(String goalId) async {
    final response = await client.client
        .get<dynamic>('${ApiEndpoints.goals}$goalId/transactions/');

    final items = extractListFromResponse(response.data);
    return items
        .map((e) => TransactionModel.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  // ===========================================================================
  // GOAL PROGRESS & INSIGHTS
  // ===========================================================================

  /// Manually refreshes goal progress calculation.
  @override
  Future<GoalModel> refreshGoalProgress(String goalId) async {
    final response = await client.client
        .post<Map<String, dynamic>>('${ApiEndpoints.goals}$goalId/refresh/');
    return GoalModel.fromMap(response.data ?? <String, dynamic>{});
  }

  /// Fetches insights and analytics for a specific goal.
  @override
  Future<Map<String, dynamic>> fetchGoalInsights(String goalId) async {
    final response = await client.client
        .get<Map<String, dynamic>>('${ApiEndpoints.goals}$goalId/insights/');
    return response.data ?? <String, dynamic>{};
  }

  Future<void> _saveGoalsToDb(List<GoalModel> goals) async {
    if (!_dbAvailable) return;
    for (final g in goals) {
      await _db.goalsDao.insertGoal(_mapToCompanion(g));
    }
  }

  GoalModel _mapToModel(Goal g) {
    return GoalModel(
      id: g.id,
      title: g.title,
      description: g.description,
      targetAmount: g.targetAmount,
      currentAmount: g.currentAmount,
      initialAmount: g.initialAmount,
      deadline: g.deadline,
      goalType: _parseGoalType(g.goalType),
      progressPercentage: g.progressPercentage,
      createdAt: g.createdAt,
      updatedAt: g.updatedAt,
      targetCategory: g.targetCategory,
      targetCategoryName: g.targetCategoryName,
      baselineAmount: g.baselineAmount,
      trackingPeriodMonths: g.trackingPeriodMonths,
    );
  }

  GoalsCompanion _mapToCompanion(GoalModel g) {
    return GoalsCompanion.insert(
      id: g.id,
      title: g.title,
      description: g.description,
      targetAmount: g.targetAmount,
      currentAmount: g.currentAmount,
      initialAmount: Value(g.initialAmount),
      deadline: Value<DateTime?>(g.deadline),
      goalType: g.goalType.value,
      progressPercentage: g.progressPercentage,
      createdAt: g.createdAt,
      updatedAt: g.updatedAt,
      targetCategory: Value<String?>(g.targetCategory),
      targetCategoryName: Value<String?>(g.targetCategoryName),
      baselineAmount: Value<double?>(g.baselineAmount),
      trackingPeriodMonths: Value(g.trackingPeriodMonths),
      isSynced: const Value(true),
    );
  }

  GoalType _parseGoalType(String? value) {
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
}

import '../models/goal.dart';
import '../models/transaction.dart';
import '../network/api_client.dart';
import '../network/endpoints.dart';
import '../utils/date_formatter.dart';
import 'base_repository.dart';

/// Repository for goal-related operations.
///
/// Handles CRUD operations for financial goals, transactions
/// associated with goals, progress tracking and insights.
class GoalRepository extends BaseRepository {
  /// Creates a [GoalRepository] instance.
  ///
  /// Optionally accepts an [ApiClient] for dependency injection.
  GoalRepository({super.client});

  // ===========================================================================
  // GOAL CRUD OPERATIONS
  // ===========================================================================

  /// Fetches all goals for the current user.
  Future<List<GoalModel>> fetchGoals() async {
    final response = await client.client.get<dynamic>(ApiEndpoints.goals);
    final items = extractListFromResponse(response.data);
    return items
        .map((e) => GoalModel.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  /// Creates a new goal.
  ///
  /// Parameters:
  /// - [title]: Required goal title
  /// - [targetAmount]: Required target amount to reach
  /// - [description]: Optional description
  /// - [currentAmount]: Initial current amount (default 0)
  /// - [initialAmount]: Initial amount when goal was created (default 0)
  /// - [deadline]: Optional deadline date
  /// - [goalType]: Type of goal (default 'CUSTOM')
  /// - [targetCategoryId]: Optional category to target
  /// - [trackedCategoryIds]: Optional list of categories to track
  /// - [autoUpdate]: Whether to auto-update progress (default false)
  /// - [trackingPeriod]: Tracking period (default 'TOTAL')
  /// - [isReductionGoal]: Whether this is a reduction goal (default false)
  Future<GoalModel> createGoal({
    required String title,
    required double targetAmount,
    String description = '',
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
      if (deadline != null) 'deadline': DateFormatter.toApiFormat(deadline),
      'goal_type': goalType,
      if (targetCategoryId != null) 'target_category': targetCategoryId,
      if (trackedCategoryIds != null && trackedCategoryIds.isNotEmpty)
        'tracked_category_ids': trackedCategoryIds,
      'auto_update': autoUpdate,
      'tracking_period': trackingPeriod,
      'is_reduction_goal': isReductionGoal,
    };

    final response = await client.client.post<Map<String, dynamic>>(
      ApiEndpoints.goals,
      data: payload,
    );
    return GoalModel.fromMap(response.data ?? <String, dynamic>{});
  }

  /// Updates an existing goal.
  ///
  /// [goalId] can be the numeric ID or UUID string.
  /// Only non-null parameters will be updated.
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

    final response = await client.client.patch<Map<String, dynamic>>(
      '${ApiEndpoints.goals}$goalId/',
      data: payload,
    );
    return GoalModel.fromMap(response.data ?? <String, dynamic>{});
  }

  /// Deletes a goal by ID or UUID.
  Future<void> deleteGoal(String id) async {
    await client.client.delete('${ApiEndpoints.goals}$id/');
  }

  // ===========================================================================
  // GOAL TRANSACTIONS
  // ===========================================================================

  /// Fetches transactions related to a specific goal.
  ///
  /// [goalId] can be the numeric ID or UUID string.
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
  ///
  /// [goalId] can be the numeric ID or UUID string.
  Future<GoalModel> refreshGoalProgress(String goalId) async {
    final response = await client.client
        .post<Map<String, dynamic>>('${ApiEndpoints.goals}$goalId/refresh/');
    return GoalModel.fromMap(response.data ?? <String, dynamic>{});
  }

  /// Fetches insights and analytics for a specific goal.
  ///
  /// [goalId] can be the numeric ID or UUID string.
  /// Returns a map containing insights data like projected completion date,
  /// average progress rate, etc.
  Future<Map<String, dynamic>> fetchGoalInsights(String goalId) async {
    final response = await client.client
        .get<Map<String, dynamic>>('${ApiEndpoints.goals}$goalId/insights/');
    return response.data ?? <String, dynamic>{};
  }
}

import 'package:flutter/foundation.dart';

import '../../../core/models/goal.dart';
import '../../../core/repositories/finance_repository.dart'; // Keep for backward compatibility
import '../../../core/repositories/goal_repository.dart';
import '../../../core/repositories/interfaces/i_goal_repository.dart';

/// Estados do ViewModel
enum GoalsViewState {
  initial,
  loading,
  success,
  error,
}

/// ViewModel para gerenciar metas com atualização otimista
class GoalsViewModel extends ChangeNotifier {
  GoalsViewModel({IGoalRepository? repository})
      : _repository = repository ?? GoalRepository();

  final IGoalRepository _repository;

  // Estado
  GoalsViewState _state = GoalsViewState.initial;
  List<GoalModel> _goals = [];
  String? _errorMessage;

  // Getters
  GoalsViewState get state => _state;
  List<GoalModel> get goals => _goals;
  List<GoalModel> get activeGoals => _goals.where((g) => g.progressPercentage < 100).toList();
  List<GoalModel> get completedGoals => _goals.where((g) => g.progressPercentage >= 100).toList();
  String? get errorMessage => _errorMessage;
  bool get isLoading => _state == GoalsViewState.loading;
  bool get hasError => _state == GoalsViewState.error;
  bool get isEmpty => _goals.isEmpty && !isLoading;

  /// Carrega metas do repositório
  Future<void> loadGoals() async {
    _state = GoalsViewState.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      _goals = await _repository.fetchGoals();
      _state = GoalsViewState.success;
      _errorMessage = null;
    } catch (e) {
      _state = GoalsViewState.error;
      _errorMessage = 'Erro ao carregar metas: ${e.toString()}';
      if (kDebugMode) {
        debugPrint('Erro ao carregar metas: $e');
      }
    } finally {
      notifyListeners();
    }
  }

  /// Atualiza metas silenciosamente (sem loading)
  Future<void> refreshSilently() async {
    try {
      _goals = await _repository.fetchGoals();
      notifyListeners();
    } catch (e) {
      // Ignora erros em refresh silencioso
    }
  }

  /// Atualiza progresso de meta otimisticamente (apenas visual)
  /// O backend calcula o progresso real baseado nas transações
  void updateGoalProgressOptimistic(String goalId, double newAmount) {
    final index = _goals.indexWhere((g) => g.id == goalId);
    if (index == -1) return;

    final goal = _goals[index];
    
    // Prevenir divisão por zero
    final percentage = goal.targetAmount > 0 
        ? (newAmount / goal.targetAmount * 100).clamp(0.0, 100.0)
        : 0.0;

    final updated = GoalModel(
      id: goal.id,
      title: goal.title,
      description: goal.description,
      targetAmount: goal.targetAmount,
      currentAmount: newAmount,
      initialAmount: goal.initialAmount,
      deadline: goal.deadline,
      goalType: goal.goalType,
      progressPercentage: percentage,
      createdAt: goal.createdAt,
      updatedAt: DateTime.now(),
    );

    _goals[index] = updated;
    notifyListeners();
  }

  /// Cria uma nova meta
  Future<GoalModel?> createGoal({
    required String title,
    required double targetAmount,
    String description = '',
    double initialAmount = 0,
    DateTime? deadline,
    String goalType = 'CUSTOM',
    String? targetCategory,
    double? baselineAmount,
    int trackingPeriodMonths = 3,
  }) async {
    try {
      final goalData = {
        'title': title,
        'description': description,
        'target_amount': targetAmount,
        'initial_amount': initialAmount,
        if (deadline != null) 'deadline': deadline.toIso8601String().split('T')[0],
        'goal_type': goalType,
        if (targetCategory != null) 'target_category': targetCategory,
        if (baselineAmount != null) 'baseline_amount': baselineAmount,
        'tracking_period_months': trackingPeriodMonths,
      };

      final response = await _repository.createGoal(
        title: title,
        targetAmount: targetAmount,
        description: description,
        initialAmount: initialAmount,
        deadline: deadline,
        goalType: goalType,
      );

      final newGoal = response;
      _goals.insert(0, newGoal);
      notifyListeners();
      return newGoal;
    } catch (e) {
      _errorMessage = 'Erro ao criar meta: ${e.toString()}';
      _state = GoalsViewState.error;
      notifyListeners();
      if (kDebugMode) {
        debugPrint('Erro ao criar meta: $e');
      }
      return null;
    }
  }

  /// Atualiza uma meta existente
  Future<GoalModel?> updateGoal({
    required String goalId,
    String? title,
    String? description,
    double? targetAmount,
    double? currentAmount,
    double? initialAmount,
    DateTime? deadline,
    String? goalType,
    String? targetCategory,
    double? baselineAmount,
  }) async {
    final index = _goals.indexWhere((g) => g.id == goalId);
    if (index == -1) return null;

    final oldGoal = _goals[index];
    
    try {
      final response = await _repository.updateGoal(
        goalId: goalId,
        title: title,
        description: description,
        targetAmount: targetAmount,
        currentAmount: currentAmount,
        initialAmount: initialAmount,
        deadline: deadline,
        goalType: goalType,
      );

      final updatedGoal = response;
      _goals[index] = updatedGoal;
      notifyListeners();
      return updatedGoal;
    } catch (e) {
      _errorMessage = 'Erro ao atualizar meta: ${e.toString()}';
      _state = GoalsViewState.error;
      notifyListeners();
      if (kDebugMode) {
        debugPrint('Erro ao atualizar meta: $e');
      }
      return null;
    }
  }

  /// Deleta uma meta com atualização otimista
  Future<bool> deleteGoal(String goalId) async {
    final index = _goals.indexWhere((g) => g.id == goalId);
    if (index == -1) return false;

    // Remove otimisticamente
    final removed = _goals.removeAt(index);
    notifyListeners();

    try {
      await _repository.deleteGoal(goalId);
      return true;
    } catch (e) {
      // Rollback em caso de erro
      _goals.insert(index, removed);
      _errorMessage = 'Erro ao deletar meta: ${e.toString()}';
      _state = GoalsViewState.error;
      notifyListeners();
      if (kDebugMode) {
        debugPrint('Erro ao deletar meta: $e');
      }
      return false;
    }
  }

  /// Limpa erro
  void clearError() {
    _errorMessage = null;
    if (_state == GoalsViewState.error) {
      _state = GoalsViewState.initial;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _goals.clear();
    super.dispose();
  }
}


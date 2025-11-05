import 'package:flutter/foundation.dart';

import '../../../core/models/goal.dart';
import '../../../core/repositories/finance_repository.dart';

/// Estados do ViewModel
enum GoalsViewState {
  initial,
  loading,
  success,
  error,
}

/// ViewModel para gerenciar metas com atualização otimista
class GoalsViewModel extends ChangeNotifier {
  GoalsViewModel({FinanceRepository? repository})
      : _repository = repository ?? FinanceRepository();

  final FinanceRepository _repository;

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
      debugPrint('Erro ao carregar metas: $e');
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
      debugPrint('Erro ao atualizar metas silenciosamente: $e');
    }
  }

  /// Atualiza progresso de meta otimisticamente (apenas visual)
  /// O backend calcula o progresso real baseado nas transações
  void updateGoalProgressOptimistic(int goalId, double newAmount) {
    final index = _goals.indexWhere((g) => g.id == goalId);
    if (index == -1) return;

    final goal = _goals[index];
    final percentage = (newAmount / goal.targetAmount * 100).clamp(0.0, 100.0);

    final updated = GoalModel(
      id: goal.id,
      title: goal.title,
      description: goal.description,
      targetAmount: goal.targetAmount,
      currentAmount: newAmount,
      initialAmount: goal.initialAmount,
      deadline: goal.deadline,
      goalType: goal.goalType,
      targetCategory: goal.targetCategory,
      categoryName: goal.categoryName,
      trackedCategories: goal.trackedCategories,
      autoUpdate: goal.autoUpdate,
      trackingPeriod: goal.trackingPeriod,
      isReductionGoal: goal.isReductionGoal,
      progressPercentage: percentage,
      createdAt: goal.createdAt,
      updatedAt: DateTime.now(),
    );

    _goals[index] = updated;
    notifyListeners();
  }

  /// Limpa erro
  void clearError() {
    _errorMessage = null;
    if (_state == GoalsViewState.error) {
      _state = GoalsViewState.initial;
    }
    notifyListeners();
  }
}

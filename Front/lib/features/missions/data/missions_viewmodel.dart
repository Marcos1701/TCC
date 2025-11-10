import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../../core/models/mission_progress.dart';
import '../../../core/repositories/finance_repository.dart';

/// Estados do ViewModel
enum MissionsViewState {
  initial,
  loading,
  success,
  error,
}

/// ViewModel para gerenciar missões e celebrações
class MissionsViewModel extends ChangeNotifier {
  MissionsViewModel({FinanceRepository? repository})
      : _repository = repository ?? FinanceRepository();

  final FinanceRepository _repository;

  // Estado
  MissionsViewState _state = MissionsViewState.initial;
  List<MissionProgressModel> _activeMissions = [];
  String? _errorMessage;

  // Missões recém completadas (para celebração)
  final Set<int> _newlyCompleted = {};

  // Getters
  MissionsViewState get state => _state;
  List<MissionProgressModel> get activeMissions => _activeMissions;
  List<MissionProgressModel> get completedMissions {
    // Filtra missões completadas da lista ativa
    return _activeMissions.where((m) => m.status == 'COMPLETED').toList();
  }
  String? get errorMessage => _errorMessage;
  bool get isLoading => _state == MissionsViewState.loading;
  bool get hasError => _state == MissionsViewState.error;
  bool get isEmpty => _activeMissions.isEmpty && !isLoading;
  Set<int> get newlyCompleted => _newlyCompleted;

  /// Carrega missões do dashboard
  Future<void> loadMissions() async {
    _state = MissionsViewState.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final dashboard = await _repository.fetchDashboard();
      _updateMissions(dashboard.activeMissions);
      _state = MissionsViewState.success;
      _errorMessage = null;
    } on DioException catch (e) {
      _state = MissionsViewState.error;
      
      // Mensagens de erro mais amigáveis
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        _errorMessage = 'Tempo de conexão esgotado. Verifique sua internet.';
      } else if (e.type == DioExceptionType.connectionError) {
        _errorMessage = 'Sem conexão com o servidor. Verifique sua internet.';
      } else if (e.response?.statusCode == 500) {
        _errorMessage = 'Erro no servidor. Tente novamente em alguns instantes.';
      } else if (e.response?.statusCode == 401) {
        _errorMessage = 'Sessão expirada. Faça login novamente.';
      } else {
        _errorMessage = 'Erro ao carregar missões. Tente novamente.';
      }
      
      debugPrint('Erro ao carregar missões: ${e.toString()}');
    } catch (e) {
      _state = MissionsViewState.error;
      _errorMessage = 'Erro inesperado ao carregar missões.';
      debugPrint('Erro ao carregar missões: $e');
    } finally {
      notifyListeners();
    }
  }

  /// Atualiza missões verificando se há novas completadas
  void _updateMissions(List<MissionProgressModel> missions) {
    // Identifica missões recém completadas
    final previousCompleted = _activeMissions
        .where((m) => m.status == 'COMPLETED')
        .map((m) => m.mission.id)
        .toSet();
    
    final newCompleted = missions
        .where((m) => m.status == 'COMPLETED')
        .map((m) => m.mission.id)
        .toSet();
    
    _newlyCompleted.clear();
    for (final id in newCompleted) {
      if (!previousCompleted.contains(id)) {
        _newlyCompleted.add(id);
      }
    }

    _activeMissions = missions;
  }

  /// Atualiza missões silenciosamente (sem loading)
  Future<void> refreshSilently() async {
    try {
      final dashboard = await _repository.fetchDashboard();
      _updateMissions(dashboard.activeMissions);
      notifyListeners();
    } catch (e) {
      debugPrint('Erro ao atualizar missões silenciosamente: $e');
    }
  }

  /// Marca missão como visualizada (remove de newlyCompleted)
  void markMissionAsViewed(int missionId) {
    _newlyCompleted.remove(missionId);
    notifyListeners();
  }

  /// Limpa todas as celebrações pendentes
  void clearCelebrations() {
    _newlyCompleted.clear();
    notifyListeners();
  }

  /// Atualiza progresso de missão otimisticamente (apenas visual)
  /// O cálculo real é feito pelo backend
  void updateMissionProgressOptimistic(int missionId, double newProgress) {
    final index = _activeMissions.indexWhere((m) => m.mission.id == missionId);
    if (index == -1) return;

    final mission = _activeMissions[index];
    
    // Cria novo objeto com progresso atualizado
    final updated = MissionProgressModel(
      id: mission.id,
      status: newProgress >= 100 ? 'COMPLETED' : mission.status,
      progress: newProgress,
      initialTps: mission.initialTps,
      initialRdr: mission.initialRdr,
      initialIli: mission.initialIli,
      initialTransactionCount: mission.initialTransactionCount,
      startedAt: mission.startedAt,
      completedAt: newProgress >= 100 ? DateTime.now() : mission.completedAt,
      updatedAt: DateTime.now(),
      mission: mission.mission,
    );

    _activeMissions[index] = updated;
    
    // Se completou (>= 100%), adiciona aos recém completados
    if (newProgress >= 100) {
      _newlyCompleted.add(missionId);
    }
    
    notifyListeners();
  }

  /// Limpa erro
  void clearError() {
    _errorMessage = null;
    if (_state == MissionsViewState.error) {
      _state = MissionsViewState.initial;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _newlyCompleted.clear();
    super.dispose();
  }
}

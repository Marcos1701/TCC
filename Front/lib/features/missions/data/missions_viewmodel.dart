import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../../core/models/mission.dart';
import '../../../core/models/mission_progress.dart';
import '../../../core/repositories/finance_repository.dart';
import '../../../core/constants/user_friendly_strings.dart';

enum MissionsViewState {
  initial,
  loading,
  success,
  error,
}

class MissionsViewModel extends ChangeNotifier {
  MissionsViewModel({FinanceRepository? repository})
      : _repository = repository ?? FinanceRepository();

  final FinanceRepository _repository;

  MissionsViewState _state = MissionsViewState.initial;
  List<MissionProgressModel> _activeMissions = [];
  String? _errorMessage;
  List<MissionModel> _recommendedMissions = [];
  final Map<int, List<MissionModel>> _missionsByCategory = {};
  Map<String, dynamic>? _contextAnalysis;
  bool _catalogLoading = false;
  String? _catalogError;
  bool _contextLoading = false;
  String? _contextError;

  final Set<int> _newlyCompleted = {};

  MissionsViewState get state => _state;
  List<MissionProgressModel> get activeMissions => _activeMissions;
  List<MissionProgressModel> get completedMissions {
    return _activeMissions.where((m) => m.status == 'COMPLETED').toList();
  }

  String? get errorMessage => _errorMessage;
  bool get isLoading => _state == MissionsViewState.loading;
  bool get hasError => _state == MissionsViewState.error;
  bool get isEmpty => _activeMissions.isEmpty && !isLoading;
  Set<int> get newlyCompleted => _newlyCompleted;
  List<MissionModel> get recommendedMissions => _recommendedMissions;
  List<MissionModel> missionsForCategory(int categoryId) =>
      _missionsByCategory[categoryId] ?? const [];
  Map<String, dynamic>? get missionContextAnalysis => _contextAnalysis;
  bool get isCatalogLoading => _catalogLoading;
  String? get catalogError => _catalogError;
  bool get isContextLoading => _contextLoading;
  String? get contextError => _contextError;
  List<CategoryMissionSummary> get categorySummaries =>
      _buildCategorySummaries();
  
  Map<String, dynamic> get missionQualityStats {
    final allMissions = [
      ..._activeMissions.map((m) => m.mission),
      ..._recommendedMissions,
      ..._missionsByCategory.values.expand((list) => list),
    ];
    
    final uniqueMissions = {for (var m in allMissions) m.id: m}.values;
    final invalidCount = uniqueMissions.where((m) => !m.isValid).length;
    
    return {
      'total': uniqueMissions.length,
      'valid': uniqueMissions.length - invalidCount,
      'invalid': invalidCount,
      'quality_rate': uniqueMissions.isEmpty 
        ? 100.0 
        : ((uniqueMissions.length - invalidCount) / uniqueMissions.length * 100).toStringAsFixed(1),
    };
  }

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

      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        _errorMessage = 'Tempo de conexão esgotado. Verifique sua internet.';
      } else if (e.type == DioExceptionType.connectionError) {
        _errorMessage = 'Sem conexão com o servidor. Verifique sua internet.';
      } else if (e.response?.statusCode == 500) {
        _errorMessage =
            'Erro no servidor. Tente novamente em alguns instantes.';
      } else {
        // 401 é tratado automaticamente pelo ApiClient (refresh de token)
        _errorMessage = UxStrings.errorLoadingChallenges;
      }
    } catch (e) {
      _state = MissionsViewState.error;
      _errorMessage =
          'Erro inesperado ao carregar ${UxStrings.challenges.toLowerCase()}.';
    } finally {
      notifyListeners();
    }
  }

  Future<void> loadRecommendedMissions({
    String? missionType,
    String? difficulty,
    int? limit,
  }) async {
    _catalogLoading = true;
    _catalogError = null;
    notifyListeners();

    try {
      final missions = await _repository.fetchRecommendedMissions(
        missionType: missionType,
        difficulty: difficulty,
        limit: limit,
      );
      
      _recommendedMissions = missions.where((m) => m.isValid).toList();
      
    } on DioException catch (e) {
      _catalogError = _mapDioError(
        e,
        fallback: 'Erro ao carregar missões recomendadas.',
      );
    } catch (e) {
      _catalogError =
          'Erro inesperado ao carregar missões recomendadas: ${e.toString()}';
    } finally {
      _catalogLoading = false;
      notifyListeners();
    }
  }

  Future<List<MissionModel>> loadMissionsForCategory(
    int categoryId, {
    bool forceReload = false,
    String? difficulty,
    bool includeInactive = false,
  }) async {
    if (!forceReload && _missionsByCategory.containsKey(categoryId)) {
      return _missionsByCategory[categoryId]!;
    }

    _catalogLoading = true;
    _catalogError = null;
    notifyListeners();

    try {
      final missions = await _repository.fetchMissionsByCategory(
        categoryId,
        difficulty: difficulty,
        includeInactive: includeInactive,
      );
      
      final validMissions = missions.where((m) => m.isValid).toList();
      
      _missionsByCategory[categoryId] = validMissions;
      return validMissions;
    } on DioException catch (e) {
      _catalogError = _mapDioError(
        e,
        fallback: 'Erro ao carregar missões para a categoria.',
      );
      rethrow;
    } catch (e) {
      _catalogError =
          'Erro inesperado ao carregar missões por categoria: ${e.toString()}';
      rethrow;
    } finally {
      _catalogLoading = false;
      notifyListeners();
    }
  }

  List<CategoryMissionSummary> _buildCategorySummaries() {
    if (_recommendedMissions.isEmpty) {
      return const [];
    }

    final Map<String, _CategoryAccumulator> buckets = {};

    for (final mission in _recommendedMissions) {
      final descriptors = _extractCategoryDescriptors(mission);
      for (final descriptor in descriptors) {
        final key = descriptor.id?.toString() ?? descriptor.name.toLowerCase();
        buckets.putIfAbsent(key, () => _CategoryAccumulator(descriptor));
        buckets[key]!.increment();
      }
    }

    final summaries = buckets.values
        .map((bucket) => CategoryMissionSummary(
              categoryId: bucket.id,
              name: bucket.name,
              count: bucket.count,
              colorHex: bucket.colorHex,
            ))
        .toList()
      ..sort((a, b) => b.count.compareTo(a.count));

    return summaries;
  }

  List<_CategoryDescriptor> _extractCategoryDescriptors(MissionModel mission) {
    final descriptors = <_CategoryDescriptor>[];

    if (mission.targetCategoryData != null) {
      descriptors.add(_CategoryDescriptor(
        id: mission.targetCategoryData!.id,
        name: mission.targetCategoryData!.name,
        colorHex: mission.targetCategoryData!.color,
      ));
    }

    for (final category in mission.targetCategories) {
      descriptors.add(_CategoryDescriptor(
        id: category.id,
        name: category.name,
        colorHex: category.color,
      ));
    }

    final targets = mission.targetInfo?['targets'];
    if (targets is List) {
      for (final item in targets) {
        if (item is Map && item['metric'] == 'CATEGORY') {
          descriptors.add(_CategoryDescriptor(
            id: item['category_id'] as int?,
            name: (item['label'] as String?) ?? 'Categoria-alvo',
            colorHex: null,
          ));
        }
      }
    }

    return descriptors;
  }

  Future<Map<String, dynamic>?> refreshMissionContextAnalysis({
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh && _contextAnalysis != null) {
      return _contextAnalysis;
    }

    _contextLoading = true;
    _contextError = null;
    notifyListeners();

    try {
      _contextAnalysis = await _repository.fetchMissionContextAnalysis(
        forceRefresh: forceRefresh,
      );
      
      if (_contextAnalysis == null) {
        _contextError = null;
      }
      
      return _contextAnalysis;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        _contextError = null;
        _contextAnalysis = null;
        return null;
      }
      
      _contextError = _mapDioError(
        e,
        fallback: 'Erro ao analisar contexto para missões.',
      );
      if (kDebugMode) {
        debugPrint('Erro ao buscar análise de contexto: ${e.message}');
      }
      return null;
    } catch (e) {
      _contextError =
          'Erro inesperado ao analisar contexto de missões: ${e.toString()}';
      if (kDebugMode) {
        debugPrint('Erro inesperado ao analisar contexto: $e');
      }
      return null;
    } finally {
      _contextLoading = false;
      notifyListeners();
    }
  }

  void _updateMissions(List<MissionProgressModel> missions) {
    final validMissions = <MissionProgressModel>[];
    final invalidMissions = <MissionProgressModel>[];
    
    for (final mission in missions) {
      if (mission.mission.hasPlaceholders()) {
        invalidMissions.add(mission);
        if (kDebugMode) {
          debugPrint(
            '⚠️ Missão inválida detectada: ID=${mission.mission.id} '
            'Título="${mission.mission.title}" '
            'Placeholders: ${mission.mission.getPlaceholders().join(", ")}'
          );
        }
      } else {
        validMissions.add(mission);
      }
    }
    
    if (invalidMissions.isNotEmpty && kDebugMode) {
      debugPrint(
        '🔍 Filtradas ${invalidMissions.length} missões com placeholders. '
        'IDs: ${invalidMissions.map((m) => m.mission.id).join(", ")}'
      );
    }

    final previousCompleted = _activeMissions
        .where((m) => m.status == 'COMPLETED')
        .map((m) => m.mission.id)
        .toSet();

    final newCompleted = validMissions
        .where((m) => m.status == 'COMPLETED')
        .map((m) => m.mission.id)
        .toSet();

    _newlyCompleted.clear();
    for (final id in newCompleted) {
      if (!previousCompleted.contains(id)) {
        _newlyCompleted.add(id);
      }
    }

    _activeMissions = validMissions;
  }

  Future<void> refreshSilently() async {
    try {
      final dashboard = await _repository.fetchDashboard();
      _updateMissions(dashboard.activeMissions);
      notifyListeners();
    } catch (e) {
      debugPrint('Erro ao atualizar missões silenciosamente: $e');
    }
  }

  void markMissionAsViewed(int missionId) {
    _newlyCompleted.remove(missionId);
    notifyListeners();
  }

  void clearCelebrations() {
    _newlyCompleted.clear();
    notifyListeners();
  }

  void updateMissionProgressOptimistic(int missionId, double newProgress) {
    final index = _activeMissions.indexWhere((m) => m.mission.id == missionId);
    if (index == -1) return;

    final mission = _activeMissions[index];

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

    if (newProgress >= 100) {
      _newlyCompleted.add(missionId);
    }

    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    if (_state == MissionsViewState.error) {
      _state = MissionsViewState.initial;
    }
    notifyListeners();
  }

  void clearCatalogError() {
    _catalogError = null;
    notifyListeners();
  }

  Future<void> startMission(int missionId) async {
    try {
      final updated = await _repository.startMissionAction(missionId);
      
      final index = _activeMissions.indexWhere((m) => m.mission.id == missionId);
      if (index != -1) {
        _activeMissions[index] = updated;
        notifyListeners();
      } else {
        // Fallback reload if finding index fails (shouldn't happen)
        await loadMissions();
      }
    } catch (e) {
      _errorMessage = 'Erro ao iniciar missão. Tente novamente.';
      notifyListeners();
    }
  }

  Future<void> skipMission(int missionId) async {
    try {
      await _repository.skipMissionAction(missionId);
      
      // Remove from list immediately
      _activeMissions.removeWhere((m) => m.mission.id == missionId);
      notifyListeners();
      
      // Reload to get new recommendation if available
      await loadMissions();
    } catch (e) {
       _errorMessage = 'Erro ao pular missão. Tente novamente.';
       notifyListeners();
    }
  }

  String _mapDioError(
    DioException exception, {
    required String fallback,
  }) {
    if (exception.type == DioExceptionType.connectionTimeout ||
        exception.type == DioExceptionType.receiveTimeout) {
      return 'Tempo de conexão esgotado. Verifique sua internet.';
    }
    if (exception.type == DioExceptionType.connectionError) {
      return 'Sem conexão com o servidor. Verifique sua internet.';
    }
    if (exception.response?.statusCode == 500) {
      return 'Erro no servidor. Tente novamente em instantes.';
    }
    // 401 é tratado automaticamente pelo ApiClient (refresh de token)
    return fallback;
  }

  @override
  void dispose() {
    _newlyCompleted.clear();
    super.dispose();
  }
}

class CategoryMissionSummary {
  const CategoryMissionSummary({
    required this.categoryId,
    required this.name,
    required this.count,
    this.colorHex,
  });

  final int? categoryId;
  final String name;
  final int count;
  final String? colorHex;
}

class _CategoryAccumulator {
  _CategoryAccumulator(_CategoryDescriptor descriptor)
      : id = descriptor.id,
        name = descriptor.name,
        colorHex = descriptor.colorHex;

  final int? id;
  final String name;
  final String? colorHex;
  int count = 0;

  void increment() => count++;
}

class _CategoryDescriptor {
  const _CategoryDescriptor({
    required this.id,
    required this.name,
    this.colorHex,
  });

  final int? id;
  final String name;
  final String? colorHex;
}

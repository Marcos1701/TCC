import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/endpoints.dart';

enum AdminViewState {
  initial,

  loading,

  success,

  error,
}

class AdminViewModel extends ChangeNotifier {
  AdminViewModel();

  final ApiClient _api = ApiClient();

  AdminViewState _state = AdminViewState.initial;
  String? _errorMessage;

  Map<String, dynamic>? _dashboardStats;

  List<Map<String, dynamic>> _missions = [];
  int _missionsTotalPages = 1;
  int _missionsCurrentPage = 1;

  List<Map<String, dynamic>> _categories = [];

  List<Map<String, dynamic>> _users = [];
  int _usersTotalPages = 1;
  int _usersCurrentPage = 1;

  Map<String, dynamic>? _missionTypeSchemas;
  bool _loadingSchemas = false;

  Map<String, dynamic>? _missionSelectOptions;
  bool _loadingSelectOptions = false;

  AdminViewState get state => _state;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _state == AdminViewState.loading;
  Map<String, dynamic>? get dashboardStats => _dashboardStats;
  List<Map<String, dynamic>> get missions => _missions;
  int get missionsTotalPages => _missionsTotalPages;
  int get missionsCurrentPage => _missionsCurrentPage;
  List<Map<String, dynamic>> get categories => _categories;
  List<Map<String, dynamic>> get users => _users;
  int get usersTotalPages => _usersTotalPages;
  int get usersCurrentPage => _usersCurrentPage;
  Map<String, dynamic>? get missionTypeSchemas => _missionTypeSchemas;
  bool get loadingSchemas => _loadingSchemas;
  Map<String, dynamic>? get missionSelectOptions => _missionSelectOptions;
  bool get loadingSelectOptions => _loadingSelectOptions;

  Future<void> loadDashboard() async {
    _state = AdminViewState.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _api.client.get(ApiEndpoints.adminDashboard);
      _dashboardStats = response.data as Map<String, dynamic>;
      _state = AdminViewState.success;
    } on DioException catch (e) {
      _state = AdminViewState.error;
      _errorMessage = _extractErrorMessage(e);
    } catch (e) {
      _state = AdminViewState.error;
      _errorMessage = 'Erro ao carregar dashboard';
    } finally {
      notifyListeners();
    }
  }

  Future<void> loadMissions({
    String? tipo,
    String? dificuldade,
    bool? ativo,
    int pagina = 1,
  }) async {
    _state = AdminViewState.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final params = <String, dynamic>{
        'pagina': pagina,
        'por_pagina': 20,
      };

      if (tipo != null) params['tipo'] = tipo;
      if (dificuldade != null) params['dificuldade'] = dificuldade;
      if (ativo != null) params['ativo'] = ativo.toString();

      final response = await _api.client.get(
        ApiEndpoints.adminMissions,
        queryParameters: params,
      );

      final data = response.data as Map<String, dynamic>;
      _missions = List<Map<String, dynamic>>.from(data['missoes'] ?? []);
      _missionsTotalPages = data['total_paginas'] ?? 1;
      _missionsCurrentPage = pagina;
      _state = AdminViewState.success;
    } on DioException catch (e) {
      _state = AdminViewState.error;
      _errorMessage = _extractErrorMessage(e);
    } catch (e) {
      _state = AdminViewState.error;
      _errorMessage = 'Erro ao carregar missões';
    } finally {
      notifyListeners();
    }
  }

  Future<bool> toggleMission(int missionId) async {
    try {
      final response = await _api.client.post(
        '${ApiEndpoints.adminMissions}$missionId/toggle/',
      );

      final data = response.data as Map<String, dynamic>;
      
      final index = _missions.indexWhere((m) => m['id'] == missionId);
      if (index != -1) {
        _missions[index]['is_active'] = data['ativo'];
        notifyListeners();
      }

      return data['sucesso'] == true;
    } catch (e) {
      debugPrint('Erro ao alternar missão: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>> generateMissions({
    required int quantidade,
    String? tier,
  }) async {
    try {
      final data = <String, dynamic>{
        'quantidade': quantidade,
      };
      
      if (tier != null) {
        data['tier'] = tier;
      }
      
      final response = await _api.client.post(
        ApiEndpoints.adminMissionsGenerate,
        data: data,
      );

      final responseData = response.data as Map<String, dynamic>;
      
      if (responseData['sucesso'] == true) {
        await loadMissions();
      }

      return responseData;
    } on DioException catch (e) {
      return {
        'sucesso': false,
        'erro': _extractErrorMessage(e),
      };
    } catch (e) {
      return {
        'sucesso': false,
        'erro': 'Erro ao gerar missões: $e',
      };
    }
  }

  Future<void> loadCategories({String? tipo}) async {
    _state = AdminViewState.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final params = <String, dynamic>{};
      if (tipo != null) params['tipo'] = tipo;

      final response = await _api.client.get(
        ApiEndpoints.adminCategories,
        queryParameters: params.isEmpty ? null : params,
      );

      final data = response.data as Map<String, dynamic>;
      _categories = List<Map<String, dynamic>>.from(data['categorias'] ?? []);
      _state = AdminViewState.success;
    } on DioException catch (e) {
      _state = AdminViewState.error;
      _errorMessage = _extractErrorMessage(e);
    } catch (e) {
      _state = AdminViewState.error;
      _errorMessage = 'Erro ao carregar categorias';
    } finally {
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>> createCategory({
    required String nome,
    required String tipo,
    String? cor,
  }) async {
    try {
      final response = await _api.client.post(
        ApiEndpoints.adminCategories,
        data: {
          'name': nome,
          'type': tipo,
          if (cor != null) 'color': cor,
        },
      );

      final data = response.data as Map<String, dynamic>;
      
      if (data['sucesso'] == true) {
        await loadCategories();
      }

      return data;
    } on DioException catch (e) {
      return {
        'sucesso': false,
        'erro': _extractErrorMessage(e),
      };
    } catch (e) {
      return {
        'sucesso': false,
        'erro': 'Erro ao criar categoria',
      };
    }
  }

  Future<bool> deleteCategory(int categoryId) async {
    try {
      await _api.client.delete(
        '${ApiEndpoints.adminCategories}$categoryId/',
      );
      
      _categories.removeWhere((c) => c['id'] == categoryId);
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Erro ao remover categoria: $e');
      return false;
    }
  }

  Future<void> loadUsers({
    String? busca,
    bool apenasAtivos = true,
    int pagina = 1,
  }) async {
    _state = AdminViewState.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final params = <String, dynamic>{
        'pagina': pagina,
        'por_pagina': 20,
        'ativos': apenasAtivos.toString(),
      };

      if (busca != null && busca.isNotEmpty) {
        params['busca'] = busca;
      }

      final response = await _api.client.get(
        ApiEndpoints.adminUsers,
        queryParameters: params,
      );

      final data = response.data as Map<String, dynamic>;
      _users = List<Map<String, dynamic>>.from(data['usuarios'] ?? []);
      _usersTotalPages = data['total_paginas'] ?? 1;
      _usersCurrentPage = pagina;
      _state = AdminViewState.success;
    } on DioException catch (e) {
      _state = AdminViewState.error;
      _errorMessage = _extractErrorMessage(e);
    } catch (e) {
      _state = AdminViewState.error;
      _errorMessage = 'Erro ao carregar usuários';
    } finally {
      notifyListeners();
    }
  }

  Future<bool> toggleUser(int userId) async {
    try {
      final response = await _api.client.post(
        '${ApiEndpoints.adminUsers}$userId/toggle/',
      );

      final data = response.data as Map<String, dynamic>;
      
      if (data['sucesso'] == true) {
        final index = _users.indexWhere((u) => u['id'] == userId);
        if (index != -1) {
          _users[index]['ativo'] = data['ativo'];
          notifyListeners();
        }
      }

      return data['sucesso'] == true;
    } catch (e) {
      debugPrint('Erro ao alternar usuário: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>> updateMission(
    int missionId,
    Map<String, dynamic> dados,
  ) async {
    try {
      final response = await _api.client.put(
        '${ApiEndpoints.adminMissions}$missionId/',
        data: dados,
      );

      final data = response.data as Map<String, dynamic>;

      if (data['sucesso'] == true) {
        final index = _missions.indexWhere((m) => m['id'] == missionId);
        if (index != -1 && data['missao'] != null) {
          _missions[index] = data['missao'] as Map<String, dynamic>;
          notifyListeners();
        }
      }

      return data;
    } on DioException catch (e) {
      return {
        'sucesso': false,
        'erro': _extractErrorMessage(e),
      };
    } catch (e) {
      return {
        'sucesso': false,
        'erro': 'Erro ao atualizar missão',
      };
    }
  }

  Future<bool> deleteMission(int missionId) async {
    try {
      await _api.client.delete(
        '${ApiEndpoints.adminMissions}$missionId/',
      );

      _missions.removeWhere((m) => m['id'] == missionId);
      notifyListeners();

      return true;
    } catch (e) {
      debugPrint('Erro ao excluir missão: $e');
      return false;
    }
  }

  String _extractErrorMessage(DioException e) {
    if (e.response?.statusCode == 403) {
      return 'Acesso negado. Você precisa ser administrador.';
    }
    // 401 é tratado automaticamente pelo ApiClient (refresh de token)
    if (e.response?.data is Map) {
      final data = e.response!.data as Map;
      if (data.containsKey('erro')) return data['erro'].toString();
      if (data.containsKey('detail')) return data['detail'].toString();
    }
    return 'Erro de conexão. Verifique sua internet.';
  }

  Future<void> loadMissionTypeSchemas() async {
    if (_missionTypeSchemas != null) return;

    _loadingSchemas = true;
    notifyListeners();

    try {
      final response = await _api.client.get(ApiEndpoints.adminMissionTypes);
      _missionTypeSchemas = response.data as Map<String, dynamic>;
      _loadingSchemas = false;
    } on DioException catch (e) {
      _loadingSchemas = false;
      debugPrint('Erro ao carregar schemas: ${_extractErrorMessage(e)}');
    } catch (e) {
      _loadingSchemas = false;
      debugPrint('Erro ao carregar schemas: $e');
    } finally {
      notifyListeners();
    }
  }

  Map<String, dynamic>? getSchemaForType(String missionType) {
    if (_missionTypeSchemas == null) return null;
    final types = _missionTypeSchemas!['types'] as Map<String, dynamic>?;
    return types?[missionType] as Map<String, dynamic>?;
  }

  List<Map<String, dynamic>> get missionTypesList {
    if (_missionTypeSchemas == null) return [];
    final list = _missionTypeSchemas!['types_list'] as List<dynamic>?;
    return list?.cast<Map<String, dynamic>>() ?? [];
  }

  List<Map<String, dynamic>> get commonFields {
    if (_missionTypeSchemas == null) return [];
    final fields = _missionTypeSchemas!['common_fields'] as List<dynamic>?;
    return fields?.cast<Map<String, dynamic>>() ?? [];
  }

  Future<void> loadMissionSelectOptions() async {
    if (_missionSelectOptions != null) return;

    _loadingSelectOptions = true;
    notifyListeners();

    try {
      final response = await _api.client.get(ApiEndpoints.adminMissionSelectOptions);
      _missionSelectOptions = response.data as Map<String, dynamic>;
      _loadingSelectOptions = false;
    } on DioException catch (e) {
      _loadingSelectOptions = false;
      debugPrint('Erro ao carregar opções de seleção: ${_extractErrorMessage(e)}');
    } catch (e) {
      _loadingSelectOptions = false;
      debugPrint('Erro ao carregar opções de seleção: $e');
    } finally {
      notifyListeners();
    }
  }

  List<Map<String, dynamic>> getCategoriesForSelect({String? tipo}) {
    if (_missionSelectOptions == null) return [];
    
    final categorias = _missionSelectOptions!['categorias'] as Map<String, dynamic>?;
    if (categorias == null) return [];
    
    final porTipo = categorias['por_tipo'] as Map<String, dynamic>?;
    if (porTipo == null) return [];
    
    if (tipo != null && porTipo.containsKey(tipo)) {
      return List<Map<String, dynamic>>.from(porTipo[tipo] as List);
    }
    
    final todas = <Map<String, dynamic>>[];
    for (final lista in porTipo.values) {
      todas.addAll(List<Map<String, dynamic>>.from(lista as List));
    }
    return todas;
  }

  Map<String, dynamic>? getDicaParaTipo(String missionType) {
    if (_missionSelectOptions == null) return null;
    
    final dicas = _missionSelectOptions!['dicas_por_tipo'] as Map<String, dynamic>?;
    return dicas?[missionType] as Map<String, dynamic>?;
  }

  bool tipoPermiteCategoria(String missionType) {
    final dica = getDicaParaTipo(missionType);
    return dica?['permite_selecao_categoria'] == true;
  }

  Future<Map<String, dynamic>> validateMissionData(
    Map<String, dynamic> dados,
  ) async {
    try {
      final response = await _api.client.post(
        ApiEndpoints.adminMissionValidate,
        data: dados,
      );
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      return {
        'valido': false,
        'erros': [_extractErrorMessage(e)],
      };
    } catch (e) {
      return {
        'valido': false,
        'erros': ['Erro ao validar missão: $e'],
      };
    }
  }

  Future<Map<String, dynamic>> createMission(Map<String, dynamic> dados) async {
    try {
      final response = await _api.client.post(
        ApiEndpoints.adminMissions,
        data: dados,
      );

      final data = response.data as Map<String, dynamic>;

      if (data['sucesso'] == true) {
        await loadMissions();
      }

      return data;
    } on DioException catch (e) {
      return {
        'sucesso': false,
        'erro': _extractErrorMessage(e),
      };
    } catch (e) {
      return {
        'sucesso': false,
        'erro': 'Erro ao criar missão: $e',
      };
    }
  }
}

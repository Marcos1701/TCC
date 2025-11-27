import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/endpoints.dart';

/// Estados do ViewModel de Administração.
enum AdminViewState {
  initial,
  loading,
  success,
  error,
}

/// ViewModel para o Painel Administrativo.
/// 
/// Gerencia missões, categorias e usuários de forma simplificada
/// para administradores do sistema.
class AdminViewModel extends ChangeNotifier {
  AdminViewModel();

  final ApiClient _api = ApiClient();

  // Estado geral
  AdminViewState _state = AdminViewState.initial;
  String? _errorMessage;

  // Dados do dashboard
  Map<String, dynamic>? _dashboardStats;

  // Missões
  List<Map<String, dynamic>> _missions = [];
  int _missionsTotalPages = 1;
  int _missionsCurrentPage = 1;

  // Categorias
  List<Map<String, dynamic>> _categories = [];

  // Usuários
  List<Map<String, dynamic>> _users = [];
  int _usersTotalPages = 1;
  int _usersCurrentPage = 1;

  // Getters
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

  /// Carrega estatísticas do dashboard administrativo.
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

  /// Carrega lista de missões com filtros opcionais.
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

  /// Alterna o estado ativo/inativo de uma missão.
  Future<bool> toggleMission(int missionId) async {
    try {
      final response = await _api.client.post(
        '${ApiEndpoints.adminMissions}$missionId/toggle/',
      );

      final data = response.data as Map<String, dynamic>;
      
      // Atualiza a missão na lista local
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

  /// Gera um lote de missões.
  Future<Map<String, dynamic>> generateMissions({
    required int quantidade,
    bool usarIA = false,
  }) async {
    try {
      final response = await _api.client.post(
        ApiEndpoints.adminMissionsGenerate,
        data: {
          'quantidade': quantidade,
          'usar_ia': usarIA,
        },
      );

      final data = response.data as Map<String, dynamic>;
      
      // Recarrega a lista de missões
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
        'erro': 'Erro ao gerar missões',
      };
    }
  }

  /// Carrega lista de categorias do sistema.
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

  /// Cria uma nova categoria do sistema.
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

  /// Remove uma categoria do sistema.
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

  /// Carrega lista de usuários.
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

  /// Alterna o estado ativo/inativo de um usuário.
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

  /// Extrai mensagem de erro de uma exceção Dio.
  String _extractErrorMessage(DioException e) {
    if (e.response?.statusCode == 403) {
      return 'Acesso negado. Você precisa ser administrador.';
    }
    if (e.response?.statusCode == 401) {
      return 'Sessão expirada. Faça login novamente.';
    }
    if (e.response?.data is Map) {
      final data = e.response!.data as Map;
      if (data.containsKey('erro')) return data['erro'].toString();
      if (data.containsKey('detail')) return data['detail'].toString();
    }
    return 'Erro de conexão. Verifique sua internet.';
  }
}

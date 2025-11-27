import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/endpoints.dart';

/// Estados possíveis do ViewModel de Administração.
///
/// Define os diferentes estados que o painel administrativo
/// pode assumir durante as operações de carregamento e processamento.
enum AdminViewState {
  /// Estado inicial, antes de qualquer operação.
  initial,

  /// Carregando dados do servidor.
  loading,

  /// Operação concluída com sucesso.
  success,

  /// Erro durante a operação.
  error,
}

/// ViewModel para o Painel Administrativo do Sistema.
///
/// Esta classe implementa o padrão MVVM (Model-View-ViewModel) e é
/// responsável por gerenciar o estado e a lógica de negócios do
/// painel administrativo, incluindo:
///
/// - Carregamento de estatísticas do dashboard;
/// - Gerenciamento de missões (listagem, ativação, geração em lote);
/// - Gerenciamento de categorias do sistema;
/// - Gerenciamento de usuários da aplicação.
///
/// Desenvolvido como parte do TCC - Sistema de Educação Financeira Gamificada.
class AdminViewModel extends ChangeNotifier {
  /// Cria uma nova instância do ViewModel administrativo.
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

  // Schemas de tipos de missão
  Map<String, dynamic>? _missionTypeSchemas;
  bool _loadingSchemas = false;

  // Opções de seleção para missões (categorias, metas, etc.)
  Map<String, dynamic>? _missionSelectOptions;
  bool _loadingSelectOptions = false;

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
  Map<String, dynamic>? get missionTypeSchemas => _missionTypeSchemas;
  bool get loadingSchemas => _loadingSchemas;
  Map<String, dynamic>? get missionSelectOptions => _missionSelectOptions;
  bool get loadingSelectOptions => _loadingSelectOptions;

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

  /// Carrega a lista de missões com filtros opcionais.
  ///
  /// Parâmetros de filtragem:
  /// - [tipo]: Tipo da missão (ONBOARDING, TPS_IMPROVEMENT, etc.);
  /// - [dificuldade]: Nível de dificuldade (EASY, MEDIUM, HARD);
  /// - [ativo]: Status de ativação da missão;
  /// - [pagina]: Número da página para paginação.
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

  /// Alterna o estado de ativação de uma missão.
  ///
  /// Este método permite ativar ou desativar uma missão específica.
  /// Missões desativadas não são exibidas para os usuários comuns,
  /// mas permanecem no sistema para referência e possível reativação.
  ///
  /// Retorna `true` se a operação foi bem-sucedida.
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

  /// Gera um lote de missões automaticamente.
  ///
  /// Este método permite a geração em massa de missões através
  /// de dois métodos distintos:
  ///
  /// - Templates: Utiliza modelos pré-definidos com variações
  ///   nos parâmetros. Execução mais rápida.
  /// - Inteligência Artificial: Gera missões mais diversificadas
  ///   através de modelo de linguagem. Execução mais demorada.
  ///
  /// Parâmetros:
  /// - [quantidade]: Número de missões a serem geradas;
  /// - [usarIA]: Se verdadeiro, utiliza IA para geração.
  ///
  /// Retorna um mapa com o resultado da operação.
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
        'erro': 'Erro ao gerar missões: $e',
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

  /// Atualiza uma missão existente.
  ///
  /// Permite ao administrador modificar os dados de uma missão,
  /// como título, descrição, recompensa, dificuldade e outros parâmetros.
  ///
  /// Retorna um mapa com o resultado da operação.
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
        // Atualiza a missão na lista local
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

  /// Exclui (desativa permanentemente) uma missão.
  ///
  /// Remove a missão do sistema. Na prática, realiza um soft delete,
  /// mantendo os dados para histórico mas tornando-a inacessível.
  ///
  /// Retorna `true` se a operação foi bem-sucedida.
  Future<bool> deleteMission(int missionId) async {
    try {
      await _api.client.delete(
        '${ApiEndpoints.adminMissions}$missionId/',
      );

      // Remove a missão da lista local
      _missions.removeWhere((m) => m['id'] == missionId);
      notifyListeners();

      return true;
    } catch (e) {
      debugPrint('Erro ao excluir missão: $e');
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

  /// Carrega os schemas de tipos de missão.
  ///
  /// Os schemas definem os campos obrigatórios e opcionais
  /// para cada tipo de missão, permitindo formulários dinâmicos.
  Future<void> loadMissionTypeSchemas() async {
    if (_missionTypeSchemas != null) return; // Cache

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

  /// Retorna o schema de um tipo de missão específico.
  Map<String, dynamic>? getSchemaForType(String missionType) {
    if (_missionTypeSchemas == null) return null;
    final types = _missionTypeSchemas!['types'] as Map<String, dynamic>?;
    return types?[missionType] as Map<String, dynamic>?;
  }

  /// Retorna a lista de tipos de missão para dropdown.
  List<Map<String, dynamic>> get missionTypesList {
    if (_missionTypeSchemas == null) return [];
    final list = _missionTypeSchemas!['types_list'] as List<dynamic>?;
    return list?.cast<Map<String, dynamic>>() ?? [];
  }

  /// Retorna os campos comuns a todos os tipos de missão.
  List<Map<String, dynamic>> get commonFields {
    if (_missionTypeSchemas == null) return [];
    final fields = _missionTypeSchemas!['common_fields'] as List<dynamic>?;
    return fields?.cast<Map<String, dynamic>>() ?? [];
  }

  /// Carrega opções de seleção para campos de missão.
  ///
  /// Carrega categorias do sistema e informações sobre vinculação
  /// de metas para facilitar a criação de missões.
  Future<void> loadMissionSelectOptions() async {
    if (_missionSelectOptions != null) return; // Cache

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

  /// Retorna lista de categorias para seleção.
  List<Map<String, dynamic>> getCategoriesForSelect({String? tipo}) {
    if (_missionSelectOptions == null) return [];
    
    final categorias = _missionSelectOptions!['categorias'] as Map<String, dynamic>?;
    if (categorias == null) return [];
    
    final porTipo = categorias['por_tipo'] as Map<String, dynamic>?;
    if (porTipo == null) return [];
    
    if (tipo != null && porTipo.containsKey(tipo)) {
      return List<Map<String, dynamic>>.from(porTipo[tipo] as List);
    }
    
    // Retorna todas as categorias se tipo não especificado
    final todas = <Map<String, dynamic>>[];
    for (final lista in porTipo.values) {
      todas.addAll(List<Map<String, dynamic>>.from(lista as List));
    }
    return todas;
  }

  /// Retorna dica de preenchimento para um tipo de missão.
  Map<String, dynamic>? getDicaParaTipo(String missionType) {
    if (_missionSelectOptions == null) return null;
    
    final dicas = _missionSelectOptions!['dicas_por_tipo'] as Map<String, dynamic>?;
    return dicas?[missionType] as Map<String, dynamic>?;
  }

  /// Verifica se um tipo de missão permite seleção de categoria.
  bool tipoPermiteCategoria(String missionType) {
    final dica = getDicaParaTipo(missionType);
    return dica?['permite_selecao_categoria'] == true;
  }

  /// Valida os dados de uma missão no servidor.
  ///
  /// Verifica se os campos obrigatórios estão preenchidos
  /// e se os valores estão dentro dos limites permitidos.
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

  /// Cria uma nova missão.
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

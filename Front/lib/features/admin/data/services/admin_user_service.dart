import 'package:dio/dio.dart';
import '../../../../core/network/api_client.dart';

/// Serviço para gerenciamento administrativo de usuários
/// 
/// Endpoints disponíveis:
/// - GET /api/admin/users/ - Lista usuários com filtros
/// - GET /api/admin/users/{id}/ - Detalhes do usuário
/// - POST /api/admin/users/{id}/deactivate/ - Desativar usuário
/// - POST /api/admin/users/{id}/reactivate/ - Reativar usuário
/// - POST /api/admin/users/{id}/adjust_xp/ - Ajustar XP
/// - GET /api/admin/users/{id}/admin_actions/ - Histórico de ações
class AdminUserService {
  final ApiClient _apiClient = ApiClient();

  /// Lista todos os usuários com filtros opcionais
  /// 
  /// Parâmetros:
  /// - [tier]: BEGINNER, INTERMEDIATE, ADVANCED
  /// - [isActive]: true/false
  /// - [search]: busca por username/email
  /// - [ordering]: campo de ordenação (ex: -date_joined, level, experience_points)
  /// - [page]: número da página
  Future<Map<String, dynamic>> listUsers({
    String? tier,
    bool? isActive,
    String? search,
    String? ordering,
    int page = 1,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'page': page,
      };

      if (tier != null) queryParams['tier'] = tier;
      if (isActive != null) queryParams['is_active'] = isActive;
      if (search != null && search.isNotEmpty) queryParams['search'] = search;
      if (ordering != null) queryParams['ordering'] = ordering;

      final response = await _apiClient.client.get(
        '/api/admin/users/',
        queryParameters: queryParams,
      );

      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Obtém detalhes completos de um usuário
  /// 
  /// Retorna:
  /// - Dados básicos (username, email, etc)
  /// - Perfil (level, XP, metas)
  /// - Estatísticas (TPS, RDR, ILI)
  /// - Transações recentes (últimas 10)
  /// - Missões ativas (até 5)
  /// - Histórico de ações admin (últimas 20)
  Future<Map<String, dynamic>> getUserDetails(int userId) async {
    try {
      final response = await _apiClient.client.get(
        '/api/admin/users/$userId/',
      );

      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Desativa um usuário
  /// 
  /// Requer:
  /// - [reason]: Motivo obrigatório para auditoria
  Future<Map<String, dynamic>> deactivateUser({
    required int userId,
    required String reason,
  }) async {
    try {
      final response = await _apiClient.client.post(
        '/api/admin/users/$userId/deactivate/',
        data: {'reason': reason},
      );

      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Reativa um usuário
  /// 
  /// Requer:
  /// - [reason]: Motivo obrigatório para auditoria
  Future<Map<String, dynamic>> reactivateUser({
    required int userId,
    required String reason,
  }) async {
    try {
      final response = await _apiClient.client.post(
        '/api/admin/users/$userId/reactivate/',
        data: {'reason': reason},
      );

      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Ajusta XP de um usuário
  /// 
  /// Requer:
  /// - [amount]: Valor entre -500 e +500
  /// - [reason]: Motivo obrigatório para auditoria
  /// 
  /// Retorna:
  /// - XP antigo e novo
  /// - Level antigo e novo
  /// - Flag se o level mudou
  Future<Map<String, dynamic>> adjustXp({
    required int userId,
    required int amount,
    required String reason,
  }) async {
    try {
      final response = await _apiClient.client.post(
        '/api/admin/users/$userId/adjust_xp/',
        data: {
          'amount': amount,
          'reason': reason,
        },
      );

      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Obtém histórico de ações administrativas de um usuário
  /// 
  /// Parâmetros:
  /// - [actionType]: Filtro opcional por tipo de ação
  /// - [page]: Número da página (50 itens por página)
  Future<Map<String, dynamic>> getAdminActions({
    required int userId,
    String? actionType,
    int page = 1,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'page': page,
      };

      if (actionType != null) {
        queryParams['action_type'] = actionType;
      }

      final response = await _apiClient.client.get(
        '/api/admin/users/$userId/admin_actions/',
        queryParameters: queryParams,
      );

      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  String _handleError(DioException e) {
    if (e.response?.statusCode == 403) {
      return 'Acesso negado. Apenas administradores podem acessar esta funcionalidade.';
    }
    if (e.response?.statusCode == 404) {
      return 'Usuário não encontrado.';
    }
    if (e.response?.data != null) {
      final data = e.response!.data;
      if (data is Map && data.containsKey('detail')) {
        return data['detail'] as String;
      }
      if (data is Map && data.containsKey('error')) {
        return data['error'] as String;
      }
    }
    return 'Erro ao realizar operação: ${e.message}';
  }
}

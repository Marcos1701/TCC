import 'package:dio/dio.dart';
import '../../../../core/network/api_client.dart';
import '../models/achievement.dart';

/// Serviço para gerenciamento de conquistas
/// 
/// Endpoints disponíveis:
/// - GET /api/achievements/ - Lista conquistas ativas
/// - GET /api/achievements/{id}/ - Detalhes da conquista
/// - POST /api/achievements/ - Criar conquista (admin)
/// - PUT /api/achievements/{id}/ - Atualizar conquista (admin)
/// - DELETE /api/achievements/{id}/ - Desativar conquista (admin)
/// - POST /api/achievements/generate_ai_achievements/ - Gerar com IA (admin)
/// - GET /api/achievements/my_achievements/ - Progresso do usuário
/// - POST /api/achievements/{id}/unlock/ - Desbloquear manualmente
class AchievementService {
  final ApiClient _apiClient = ApiClient();

  /// Lista todas as conquistas ativas com filtros opcionais
  /// 
  /// Parâmetros:
  /// - [category]: FINANCIAL, SOCIAL, MISSION, STREAK, GENERAL
  /// - [tier]: BEGINNER, INTERMEDIATE, ADVANCED
  /// - [isAiGenerated]: true/false
  /// - [search]: busca por título ou descrição
  /// - [ordering]: campo de ordenação (priority, -xp_reward, created_at)
  Future<List<Achievement>> listAchievements({
    String? category,
    String? tier,
    bool? isAiGenerated,
    String? search,
    String? ordering,
  }) async {
    try {
      final queryParams = <String, dynamic>{};

      if (category != null) queryParams['category'] = category;
      if (tier != null) queryParams['tier'] = tier;
      if (isAiGenerated != null) queryParams['is_ai_generated'] = isAiGenerated;
      if (search != null && search.isNotEmpty) queryParams['search'] = search;
      if (ordering != null) queryParams['ordering'] = ordering;

      final response = await _apiClient.client.get(
        '/api/achievements/',
        queryParameters: queryParams,
      );

      final List<dynamic> results = response.data as List<dynamic>;
      return results.map((json) => Achievement.fromJson(json as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Obtém detalhes de uma conquista específica
  Future<Achievement> getAchievement(int achievementId) async {
    try {
      final response = await _apiClient.client.get(
        '/api/achievements/$achievementId/',
      );

      return Achievement.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Obtém progresso do usuário em todas as conquistas ativas
  /// 
  /// Retorna lista ordenada por:
  /// 1. Conquistas não desbloqueadas primeiro
  /// 2. Progresso descendente (mais próximas de desbloquear)
  Future<List<UserAchievement>> getMyAchievements() async {
    try {
      final response = await _apiClient.client.get(
        '/api/achievements/my_achievements/',
      );

      final List<dynamic> results = response.data as List<dynamic>;
      return results.map((json) => UserAchievement.fromJson(json as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Desbloqueia manualmente uma conquista
  /// 
  /// Útil para testes e awards especiais
  /// 
  /// Retorna:
  /// - status: "unlocked" ou "already_unlocked"
  /// - xp_awarded: XP ganho (se desbloqueado agora)
  Future<Map<String, dynamic>> unlockAchievement(int achievementId) async {
    try {
      final response = await _apiClient.client.post(
        '/api/achievements/$achievementId/unlock/',
      );

      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // ===== MÉTODOS ADMIN =====

  /// Cria uma nova conquista (admin only)
  /// 
  /// Requer campos:
  /// - title, description, category, tier, xp_reward, icon, criteria
  Future<Achievement> createAchievement({
    required String title,
    required String description,
    required String category,
    required String tier,
    required int xpReward,
    required String icon,
    required Map<String, dynamic> criteria,
    int priority = 50,
  }) async {
    try {
      final response = await _apiClient.client.post(
        '/api/achievements/',
        data: {
          'title': title,
          'description': description,
          'category': category,
          'tier': tier,
          'xp_reward': xpReward,
          'icon': icon,
          'criteria': criteria,
          'priority': priority,
          'is_active': true,
          'is_ai_generated': false,
        },
      );

      return Achievement.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Atualiza uma conquista existente (admin only)
  Future<Achievement> updateAchievement({
    required int achievementId,
    String? title,
    String? description,
    String? category,
    String? tier,
    int? xpReward,
    String? icon,
    Map<String, dynamic>? criteria,
    bool? isActive,
    int? priority,
  }) async {
    try {
      final data = <String, dynamic>{};
      if (title != null) data['title'] = title;
      if (description != null) data['description'] = description;
      if (category != null) data['category'] = category;
      if (tier != null) data['tier'] = tier;
      if (xpReward != null) data['xp_reward'] = xpReward;
      if (icon != null) data['icon'] = icon;
      if (criteria != null) data['criteria'] = criteria;
      if (isActive != null) data['is_active'] = isActive;
      if (priority != null) data['priority'] = priority;

      final response = await _apiClient.client.patch(
        '/api/achievements/$achievementId/',
        data: data,
      );

      return Achievement.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Desativa uma conquista (soft delete) (admin only)
  Future<void> deleteAchievement(int achievementId) async {
    try {
      await _apiClient.client.delete(
        '/api/achievements/$achievementId/',
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Gera conquistas usando IA (Google Gemini) (admin only)
  /// 
  /// Parâmetros:
  /// - [category]: 'ALL', 'FINANCIAL', 'SOCIAL', 'MISSION', 'STREAK', 'GENERAL'
  /// - [tier]: 'ALL', 'BEGINNER', 'INTERMEDIATE', 'ADVANCED'
  /// 
  /// Retorna:
  /// - created: número de conquistas criadas
  /// - total: total de conquistas geradas
  /// - cached: true se usou cache (30 dias)
  Future<Map<String, dynamic>> generateAiAchievements({
    String category = 'ALL',
    String tier = 'ALL',
  }) async {
    try {
      final response = await _apiClient.client.post(
        '/api/achievements/generate_ai_achievements/',
        data: {
          'category': category,
          'tier': tier,
        },
      );

      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // ===== HELPERS =====

  String _handleError(DioException e) {
    if (e.response != null) {
      final data = e.response!.data;
      if (data is Map && data.containsKey('error')) {
        return data['error'] as String;
      }
      if (data is Map && data.containsKey('detail')) {
        return data['detail'] as String;
      }
      return 'Erro ao processar requisição: ${e.response!.statusCode}';
    }
    return 'Erro de conexão. Verifique sua internet.';
  }
}

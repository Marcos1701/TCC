import 'package:dio/dio.dart';
import '../../../core/models/dashboard.dart';
import '../../../core/models/analytics.dart';
import '../../../core/network/api_client.dart';

/// Serviço para buscar dados do dashboard
class DashboardService {
  DashboardService() : _dio = ApiClient().client;

  final Dio _dio;

  /// Busca todos os dados do dashboard (métricas, gráficos, insights, missões)
  Future<DashboardData> getDashboard() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>('/api/dashboard/');
      
      if (response.statusCode == 200 && response.data != null) {
        return DashboardData.fromMap(response.data!);
      } else {
        throw DioException(
          requestOptions: response.requestOptions,
          response: response,
          error: 'Resposta inválida do servidor',
        );
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        throw Exception('Sessão expirada. Faça login novamente.');
      } else if (e.response?.statusCode == 404) {
        throw Exception('Endpoint do dashboard não encontrado.');
      } else if (e.type == DioExceptionType.connectionTimeout ||
                 e.type == DioExceptionType.receiveTimeout) {
        throw Exception('Tempo esgotado. Verifique sua conexão.');
      } else if (e.type == DioExceptionType.connectionError) {
        throw Exception('Erro de conexão. Verifique sua internet.');
      } else {
        throw Exception('Erro ao carregar dashboard: ${e.message}');
      }
    } catch (e) {
      throw Exception('Erro inesperado ao carregar dashboard: $e');
    }
  }

  /// Busca análises avançadas do usuário
  /// 
  /// Endpoint: GET /api/dashboard/analytics/
  /// Retorna dados completos de evolução, padrões de categoria, tier e distribuição de missões
  Future<AnalyticsData> getAnalytics() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>('/api/dashboard/analytics/');
      
      if (response.statusCode == 200 && response.data != null) {
        return AnalyticsData.fromJson(response.data!);
      } else {
        throw DioException(
          requestOptions: response.requestOptions,
          response: response,
          error: 'Resposta inválida do servidor',
        );
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        throw Exception('Sessão expirada. Faça login novamente.');
      } else if (e.response?.statusCode == 404) {
        throw Exception('Endpoint de analytics não encontrado.');
      } else if (e.response?.statusCode == 500) {
        throw Exception('Erro no servidor ao processar analytics.');
      } else if (e.type == DioExceptionType.connectionTimeout ||
                 e.type == DioExceptionType.receiveTimeout) {
        throw Exception('Tempo esgotado. Verifique sua conexão.');
      } else if (e.type == DioExceptionType.connectionError) {
        throw Exception('Erro de conexão. Verifique sua internet.');
      } else {
        throw Exception('Erro ao carregar analytics: ${e.message}');
      }
    } catch (e) {
      throw Exception('Erro inesperado ao carregar analytics: $e');
    }
  }

  /// Busca apenas o contexto abrangente (mais leve que analytics completo)
  Future<ComprehensiveContext> getComprehensiveContext() async {
    final analytics = await getAnalytics();
    return analytics.comprehensiveContext;
  }

  /// Busca apenas padrões de categoria
  Future<CategoryPatternsAnalysis> getCategoryPatterns() async {
    final analytics = await getAnalytics();
    return analytics.categoryPatterns;
  }

  /// Busca apenas progressão de tier
  Future<TierProgressionAnalysis> getTierProgression() async {
    final analytics = await getAnalytics();
    return analytics.tierProgression;
  }

  /// Busca apenas distribuição de missões
  Future<MissionDistributionAnalysis> getMissionDistribution() async {
    final analytics = await getAnalytics();
    return analytics.missionDistribution;
  }
}

import 'package:dio/dio.dart';
import '../../../core/models/dashboard.dart';
import '../../../core/models/analytics.dart';
import '../../../core/network/api_client.dart';

class DashboardService {
  DashboardService() : _dio = ApiClient().client;

  final Dio _dio;

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
      // 401 é tratado automaticamente pelo ApiClient (refresh de token)
      if (e.response?.statusCode == 404) {
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
      // 401 é tratado automaticamente pelo ApiClient (refresh de token)
      if (e.response?.statusCode == 404) {
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

  Future<ComprehensiveContext> getComprehensiveContext() async {
    final analytics = await getAnalytics();
    return analytics.comprehensiveContext;
  }

  Future<CategoryPatternsAnalysis> getCategoryPatterns() async {
    final analytics = await getAnalytics();
    return analytics.categoryPatterns;
  }

  Future<TierProgressionAnalysis> getTierProgression() async {
    final analytics = await getAnalytics();
    return analytics.tierProgression;
  }

  Future<MissionDistributionAnalysis> getMissionDistribution() async {
    final analytics = await getAnalytics();
    return analytics.missionDistribution;
  }
}

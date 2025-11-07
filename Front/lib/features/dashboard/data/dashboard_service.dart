import 'package:dio/dio.dart';
import '../../../core/models/dashboard.dart';
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
}

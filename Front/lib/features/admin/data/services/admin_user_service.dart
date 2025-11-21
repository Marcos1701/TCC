import 'package:dio/dio.dart';
import '../../../../core/network/api_client.dart';










class AdminUserService {
  final ApiClient _apiClient = ApiClient();









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
      return 'Acesso negado. Privilégios administrativos necessários.';
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

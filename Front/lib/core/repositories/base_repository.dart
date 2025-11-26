import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../errors/failures.dart';
import '../network/api_client.dart';

/// Classe base para todos os repositórios.
/// Contém métodos utilitários comuns.
abstract class BaseRepository {
  BaseRepository({ApiClient? client}) : _client = client ?? ApiClient();

  final ApiClient _client;
  
  @protected
  ApiClient get client => _client;

  @protected
  Failure handleError(dynamic error) {
    if (error is DioException) {
      switch (error.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
        case DioExceptionType.connectionError:
          return const NetworkFailure('Verifique sua conexão com a internet');
        
        case DioExceptionType.badResponse:
          final statusCode = error.response?.statusCode;
          final data = error.response?.data;
          
          if (statusCode == 401) {
            return const UnauthorizedFailure();
          }
          
          if (statusCode == 404) {
            return const NotFoundFailure();
          }
          
          if (statusCode == 400 && data is Map<String, dynamic>) {
            final message = data['detail'] ?? 
                           data['error'] ?? 
                           data['message'] ?? 
                           'Dados inválidos';
            return ValidationFailure(message.toString(), errors: data);
          }
          
          if (data is Map<String, dynamic>) {
            final message = data['detail'] ?? data['error'] ?? 'Erro no servidor';
            return ServerFailure(message.toString(), statusCode: statusCode);
          }
          
          return ServerFailure(
            'Erro no servidor (${statusCode ?? "desconhecido"})',
            statusCode: statusCode,
          );
        
        default:
          return NetworkFailure(error.message ?? 'Erro de conexão');
      }
    }
    
    return ServerFailure(error.toString());
  }

  @protected
  List<dynamic> extractListFromResponse(dynamic data) {
    if (data == null) {
      debugPrint('Warning: extractListFromResponse: data is null');
      return [];
    }
    
    if (data is Map<String, dynamic>) {
      if (data.containsKey('results')) {
        final results = data['results'];
        if (results is List<dynamic>) {
          return results;
        }
        return [];
      }
      
      if (data.containsKey('detail') || data.containsKey('error')) {
        debugPrint('Error response detected: $data');
      }
      return [];
    }
    
    if (data is List<dynamic>) {
      return data;
    }
    
    return [];
  }
}

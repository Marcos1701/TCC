import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../storage/secure_storage_service.dart';

typedef OnSessionExpired = void Function();

class ApiClient {
  ApiClient._internal() {
    final options = BaseOptions(
      baseUrl: _normaliseBaseUrl(_resolveBaseUrl()),
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(minutes: 5),
      sendTimeout: const Duration(seconds: 60),
      contentType: 'application/json',
      headers: const {'Accept': 'application/json'},
      responseType: ResponseType.json,
      validateStatus: (status) => status != null && status >= 200 && status < 300,
    );

    _dio = Dio(options)
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) async {
            final publicEndpoints = [
              '/api/token/',
              '/api/token/refresh/',
              '/api/auth/register/',
            ];
            
            final isPublicEndpoint = publicEndpoints.any(
              (endpoint) => options.path.contains(endpoint),
            );
            
            if (!isPublicEndpoint) {
              final token = _accessToken ?? await _storage.readToken();
              if (token != null) {
                options.headers['Authorization'] = 'Bearer $token';
              }
            }
            handler.next(options);
          },
          onError: (error, handler) async {
            if (error.response?.data != null) {
              try {
                final data = error.response!.data;
                String? errorMessage;
                
                if (data is Map<String, dynamic>) {
                  if (data.containsKey('non_field_errors')) {
                    final errors = data['non_field_errors'];
                    if (errors is List && errors.isNotEmpty) {
                      errorMessage = errors.first.toString();
                    } else if (errors is String) {
                      errorMessage = errors;
                    }
                  } else if (data.containsKey('detail')) {
                    errorMessage = data['detail'].toString();
                  } else if (data.containsKey('error')) {
                    errorMessage = data['error'].toString();
                  }
                  
                  if (errorMessage != null) {
                    final newError = DioException(
                      requestOptions: error.requestOptions,
                      response: error.response,
                      type: error.type,
                      error: errorMessage,
                    );
                    return handler.next(newError);
                  }
                }
              } catch (e) {
                debugPrint('⚠️ Error extracting error message: $e');
              }
            }
            
            if (_shouldTryRefresh(error)) {
              final retried = await _refreshAndRetry(error.requestOptions);
              if (retried != null) {
                return handler.resolve(retried);
              }
            }
            handler.next(error);
          },
        ),
      );
  }

  static final ApiClient _instance = ApiClient._internal();

  factory ApiClient() => _instance;

  late final Dio _dio;
  final SecureStorageService _storage = SecureStorageService();

  String? _accessToken;
  String? _refreshToken;
  bool _refreshing = false;
  OnSessionExpired? _onSessionExpired;

  Dio get client => _dio;

  void setOnSessionExpired(OnSessionExpired callback) {
    _onSessionExpired = callback;
  }

  void clearOnSessionExpired() {
    _onSessionExpired = null;
  }

  Future<void> bootstrap() async {
    _accessToken = await _storage.readToken();
    _refreshToken = await _storage.readRefreshToken();
  }

  Future<void> setTokens(
      {required String access, required String refresh}) async {
    _accessToken = access;
    _refreshToken = refresh;
    await _storage.saveToken(access);
    await _storage.saveRefreshToken(refresh);
  }

  Future<void> clearTokens() async {
    _accessToken = null;
    _refreshToken = null;
    await _storage.clearAll();
  }

  bool _shouldTryRefresh(DioException error) {
    if (error.response?.statusCode != 401) return false;
    if (_refreshing) return false;
    return _refreshToken != null;
  }

  Future<Response<dynamic>?> _refreshAndRetry(RequestOptions original) async {
    if (_refreshToken == null) {
      debugPrint('🚨 Refresh token not available, notifying expiration');
      await clearTokens();
      _notifySessionExpired();
      return null;
    }
    
    try {
      _refreshing = true;
      debugPrint('🔄 Trying to refresh access token...');
      
      final response = await _dio.post<Map<String, dynamic>>(
        '/api/token/refresh/',
        data: {'refresh': _refreshToken},
        options: Options(headers: {'Authorization': null}),
      );
      
      final data = response.data ?? {};
      final newAccess = data['access'] as String?;
      final refreshValue = (data['refresh'] as String?) ?? _refreshToken;
      
      if (newAccess != null && refreshValue != null) {
        debugPrint('✅ Token refreshed successfully');
        await setTokens(access: newAccess, refresh: refreshValue);
        
        final opts = Options(
          method: original.method,
          headers: Map<String, dynamic>.from(original.headers),
        );
        
        return _dio.request<dynamic>(
          original.path,
          data: original.data,
          queryParameters: original.queryParameters,
          options: opts,
        );
      } else {
        debugPrint('🚨 Invalid refresh response, notifying expiration');
        await clearTokens();
        _notifySessionExpired();
      }
    } on DioException catch (e) {
      debugPrint('🚨 Error refreshing token (${e.response?.statusCode}), notifying expiration');
      await clearTokens();
      _notifySessionExpired();
    } finally {
      _refreshing = false;
    }
    return null;
  }

  void _notifySessionExpired() {
    debugPrint('📢 Notifying session expiration');
    _onSessionExpired?.call();
  }

  static String _resolveBaseUrl() {
    const override = String.fromEnvironment('API_BASE_URL');
    if (override.isNotEmpty) {
      return override;
    }

    if (kIsWeb) {
      final uri = Uri.base;
      final host = uri.host;
      if (uri.scheme.startsWith('http') &&
          host.isNotEmpty &&
          host != 'localhost' &&
          host != '127.0.0.1') {
        return uri.origin;
      }
      return 'http://localhost:8000';
    }

    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8000';
    }

    return 'http://localhost:8000';
  }

  static String _normaliseBaseUrl(String value) {
    if (value.endsWith('/')) {
      return value.substring(0, value.length - 1);
    }
    return value;
  }
}

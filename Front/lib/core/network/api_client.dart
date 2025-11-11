import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../storage/secure_storage_service.dart';

/// Cliente único pra falar com a API.
/// guarda token na memória e renova quando 401 pingar.
class ApiClient {
  ApiClient._internal() {
    final options = BaseOptions(
      baseUrl: _normaliseBaseUrl(_resolveBaseUrl()),
      connectTimeout: const Duration(seconds: 20),  // Aumentado de 15s para 20s
      receiveTimeout: const Duration(seconds: 60),  // Aumentado de 25s para 60s (geração de missões com IA)
      sendTimeout: const Duration(seconds: 30),     // Adicionado timeout de envio
      contentType: 'application/json',
      headers: const {'Accept': 'application/json'},
      responseType: ResponseType.json,
      validateStatus: (status) => status != null && status < 500,
    );

    _dio = Dio(options)
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) async {
            final token = _accessToken ?? await _storage.readToken();
            if (token != null) {
              options.headers['Authorization'] = 'Bearer $token';
            }
            handler.next(options);
          },
          onError: (error, handler) async {
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

  Dio get client => _dio;

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
    if (_refreshToken == null) return null;
    try {
      _refreshing = true;
      final response = await _dio.post<Map<String, dynamic>>(
        '/api/token/refresh/',
        data: {'refresh': _refreshToken},
        options: Options(headers: {'Authorization': null}),
      );
      final data = response.data ?? {};
      final newAccess = data['access'] as String?;
      final refreshValue = (data['refresh'] as String?) ?? _refreshToken;
      if (newAccess != null && refreshValue != null) {
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
      }
    } on DioException {
      await clearTokens();
    } finally {
      _refreshing = false;
    }
    return null;
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

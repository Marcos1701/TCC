import 'package:dio/dio.dart';

import '../storage/secure_storage_service.dart';

/// Cliente único pra bater na API, seguindo o fluxo JWT do doc e renovando token quando 401 pingar.
class ApiClient {
  ApiClient._internal() {
    final options = BaseOptions(
      baseUrl: const String.fromEnvironment(
        'API_BASE_URL',
        defaultValue: 'http://localhost:8000',
      ),
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 25),
      contentType: 'application/json',
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

  Future<void> setTokens({required String access, required String refresh}) async {
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
      final newRefresh = data['refresh'] as String? ?? _refreshToken;
      if (newAccess != null) {
        await setTokens(access: newAccess, refresh: newRefresh ?? _refreshToken!);
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
}

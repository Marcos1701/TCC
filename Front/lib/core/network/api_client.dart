import 'package:dio/dio.dart';

/// Casca simples pra montar o `Dio` que vai falar com a API.
///
/// Mais pra frente a gente cola interceptors de auth, logs e regras de erro do
/// jeito que o documento pede (JWT, TLS obrigatório, retries e tudo mais).
class ApiClient {
  ApiClient({Dio? dio}) : _dio = dio ?? _createDefaultClient();

  final Dio _dio;

  Dio get client => _dio;

  static Dio _createDefaultClient() {
    final options = BaseOptions(
      baseUrl: 'https://api.genapp.local',
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 20),
      contentType: 'application/json',
    );

    final dio = Dio(options);
    dio.interceptors.add(
      QueuedInterceptorsWrapper(
        onRequest: (options, handler) {
          // Depois encaixamos cabeçalhos de auth e telemetria aqui.
          handler.next(options);
        },
      ),
    );
    return dio;
  }
}

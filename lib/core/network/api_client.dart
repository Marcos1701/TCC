import 'package:dio/dio.dart';

/// Basic wrapper responsible for configuring the `Dio` HTTP client used by the
/// GenApp backend integration.
///
/// Future tasks will plug authentication interceptors, logging and error
/// handling policies according to the specification defined in the project
/// document (JWT, TLS enforcement, retry policies, etc.).
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
          // Placeholder for authentication headers and telemetry.
          handler.next(options);
        },
      ),
    );
    return dio;
  }
}

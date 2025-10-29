import '../models/auth_tokens.dart';
import '../models/profile.dart';
import '../models/session_data.dart';
import '../network/api_client.dart';
import '../network/endpoints.dart';

class AuthRepository {
  AuthRepository({ApiClient? client}) : _client = client ?? ApiClient();

  final ApiClient _client;

  Future<AuthTokens> login(
      {required String email, required String password}) async {
    final normalizedEmail = email.trim().toLowerCase();
    final response = await _client.client.post<Map<String, dynamic>>(
      ApiEndpoints.token,
      data: {
        'email': normalizedEmail,
        'username': normalizedEmail,
        'password': password,
      },
    );
    final data = response.data ?? <String, dynamic>{};
    return AuthTokens.fromMap(data);
  }

  Future<AuthTokens> register({
    required String name,
    required String email,
    required String password,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    final response = await _client.client.post<Map<String, dynamic>>(
      ApiEndpoints.register,
      data: {
        'name': name.trim(),
        'email': normalizedEmail,
        'password': password,
      },
    );
    final body = response.data ?? <String, dynamic>{};
    final tokens = body['tokens'];
    if (tokens is Map<String, dynamic>) {
      return AuthTokens.fromMap(tokens);
    }
    throw StateError('Resposta de registro sem tokens.');
  }

  Future<SessionData> fetchSession() async {
    final response =
        await _client.client.get<Map<String, dynamic>>(ApiEndpoints.profile);
    final data = response.data ?? <String, dynamic>{};
    final user = UserHeader.fromMap(data['user'] as Map<String, dynamic>);
    final profile = ProfileModel.fromMap(
      (data['snapshot'] ?? data['profile']) as Map<String, dynamic>,
    );
    return SessionData(user: user, profile: profile);
  }

  Future<ProfileModel> updateTargets(
      {required Map<String, dynamic> payload}) async {
    final response = await _client.client.put<Map<String, dynamic>>(
      ApiEndpoints.profile,
      data: payload,
    );
    final body = response.data ?? <String, dynamic>{};
    return ProfileModel.fromMap(
        (body['snapshot'] ?? body['profile']) as Map<String, dynamic>);
  }

  Future<void> logout() async {
    await _client.clearTokens();
  }
}

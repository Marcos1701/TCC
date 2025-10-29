import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Serviço que guarda info sensível usando o cofre nativo (Keychain, Keystore...).
///
/// Tokens, salts e afins citados no documento ficam aqui. A API é curtinha,
/// pronta pra crescer junto com o módulo de autenticação.
class SecureStorageService {
  SecureStorageService({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const _tokenKey = 'auth_token';
  static const _refreshTokenKey = 'refresh_token';

  Future<void> saveToken(String token) =>
      _storage.write(key: _tokenKey, value: token);

  Future<String?> readToken() => _storage.read(key: _tokenKey);

  Future<void> deleteToken() => _storage.delete(key: _tokenKey);

  Future<void> saveRefreshToken(String token) =>
      _storage.write(key: _refreshTokenKey, value: token);

  Future<String?> readRefreshToken() => _storage.read(key: _refreshTokenKey);

  Future<void> clearAll() => _storage.deleteAll();
}

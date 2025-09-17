import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Service responsible for persisting sensitive information locally using the
/// platform secure storage (Keychain on iOS, Keystore on Android, etc.).
///
/// Access tokens, refresh tokens and cryptographic salts described in the
/// project specification should be saved here. The class exposes a minimal API
/// that can evolve alongside the authentication module.
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

  Future<String?> readRefreshToken() =>
      _storage.read(key: _refreshTokenKey);

  Future<void> clearAll() => _storage.deleteAll();
}

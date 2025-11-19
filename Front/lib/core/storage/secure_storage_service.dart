import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Service that stores sensitive info using native vault (Keychain, Keystore...).
///
/// Tokens, salts and similar items mentioned in the document stay here. The API is short,
/// ready to grow along with the authentication module.
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

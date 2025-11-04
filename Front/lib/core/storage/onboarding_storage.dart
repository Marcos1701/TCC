import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Serviço para controlar o estado do onboarding do usuário
class OnboardingStorage {
  static const _storage = FlutterSecureStorage();
  static const _onboardingCompleteKey = 'onboarding_complete';

  /// Verifica se o usuário já completou o onboarding
  static Future<bool> isOnboardingComplete() async {
    final value = await _storage.read(key: _onboardingCompleteKey);
    return value == 'true';
  }

  /// Marca o onboarding como completo
  static Future<void> markOnboardingComplete() async {
    await _storage.write(key: _onboardingCompleteKey, value: 'true');
  }

  /// Reseta o estado do onboarding (útil para testes)
  static Future<void> resetOnboarding() async {
    await _storage.delete(key: _onboardingCompleteKey);
  }
}

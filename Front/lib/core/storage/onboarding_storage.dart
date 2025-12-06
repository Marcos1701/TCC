import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class OnboardingStorage {
  static const _storage = FlutterSecureStorage();
  static const _onboardingCompleteKey = 'onboarding_complete';

  static Future<bool> isOnboardingComplete() async {
    final value = await _storage.read(key: _onboardingCompleteKey);
    return value == 'true';
  }

  static Future<void> markOnboardingComplete() async {
    await _storage.write(key: _onboardingCompleteKey, value: 'true');
  }

  static Future<void> resetOnboarding() async {
    await _storage.delete(key: _onboardingCompleteKey);
  }
}

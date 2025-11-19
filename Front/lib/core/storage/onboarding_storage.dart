import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Service to control user onboarding state
class OnboardingStorage {
  static const _storage = FlutterSecureStorage();
  static const _onboardingCompleteKey = 'onboarding_complete';

  /// Checks if user has completed onboarding
  static Future<bool> isOnboardingComplete() async {
    final value = await _storage.read(key: _onboardingCompleteKey);
    return value == 'true';
  }

  /// Marks onboarding as complete
  static Future<void> markOnboardingComplete() async {
    await _storage.write(key: _onboardingCompleteKey, value: 'true');
  }

  /// Resets onboarding state (useful for testing)
  static Future<void> resetOnboarding() async {
    await _storage.delete(key: _onboardingCompleteKey);
  }
}

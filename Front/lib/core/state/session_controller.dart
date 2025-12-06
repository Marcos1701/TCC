import 'package:flutter/material.dart';

import '../models/profile.dart';
import '../models/session_data.dart';
import '../network/api_client.dart';
import '../repositories/auth_repository.dart';

class SessionController extends ChangeNotifier {
  SessionController({AuthRepository? authRepository})
      : _authRepository = authRepository ?? AuthRepository() {
    ApiClient().setOnSessionExpired(_handleSessionExpired);
  }

  final AuthRepository _authRepository;
  SessionData? _session;
  bool _loading = true;
  bool _bootstrapDone = false;
  bool _isNewRegistration = false;
  bool _sessionExpired = false;

  SessionData? get session => _session;
  bool get isAuthenticated => _session != null && !_sessionExpired;
  bool get isLoading => _loading;
  bool get bootstrapDone => _bootstrapDone;
  bool get isNewRegistration => _isNewRegistration;
  bool get sessionExpired => _sessionExpired;

  ProfileModel? get profile => _session?.profile;

  void _handleSessionExpired() {
    _sessionExpired = true;
    _session = null;
    _isNewRegistration = false;
    notifyListeners();
  }

  @override
  void dispose() {
    ApiClient().clearOnSessionExpired();
    super.dispose();
  }

  Future<void> bootstrap() async {
    if (_bootstrapDone) return;
    _bootstrapDone = true;
    await ApiClient().bootstrap();
    try {
      _session = await _authRepository.fetchSession();
    } catch (_) {
      _session = null;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> login({required String email, required String password}) async {
    _loading = true;
    _isNewRegistration = false;
    _sessionExpired = false;
    notifyListeners();
    try {
      final tokens =
          await _authRepository.login(email: email, password: password);
      await ApiClient()
          .setTokens(access: tokens.access, refresh: tokens.refresh);
      _session = await _authRepository.fetchSession();
      _loading = false;
      notifyListeners();
    } catch (e) {
      _loading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> register({
    required String name,
    required String email,
    required String password,
  }) async {
    _loading = true;
    _isNewRegistration = true;
    _sessionExpired = false;
    notifyListeners();
    try {
      final tokens = await _authRepository.register(
        name: name,
        email: email,
        password: password,
      );
      await ApiClient()
          .setTokens(access: tokens.access, refresh: tokens.refresh);
      _session = await _authRepository.fetchSession();
      _loading = false;
      notifyListeners();
    } catch (e) {
      _loading = false;
      _isNewRegistration = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> refreshSession() async {
    if (!isAuthenticated) return;
    try {
      _session = await _authRepository.fetchSession();
      notifyListeners();
    } catch (e) {
      debugPrint('Error refreshing session: $e');
    }
  }

  void updateProfile(ProfileModel newProfile) {
    if (_session != null) {
      _session = SessionData(user: _session!.user, profile: newProfile);
      notifyListeners();
    }
  }

  Future<void> updateTargets({
    required int targetTps,
    required int targetRdr,
    required double targetIli,
  }) async {
    final profile = await _authRepository.updateTargets(
      payload: {
        'target_tps': targetTps,
        'target_rdr': targetRdr,
        'target_ili': targetIli,
      },
    );
    if (_session != null) {
      _session = SessionData(user: _session!.user, profile: profile);
      notifyListeners();
    }
  }

  Future<void> logout() async {
    await _authRepository.logout();
    _session = null;
    _isNewRegistration = false;
    _sessionExpired = false;
    notifyListeners();
  }

  void clearNewRegistrationFlag() {
    _isNewRegistration = false;
  }
}

class SessionScope extends InheritedNotifier<SessionController> {
  const SessionScope(
      {super.key, required SessionController controller, required super.child})
      : super(notifier: controller);

  static SessionController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<SessionScope>();
    assert(scope != null, 'SessionScope não encontrado no contexto');
    return scope!.notifier!;
  }
}

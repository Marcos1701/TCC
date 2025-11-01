import 'package:flutter/material.dart';

import '../models/profile.dart';
import '../models/session_data.dart';
import '../network/api_client.dart';
import '../repositories/auth_repository.dart';

class SessionController extends ChangeNotifier {
  SessionController({AuthRepository? authRepository})
      : _authRepository = authRepository ?? AuthRepository();

  final AuthRepository _authRepository;
  SessionData? _session;
  bool _loading = true;
  bool _bootstrapDone = false;

  SessionData? get session => _session;
  bool get isAuthenticated => _session != null;
  bool get isLoading => _loading;

  ProfileModel? get profile => _session?.profile;

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

  Future<bool> login({required String email, required String password}) async {
    _setLoading(true);
    try {
      final tokens =
          await _authRepository.login(email: email, password: password);
      await ApiClient()
          .setTokens(access: tokens.access, refresh: tokens.refresh);
      _session = await _authRepository.fetchSession();
      return true;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> register({
    required String name,
    required String email,
    required String password,
  }) async {
    _setLoading(true);
    try {
      final tokens = await _authRepository.register(
        name: name,
        email: email,
        password: password,
      );
      await ApiClient()
          .setTokens(access: tokens.access, refresh: tokens.refresh);
      _session = await _authRepository.fetchSession();
      return true;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> refreshSession() async {
    if (!isAuthenticated) return;
    _session = await _authRepository.fetchSession();
    notifyListeners();
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
    notifyListeners();
  }

  void _setLoading(bool value) {
    _loading = value;
    notifyListeners();
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

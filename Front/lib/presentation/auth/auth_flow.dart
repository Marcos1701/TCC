import 'package:flutter/material.dart';

import '../../core/services/cache_manager.dart';
import '../../core/state/session_controller.dart';
import '../../features/admin/presentation/admin_panel_page.dart';
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/auth/presentation/pages/register_page.dart';
import '../../features/onboarding/presentation/pages/simplified_onboarding_page.dart';
import '../shell/root_shell.dart';

class AuthFlow extends StatefulWidget {
  const AuthFlow({super.key});

  @override
  State<AuthFlow> createState() => _AuthFlowState();
}

class _AuthFlowState extends State<AuthFlow> {
  bool _showLogin = true;
  int _rootShellRebuildKey = 0;

  static bool _onboardingCheckedThisSession = false;
  static String? _lastUserIdChecked;
  static String?
      _lastAuthenticatedUserId;

  void _toggle() => setState(() => _showLogin = !_showLogin);

  static void resetOnboardingFlags() {
    _onboardingCheckedThisSession = false;
    _lastUserIdChecked = null;
  }

  Future<void> _checkAndShowOnboardingIfNeeded() async {
    final session = SessionScope.of(context);
    final currentUserId = session.session?.user.id.toString();

    if (currentUserId == null) return;

    final isAdmin = session.session?.user.isAdmin ?? false;
    if (isAdmin) return;

    if (_onboardingCheckedThisSession && _lastUserIdChecked == currentUserId) {
      return;
    }

    try {
      await session.refreshSession();

      if (session.session?.user.isAdmin ?? false) return;

      final isFirstAccess = session.profile?.isFirstAccess ?? false;

      if (mounted && isFirstAccess) {
        _onboardingCheckedThisSession = true;
        _lastUserIdChecked = currentUserId;

        final completed = await Navigator.of(context).push<bool>(
          MaterialPageRoute(
            builder: (context) => const SimplifiedOnboardingPage(),
            fullscreenDialog: true,
          ),
        );

        if (mounted) {
          CacheManager().invalidateAll();

          await session.refreshSession();

          if (completed == true) {
            setState(() {
              _rootShellRebuildKey++;
            });
          }
        }
      } else {
        _onboardingCheckedThisSession = true;
        _lastUserIdChecked = currentUserId;
      }

      if (mounted && session.isNewRegistration) {
        session.clearNewRegistrationFlag();
      }
    } catch (e) {
      debugPrint('❌ Erro ao verificar onboarding: $e');
      _onboardingCheckedThisSession = true;
      _lastUserIdChecked = currentUserId;
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: SessionScope.of(context),
      builder: (context, child) {
        final session = SessionScope.of(context);

        if (!session.bootstrapDone && session.isLoading) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (session.sessionExpired) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    '⏰ Sua sessão expirou. Por favor, faça login novamente.',
                    style: TextStyle(color: Colors.white),
                  ),
                  backgroundColor: Colors.orange,
                  duration: Duration(seconds: 4),
                ),
              );
              resetOnboardingFlags();
            }
          });
        }

        final currentUserId = session.session?.user.id.toString();
        if (_lastAuthenticatedUserId != null &&
            _lastAuthenticatedUserId != currentUserId) {
          resetOnboardingFlags();
        }
        _lastAuthenticatedUserId = currentUserId;

        if (session.isAuthenticated) {
          final isAdmin = session.session?.user.isAdmin ?? false;

          if (isAdmin) {
            return const AdminPanelPage();
          }

          if (session.isNewRegistration) {
            if (currentUserId != null && currentUserId != _lastUserIdChecked) {
              _onboardingCheckedThisSession = false;
              _lastUserIdChecked = null;
            }
          }

          WidgetsBinding.instance.addPostFrameCallback((_) {
            _checkAndShowOnboardingIfNeeded();
          });
          return RootShell(key: ValueKey('root_shell_$_rootShellRebuildKey'));
        }

        return child!;
      },
      child: IndexedStack(
        index: _showLogin ? 0 : 1,
        children: [
          LoginPage(key: const ValueKey('login'), onToggle: _toggle),
          RegisterPage(key: const ValueKey('register'), onToggle: _toggle),
        ],
      ),
    );
  }
}

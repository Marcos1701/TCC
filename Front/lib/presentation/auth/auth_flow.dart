import 'package:flutter/material.dart';

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
  final _rootShellKey = GlobalKey(); // Key para forçar rebuild da home
  
  // Controle de onboarding - persiste entre rebuilds
  static bool _onboardingCheckedThisSession = false;
  static String? _lastUserIdChecked;
  static String? _lastAuthenticatedUserId; // Rastreia último usuário autenticado

  void _toggle() => setState(() => _showLogin = !_showLogin);
  
  static void resetOnboardingFlags() {
    _onboardingCheckedThisSession = false;
    _lastUserIdChecked = null;
  }

  Future<void> _checkAndShowOnboardingIfNeeded() async {
    final session = SessionScope.of(context);
    final currentUserId = session.session?.user.id.toString();
    
    if (currentUserId == null) return;
    
    // Administradores não passam pelo onboarding
    final isAdmin = session.session?.user.isAdmin ?? false;
    if (isAdmin) return;
    
    if (_onboardingCheckedThisSession && _lastUserIdChecked == currentUserId) {
      return;
    }
    
    try {
      await session.refreshSession();
      
      // Verifica novamente após refresh se virou admin
      if (session.session?.user.isAdmin ?? false) return;
      
      final isFirstAccess = session.profile?.isFirstAccess ?? false;
      
      if (mounted && isFirstAccess) {
        _onboardingCheckedThisSession = true;
        _lastUserIdChecked = currentUserId;
        
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => const SimplifiedOnboardingPage(),
            fullscreenDialog: true,
          ),
        );
        
        if (mounted) {
          await session.refreshSession();
          
          setState(() {
            _rootShellKey.currentState?.setState(() {});
          });
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
    // NÃO limpa as flags static no dispose
    // As flags devem persistir durante toda a vida da aplicação
    // para evitar que o onboarding apareça múltiplas vezes
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: SessionScope.of(context),
      builder: (context, child) {
        final session = SessionScope.of(context);

        // Mostra loading apenas durante bootstrap
        if (!session.bootstrapDone && session.isLoading) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // Se a sessão expirou, mostra mensagem e redireciona para login
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
              // Reset das flags de onboarding ao expirar sessão
              resetOnboardingFlags();
            }
          });
        }

        // Detecta mudança de usuário autenticado (logout/login)
        final currentUserId = session.session?.user.id.toString();
        if (_lastAuthenticatedUserId != null && 
            _lastAuthenticatedUserId != currentUserId) {
          resetOnboardingFlags();
        }
        _lastAuthenticatedUserId = currentUserId;

        // Se autenticado, vai para a home ou painel admin
        if (session.isAuthenticated) {
          // PRIMEIRO: Verifica se é administrador - admins vão direto para o painel
          // sem passar pelo onboarding
          final isAdmin = session.session?.user.isAdmin ?? false;
          
          if (isAdmin) {
            // Admin vai direto para o painel administrativo
            return const AdminPanelPage();
          }
          
          // SEGUNDO: Apenas para usuários normais - verifica onboarding
          // Se for novo cadastro, permite nova verificação de onboarding
          if (session.isNewRegistration) {
            if (currentUserId != null && currentUserId != _lastUserIdChecked) {
              _onboardingCheckedThisSession = false;
              _lastUserIdChecked = null;
            }
          }
          
          // Verifica onboarding apenas uma vez por sessão do app (usuários normais)
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _checkAndShowOnboardingIfNeeded();
          });
          return RootShell(key: _rootShellKey);
        }

        // Retorna o child que contém as páginas de auth
        return child!;
      },
      // Child não é reconstruído, apenas o AnimatedBuilder
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

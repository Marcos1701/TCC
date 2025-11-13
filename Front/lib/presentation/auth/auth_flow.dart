import 'package:flutter/material.dart';

import '../../core/state/session_controller.dart';
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/auth/presentation/pages/register_page.dart';
import '../../features/onboarding/presentation/pages/simplified_onboarding_page.dart';
import '../../features/admin/presentation/pages/admin_dashboard_page.dart';
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
  
  /// Reseta as flags de onboarding quando necessário (ex: logout)
  static void resetOnboardingFlags() {
    debugPrint('🔄 Resetando flags de onboarding');
    _onboardingCheckedThisSession = false;
    _lastUserIdChecked = null;
  }

  Future<void> _checkAndShowOnboardingIfNeeded() async {
    final session = SessionScope.of(context);
    final currentUserId = session.session?.user.id.toString();
    
    // Se não há usuário autenticado, retorna
    if (currentUserId == null) return;
    
    // Se já verificou para este usuário nesta sessão do app, não verifica novamente
    if (_onboardingCheckedThisSession && _lastUserIdChecked == currentUserId) {
      debugPrint('ℹ️ Onboarding já verificado para este usuário nesta sessão');
      return;
    }
    
    try {
      // Atualiza a sessão para garantir dados mais recentes
      await session.refreshSession();
      
      // Verifica se é o primeiro acesso
      final isFirstAccess = session.profile?.isFirstAccess ?? false;
      
      debugPrint('🔍 Verificando primeiro acesso: isFirstAccess=$isFirstAccess, userId=$currentUserId');
      
      if (mounted && isFirstAccess) {
        debugPrint('🎯 É primeiro acesso! Exibindo onboarding...');
        
        // Marca como verificado ANTES de mostrar o onboarding
        // para evitar que apareça múltiplas vezes se houver rebuilds
        _onboardingCheckedThisSession = true;
        _lastUserIdChecked = currentUserId;
        
        // Primeira vez que o usuário acessa - mostra setup inicial simplificado
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => const SimplifiedOnboardingPage(),
            fullscreenDialog: true,
          ),
        );
        
        // APÓS o Navigator.pop, atualiza a sessão e força rebuild
        if (mounted) {
          debugPrint('✅ Onboarding concluído/pulado - atualizando sessão');
          
          // Atualiza a sessão para pegar o novo valor de isFirstAccess
          await session.refreshSession();
          
          // Verifica se a sessão foi atualizada corretamente
          final updatedFirstAccess = session.profile?.isFirstAccess ?? true;
          debugPrint('✅ Sessão atualizada - novo isFirstAccess: $updatedFirstAccess');
          
          if (updatedFirstAccess) {
            debugPrint('⚠️ ATENÇÃO: isFirstAccess ainda está true após refresh!');
          }
          
          // Força rebuild completo
          setState(() {
            // Força recriação do RootShell com nova key
            _rootShellKey.currentState?.setState(() {});
          });
        }
      } else {
        debugPrint('ℹ️ Não é primeiro acesso, continuando normalmente');
        // Marca como verificado para este usuário
        _onboardingCheckedThisSession = true;
        _lastUserIdChecked = currentUserId;
      }
      
      // Reseta a flag de novo registro após verificar onboarding
      if (mounted && session.isNewRegistration) {
        session.clearNewRegistrationFlag();
      }
    } catch (e) {
      // Se houver erro, marca como verificado para evitar loops
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
          // Usuário mudou (fez logout e/ou login com outra conta)
          debugPrint('🔄 Usuário mudou de $_lastAuthenticatedUserId para $currentUserId - resetando flags');
          resetOnboardingFlags();
        }
        _lastAuthenticatedUserId = currentUserId;

        // Se autenticado, vai para a home
        if (session.isAuthenticated) {
          // Verifica se é admin
          final isAdmin = session.session?.user.isAdmin ?? false;
          
          // Se for admin, vai direto para o painel administrativo
          if (isAdmin) {
            return const AdminDashboardPage();
          }
          
          // Se for novo cadastro, permite nova verificação de onboarding
          if (session.isNewRegistration) {
            if (currentUserId != null && currentUserId != _lastUserIdChecked) {
              _onboardingCheckedThisSession = false;
              _lastUserIdChecked = null;
            }
          }
          
          // Verifica onboarding apenas uma vez por sessão do app
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

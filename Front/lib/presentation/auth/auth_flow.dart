import 'package:flutter/material.dart';

import '../../core/state/session_controller.dart';
import '../../core/repositories/finance_repository.dart';
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/auth/presentation/pages/register_page.dart';
import '../../features/onboarding/presentation/pages/initial_setup_page.dart';
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
  final _repository = FinanceRepository();
  
  // Controle de onboarding - persiste entre rebuilds
  static bool _onboardingCheckedThisSession = false;
  static String? _lastUserIdChecked;

  void _toggle() => setState(() => _showLogin = !_showLogin);

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
        
        // Primeira vez que o usuário acessa - mostra setup inicial
        final result = await Navigator.of(context).push<bool>(
          MaterialPageRoute(
            builder: (context) => InitialSetupPage(
              onComplete: () async {
                
                
                // Marca como primeiro acesso concluído na API
                try {
                  await _repository.completeFirstAccess();
                  debugPrint('✅ Primeiro acesso marcado como concluído na API');
                } catch (e) {
                  debugPrint('❌ Erro ao marcar primeiro acesso: $e');
                }
                
                // Força rebuild da home após conclusão
                if (mounted) {
                  await session.refreshSession();
                  debugPrint('✅ Sessão atualizada após conclusão');
                  setState(() {
                    // Força recriação do RootShell com nova key
                    _rootShellKey.currentState?.setState(() {});
                  });
                }
              },
            ),
            fullscreenDialog: true,
          ),
        );
        
        // Se completou com sucesso, força rebuild
        if (result == true && mounted) {
          setState(() {
            // Força rebuild do widget tree
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
    // Limpa as flags static ao destruir o widget
    // Isso permite que um novo usuário tenha seu onboarding verificado
    _onboardingCheckedThisSession = false;
    _lastUserIdChecked = null;
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
            final currentUserId = session.session?.user.id.toString();
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

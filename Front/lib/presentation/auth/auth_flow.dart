import 'package:flutter/material.dart';

import '../../core/state/session_controller.dart';
import '../../core/repositories/finance_repository.dart';
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/auth/presentation/pages/register_page.dart';
import '../../features/onboarding/presentation/pages/initial_setup_page.dart';
import '../shell/root_shell.dart';

class AuthFlow extends StatefulWidget {
  const AuthFlow({super.key});

  @override
  State<AuthFlow> createState() => _AuthFlowState();
}

class _AuthFlowState extends State<AuthFlow> {
  bool _showLogin = true;
  bool _onboardingAlreadyChecked = false; // Flag para verificar apenas uma vez
  final _rootShellKey = GlobalKey(); // Key para forçar rebuild da home
  final _repository = FinanceRepository();

  void _toggle() => setState(() => _showLogin = !_showLogin);

  Future<void> _checkAndShowOnboardingIfNeeded() async {
    // Se já verificou nesta sessão do app, não verifica novamente
    // Isso evita que o onboarding apareça múltiplas vezes durante a mesma sessão
    if (_onboardingAlreadyChecked) return;
    
    _onboardingAlreadyChecked = true;
    
    try {
      final session = SessionScope.of(context);
      
      // Verifica se é o primeiro acesso usando a informação vinda da API
      // Esta informação está no perfil do usuário
      final isFirstAccess = session.profile?.isFirstAccess ?? false;
      
      debugPrint('🔍 Verificando primeiro acesso: isFirstAccess=$isFirstAccess');
      
      if (mounted && isFirstAccess) {
        debugPrint('🎯 É primeiro acesso! Exibindo onboarding...');
        
        // Marca imediatamente como não sendo mais primeiro acesso
        // Isso garante que mesmo se o usuário pular, não verá novamente
        try {
          await _repository.completeFirstAccess();
          debugPrint('✅ Primeiro acesso marcado como concluído na API');
          // Atualiza o perfil local para refletir a mudança
          await session.refreshSession();
        } catch (e) {
          debugPrint('❌ Erro ao marcar primeiro acesso: $e');
        }
        
        // Primeira vez que o usuário acessa - mostra setup inicial
        final result = await Navigator.of(context).push<bool>(
          MaterialPageRoute(
            builder: (context) => InitialSetupPage(
              onComplete: () async {
                debugPrint('✅ Onboarding completo, transações criadas');
                
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
      }
      
      // Reseta a flag de novo registro após verificar onboarding
      if (mounted && session.isNewRegistration) {
        session.clearNewRegistrationFlag();
      }
    } catch (e) {
      // Se houver erro, apenas continua sem mostrar onboarding
      debugPrint('❌ Erro ao verificar onboarding: $e');
    }
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
          // Se for novo cadastro, reseta a flag para permitir verificação
          if (session.isNewRegistration && _onboardingAlreadyChecked) {
            _onboardingAlreadyChecked = false;
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

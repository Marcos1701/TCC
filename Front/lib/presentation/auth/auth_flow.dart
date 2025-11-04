import 'package:flutter/material.dart';

import '../../core/state/session_controller.dart';
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/auth/presentation/pages/register_page.dart';
import '../shell/root_shell.dart';

class AuthFlow extends StatefulWidget {
  const AuthFlow({super.key});

  @override
  State<AuthFlow> createState() => _AuthFlowState();
}

class _AuthFlowState extends State<AuthFlow> {
  bool _showLogin = true;

  void _toggle() => setState(() => _showLogin = !_showLogin);

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
          return const RootShell();
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

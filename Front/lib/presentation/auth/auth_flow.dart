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
    final session = SessionScope.of(context);

    if (session.isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (session.isAuthenticated) {
      return const RootShell();
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 350),
      child: _showLogin
          ? LoginPage(
              key: const ValueKey('login'),
              onToggle: _toggle,
            )
          : RegisterPage(
              key: const ValueKey('register'),
              onToggle: _toggle,
            ),
    );
  }
}

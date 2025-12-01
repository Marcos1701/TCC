import 'package:flutter/material.dart';
import 'core/state/session_controller.dart';
import 'core/repositories/auth_repository.dart';
import 'core/theme/app_theme.dart';
import 'presentation/auth/auth_flow.dart';

class GenApp extends StatefulWidget {
  const GenApp({
    super.key,
    this.theme,
    this.darkTheme,
    this.authRepository,
  });

  final ThemeData? theme;
  final ThemeData? darkTheme;
  final AuthRepository? authRepository;

  @override
  State<GenApp> createState() => _GenAppState();
}

class _GenAppState extends State<GenApp> {
  late final SessionController _sessionController;

  @override
  void initState() {
    super.initState();
    _sessionController = SessionController(authRepository: widget.authRepository)
      ..bootstrap();
  }

  @override
  void dispose() {
    _sessionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SessionScope(
      controller: _sessionController,
      child: MaterialApp(
        title: 'GenApp - Gestão Financeira',
        theme: widget.theme ?? AppTheme.dark,
        darkTheme: widget.darkTheme ?? AppTheme.dark,
        themeMode: ThemeMode.dark,
        debugShowCheckedModeBanner: false,
        home: const AuthFlow(),
      ),
    );
  }
}

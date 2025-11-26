import 'package:flutter/material.dart';
import 'core/state/session_controller.dart';
import 'core/theme/app_theme.dart';
import 'presentation/auth/auth_flow.dart';

class GenApp extends StatefulWidget {
  const GenApp({super.key});

  @override
  State<GenApp> createState() => _GenAppState();
}

class _GenAppState extends State<GenApp> {
  late final SessionController _sessionController = SessionController()
    ..bootstrap();

  @override
  Widget build(BuildContext context) {
    return SessionScope(
      controller: _sessionController,
      child: MaterialApp(
        title: 'GenApp - Gestão Financeira',
        theme: AppTheme.dark,
        darkTheme: AppTheme.dark,
        themeMode: ThemeMode.dark,
        debugShowCheckedModeBanner: false,
        home: const AuthFlow(),
      ),
    );
  }
}

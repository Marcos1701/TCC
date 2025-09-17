import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'presentation/shell/root_shell.dart';

/// Root widget for the GenApp application.
///
/// This widget is responsible for providing the [MaterialApp] configuration
/// shared by the whole project, such as the application theme and navigation
/// shell. Future integrations (routing, dependency injection, localization)
/// should be added here to keep the `main.dart` file lightweight.
class GenApp extends StatelessWidget {
  const GenApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GenApp',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      debugShowCheckedModeBanner: false,
      home: const RootShell(),
    );
  }
}

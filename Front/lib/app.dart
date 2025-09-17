import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'presentation/shell/root_shell.dart';

/// Widget raiz do app.
///
/// Aqui a gente concentra o `MaterialApp`, tema e casca de navegação pra
/// manter o `main.dart` enxuto e pronto pra receber rotas, injeção de
/// dependência e afins.
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

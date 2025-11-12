import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme_extension.dart';
import '../../core/constants/user_friendly_strings.dart';
import '../../features/home/presentation/pages/home_page.dart';
import '../../features/home/presentation/pages/finances_page.dart';
import '../../features/home/presentation/pages/profile_page.dart';

class _NavigationItem {
  const _NavigationItem({
    required this.label,
    required this.icon,
    required this.builder,
  });

  final String label;
  final IconData icon;
  final Widget Function() builder;
}

class RootShell extends StatefulWidget {
  const RootShell({super.key});

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  int _currentIndex = 0;
  DateTime? _lastBackPress;

  final List<_NavigationItem> _items = [
    const _NavigationItem(
      label: UxStrings.home,
      icon: Icons.home_rounded,
      builder: HomePage.new,
    ),
    const _NavigationItem(
      label: UxStrings.finances,
      icon: Icons.account_balance_wallet_rounded,
      builder: FinancesPage.new,
    ),
    const _NavigationItem(
      label: UxStrings.profile,
      icon: Icons.person_rounded,
      builder: ProfilePage.new,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.extension<AppDecorations>()!;
    final isDark = theme.brightness == Brightness.dark;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        
        // Se não estiver na primeira aba (Home), volta para ela
        if (_currentIndex != 0) {
          setState(() => _currentIndex = 0);
          return;
        }
        
        // Se estiver na Home, implementa double-tap to exit
        final now = DateTime.now();
        if (_lastBackPress == null || 
            now.difference(_lastBackPress!) > const Duration(seconds: 2)) {
          _lastBackPress = now;
          
          // Mostra um SnackBar avisando
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Pressione voltar novamente para sair'),
                duration: Duration(seconds: 2),
              ),
            );
          }
        } else {
          // Segundo tap dentro de 2 segundos - sai do app
          _lastBackPress = null;
          await SystemChannels.platform.invokeMethod('SystemNavigator.pop');
        }
      },
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: SafeArea(
          bottom: false,
          child: IndexedStack(
            index: _currentIndex,
            children: _items
                .map(
                  (item) => KeyedSubtree(
                    key: PageStorageKey(item.label),
                    child: item.builder(),
                  ),
                )
                .toList(),
          ),
        ),
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.vertical(top: tokens.sheetRadius.topLeft),
            border: Border.all(color: theme.dividerColor),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.34 : 0.2),
                blurRadius: 24,
                offset: const Offset(0, -6),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: BottomNavigationBar(
              type: BottomNavigationBarType.fixed,
              backgroundColor: Colors.transparent,
              selectedItemColor: AppColors.primary,
              unselectedItemColor: AppColors.textSecondary,
              showUnselectedLabels: true,
              currentIndex: _currentIndex,
              onTap: (index) => setState(() => _currentIndex = index),
              items: _items
                  .map(
                    (item) => BottomNavigationBarItem(
                      icon: Icon(item.icon),
                      label: item.label,
                    ),
                  )
                  .toList(),
            ),
          ),
        ),
      ),
    );
  }
}

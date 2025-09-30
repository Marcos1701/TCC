import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../features/home/presentation/pages/home_page.dart';
import '../../features/missions/presentation/pages/missions_page.dart';
import '../../features/progress/presentation/pages/progress_page.dart';
import '../../features/profile/presentation/pages/profile_page.dart';
import '../../features/transactions/presentation/pages/transactions_page.dart';

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

  final List<_NavigationItem> _items = [
    const _NavigationItem(
      label: 'Home',
      icon: Icons.home_rounded,
      builder: HomePage.new,
    ),
    const _NavigationItem(
      label: 'Transações',
      icon: Icons.swap_vert_rounded,
      builder: TransactionsPage.new,
    ),
    const _NavigationItem(
      label: 'Missões',
      icon: Icons.videogame_asset_rounded,
      builder: MissionsPage.new,
    ),
    const _NavigationItem(
      label: 'Progresso',
      icon: Icons.flag_rounded,
      builder: ProgressPage.new,
    ),
    const _NavigationItem(
      label: 'Perfil',
      icon: Icons.person_rounded,
      builder: ProfilePage.new,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: IndexedStack(
          index: _currentIndex,
          children: _items
              .map(
                (item) => KeyedSubtree(
                  key: PageStorageKey(item.label),
                  child: Container(
                    color: AppColors.background,
                    child: item.builder(),
                  ),
                ),
              )
              .toList(),
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 20,
              offset: const Offset(0, -4),
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
    );
  }
}

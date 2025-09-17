import 'package:flutter/material.dart';

import '../../features/dashboard/presentation/pages/dashboard_page.dart';
import '../../features/missions/presentation/pages/missions_page.dart';
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
  final WidgetBuilder builder;
}

/// Casca principal que cuida das abas do app.
///
/// O relatório fala das quatro frentes básicas (dashboard, transações, missões
/// e perfil) e aqui a gente amarra tudo num `BottomNavigationBar`, deixando um
/// ponto único pra encaixar ações globais no futuro.
class RootShell extends StatefulWidget {
  const RootShell({super.key});

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  int _currentIndex = 0;

  final List<_NavigationItem> _items = const [
    _NavigationItem(
      label: 'Visão Geral',
      icon: Icons.dashboard_outlined,
      builder: DashboardPage.new,
    ),
    _NavigationItem(
      label: 'Transações',
      icon: Icons.receipt_long_outlined,
      builder: TransactionsPage.new,
    ),
    _NavigationItem(
      label: 'Missões',
      icon: Icons.emoji_events_outlined,
      builder: MissionsPage.new,
    ),
    _NavigationItem(
      label: 'Perfil',
      icon: Icons.person_outline,
      builder: ProfilePage.new,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_items[_currentIndex].label),
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: _items
            .map((item) => KeyedSubtree(
                  key: PageStorageKey(item.label),
                  child: item.builder(context),
                ))
            .toList(),
      ),
      bottomNavigationBar: BottomNavigationBar(
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
    );
  }
}

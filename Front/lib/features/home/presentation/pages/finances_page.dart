import 'package:flutter/material.dart';

import '../../../progress/presentation/pages/progress_page.dart';
import '../../../tracking/presentation/pages/tracking_page.dart';
import '../../../transactions/presentation/pages/transactions_page.dart';

/// Página de Finanças Unificada (Dia 8-10)
/// Combina Transações + Análises + Metas em tabs internas
/// Simplifica navegação de 5 para 3 abas principais
class FinancesPage extends StatefulWidget {
  const FinancesPage({super.key});

  @override
  State<FinancesPage> createState() => _FinancesPageState();
}

class _FinancesPageState extends State<FinancesPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text('Finanças'),
        backgroundColor: const Color(0xFF1E1E1E),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.purple,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.grey[400],
          tabs: const [
            Tab(
              icon: Icon(Icons.swap_vert_rounded),
              text: 'Transações',
            ),
            Tab(
              icon: Icon(Icons.analytics_rounded),
              text: 'Análises',
            ),
            Tab(
              icon: Icon(Icons.flag_rounded),
              text: 'Metas',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          // Tab 1: Transações
          TransactionsPage(),

          // Tab 2: Análises
          TrackingPage(),

          // Tab 3: Metas
          ProgressPage(),
        ],
      ),
    );
  }
}

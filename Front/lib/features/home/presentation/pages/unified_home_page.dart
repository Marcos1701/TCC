import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/models/dashboard.dart';
import '../../../../core/repositories/finance_repository.dart';
import '../../../../core/services/analytics_service.dart';
import '../../../../core/services/feedback_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../missions/presentation/pages/missions_page.dart';
import '../widgets/day4_5_widgets.dart';

class UnifiedHomePage extends StatefulWidget {
  const UnifiedHomePage({super.key});

  @override
  State<UnifiedHomePage> createState() => _UnifiedHomePageState();
}

class _UnifiedHomePageState extends State<UnifiedHomePage> {
  final FinanceRepository _repository = FinanceRepository();
  final NumberFormat _currency = NumberFormat.currency(
    locale: 'pt_BR',
    symbol: 'R\$',
  );

  bool _isLoading = true;
  DashboardData? _data;
  String? _error;

  @override
  void initState() {
    super.initState();
    AnalyticsService.trackScreenView('unified_home');
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final data = await _repository.fetchDashboard();
      if (mounted) {
        setState(() {
          _data = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _refresh() async {
    await _loadData();
    if (mounted) {
      FeedbackService.showSuccess(
        context,
        'Dados atualizados com sucesso.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text('Início'),
        backgroundColor: const Color(0xFF1E1E1E),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refresh,
            tooltip: 'Atualizar',
          ),
        ],
      ),
      body: _buildBody(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openTransactionSheet,
        icon: const Icon(Icons.add),
        label: const Text('Nova transação'),
        backgroundColor: AppColors.primary,
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            const Text(
              'Erro ao carregar dados',
              style: TextStyle(fontSize: 18, color: Colors.white),
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              style: TextStyle(color: Colors.grey[400]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loadData,
              child: const Text('Tentar novamente'),
            ),
          ],
        ),
      );
    }

    if (_data == null) {
      return const Center(
        child: Text('Nenhum dado disponível'),
      );
    }

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          MonthSummaryCard(
            summary: _data!.summary,
            currency: _currency,
          ),
          const SizedBox(height: 16),

          if (_data!.activeMissions.isNotEmpty) ...[
            WeeklyChallengeCard(
              mission: _data!.activeMissions.first,
              onTap: () => _navigateToMissions(context),
            ),
            const SizedBox(height: 16),
          ],

          if (_data!.activeMissions.isNotEmpty)
            _buildViewAllChallengesButton(),
          const SizedBox(height: 16),

          QuickActionsCard(
            onAddTransaction: _openTransactionSheet,
            onViewAnalysis: () => _navigateToAnalysis(context),
          ),
          const SizedBox(height: 16),

          RecentTransactionsSection(
            repository: _repository,
            currency: _currency,
            onViewAll: () => _navigateToTransactions(context),
          ),
          
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildViewAllChallengesButton() {
    return Card(
      color: Colors.deepPurple[900]?.withOpacity(0.3),
      child: InkWell(
        onTap: () => _navigateToMissions(context),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.emoji_events,
                color: Colors.amber,
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                'Ver todos os desafios (${_data!.activeMissions.length})',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.arrow_forward_ios,
                color: Colors.white70,
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openTransactionSheet() {
    FeedbackService.showInfo(
      context,
      '💡 Sheet de transação será implementado',
    );
  }

  void _navigateToMissions(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const MissionsPage()),
    );
  }


  void _navigateToAnalysis(BuildContext context) {
    FeedbackService.showInfo(
      context,
      '💡 Análises estão na aba Finanças',
    );
  }

  void _navigateToTransactions(BuildContext context) {
    FeedbackService.showInfo(
      context,
      '💡 Transações estão na aba Finanças',
    );
  }
}

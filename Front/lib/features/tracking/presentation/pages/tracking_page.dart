import 'package:flutter/material.dart';

import '../../../../core/constants/user_friendly_strings.dart';
import '../../../../core/models/dashboard.dart';
import '../../../../core/repositories/finance_repository.dart';
import '../../../../core/services/cache_manager.dart';
import '../../../../core/theme/app_colors.dart';
import '../widgets/tracking_widgets.dart';

/// Página de Análise Financeira.
///
/// Exibe gráficos e métricas sobre a situação financeira do usuário:
/// - Resumo do período (receitas, despesas, saldo)
/// - Evolução temporal (gráfico de linha)
/// - Saldo mensal (gráfico de barras)
/// - Distribuição por categoria (gráfico de pizza)
class TrackingPage extends StatefulWidget {
  const TrackingPage({super.key});

  @override
  State<TrackingPage> createState() => _TrackingPageState();
}

class _TrackingPageState extends State<TrackingPage> {
  final _repository = FinanceRepository();
  final _cacheManager = CacheManager();
  late Future<DashboardData> _dashboardFuture;

  @override
  void initState() {
    super.initState();
    _dashboardFuture = _repository.fetchDashboard();
    _cacheManager.addListener(_onCacheInvalidated);
  }

  @override
  void dispose() {
    _cacheManager.removeListener(_onCacheInvalidated);
    super.dispose();
  }

  void _onCacheInvalidated() {
    if (_cacheManager.isInvalidated(CacheType.dashboard) ||
        _cacheManager.isInvalidated(CacheType.transactions)) {
      _refresh();
      _cacheManager.clearInvalidation(CacheType.dashboard);
      _cacheManager.clearInvalidation(CacheType.transactions);
    }
  }

  Future<void> _refresh() async {
    setState(() {
      _dashboardFuture = _repository.fetchDashboard();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: Text(
          UxStrings.analysis,
          style: theme.textTheme.titleLarge?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: false,
        automaticallyImplyLeading: true,
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: _refresh,
        child: FutureBuilder<DashboardData>(
          future: _dashboardFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation(AppColors.primary),
                ),
              );
            }

            if (snapshot.hasError) {
              return _ErrorState(onRetry: _refresh);
            }

            if (!snapshot.hasData) {
              return const _EmptyState();
            }

            return _TrackingContent(data: snapshot.data!);
          },
        ),
      ),
    );
  }
}

/// Conteúdo principal da página de análise.
class _TrackingContent extends StatelessWidget {
  const _TrackingContent({required this.data});

  final DashboardData data;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
      children: [
        SummaryCard(summary: data.summary),
        const SizedBox(height: 24),
        CashflowChart(cashflow: data.cashflow),
        const SizedBox(height: 24),
        BalanceChart(cashflow: data.cashflow),
        const SizedBox(height: 24),
        if (data.categories.isNotEmpty)
          _CategoryDistribution(categories: data.categories),
      ],
    );
  }
}

/// Seção de distribuição por categoria.
class _CategoryDistribution extends StatelessWidget {
  const _CategoryDistribution({required this.categories});

  final Map<String, List<CategorySlice>> categories;

  @override
  Widget build(BuildContext context) {
    final expenses = categories['EXPENSE'] ?? [];
    final income = categories['INCOME'] ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (expenses.isNotEmpty) ...[
          CategoryPieChart(
            title: '${UxStrings.expense} por Categoria',
            slices: expenses,
            baseColor: AppColors.alert,
          ),
          const SizedBox(height: 24),
        ],
        if (income.isNotEmpty) ...[
          CategoryPieChart(
            title: '${UxStrings.income} por Categoria',
            slices: income,
            baseColor: AppColors.success,
          ),
        ],
      ],
    );
  }
}

/// Estado de erro da página.
class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.error_outline,
            size: 64,
            color: AppColors.alert,
          ),
          const SizedBox(height: 16),
          Text(
            'Erro ao carregar dados',
            style: theme.textTheme.titleLarge?.copyWith(
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Toque para tentar novamente',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.grey[500],
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text(UxStrings.tryAgain),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Estado vazio da página.
class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.inbox_outlined,
            size: 64,
            color: Colors.grey,
          ),
          const SizedBox(height: 16),
          Text(
            UxStrings.noData,
            style: theme.textTheme.titleLarge?.copyWith(
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Adicione transações para ver suas análises',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../../../core/constants/user_friendly_strings.dart';
import '../../../../core/models/analytics.dart';
import '../../../../core/models/dashboard.dart';
import '../../../../core/repositories/finance_repository.dart';
import '../../../../core/services/cache_manager.dart';
import '../../../../core/theme/app_colors.dart';
import '../widgets/tracking_widgets.dart';

class TrackingPage extends StatefulWidget {
  const TrackingPage({super.key});

  @override
  State<TrackingPage> createState() => _TrackingPageState();
}

class _TrackingPageState extends State<TrackingPage> {
  final _repository = FinanceRepository();
  final _cacheManager = CacheManager();
  late Future<_TrackingData> _dataFuture;

  @override
  void initState() {
    super.initState();
    _dataFuture = _loadData();
    _cacheManager.addListener(_onCacheInvalidated);
  }

  @override
  void dispose() {
    _cacheManager.removeListener(_onCacheInvalidated);
    super.dispose();
  }

  Future<_TrackingData> _loadData() async {
    final dashboard = await _repository.fetchDashboard();
    
    AnalyticsData? analytics;
    try {
      analytics = await _repository.fetchAnalytics();
    } catch (_) {
      // Analytics is optional, continue without it
    }
    
    return _TrackingData(
      dashboard: dashboard,
      analytics: analytics,
    );
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
      _dataFuture = _loadData();
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
        child: FutureBuilder<_TrackingData>(
          future: _dataFuture,
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

class _TrackingData {
  final DashboardData dashboard;
  final AnalyticsData? analytics;

  const _TrackingData({required this.dashboard, this.analytics});
}

class _TrackingContent extends StatelessWidget {
  const _TrackingContent({required this.data});

  final _TrackingData data;

  @override
  Widget build(BuildContext context) {
    final analytics = data.analytics;
    final dashboard = data.dashboard;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
      children: [
        // Profile Scorecard (Gamification)
        if (analytics != null) ...[
          ProfileScorecard(tier: analytics.comprehensiveContext.tier),
          const SizedBox(height: 24),
        ],

        // Financial Health Indicators (TPS, RDR, ILI)
        if (analytics != null) ...[
          FinancialHealthIndicators(
            tps: analytics.comprehensiveContext.currentIndicators['tps'] ?? 0.0,
            rdr: analytics.comprehensiveContext.currentIndicators['rdr'] ?? 0.0,
            ili: analytics.comprehensiveContext.currentIndicators['ili'] ?? 0.0,
          ),
          const SizedBox(height: 24),
        ],

        // Summary Card (fallback if no analytics)
        if (analytics == null) ...[
          SummaryCard(summary: dashboard.summary),
          const SizedBox(height: 24),
        ],

        // Cashflow Chart
        CashflowChart(cashflow: dashboard.cashflow),
        const SizedBox(height: 24),

        // Balance Chart
        BalanceChart(cashflow: dashboard.cashflow),
        const SizedBox(height: 24),

        // Category Distribution
        if (dashboard.categories.isNotEmpty)
          _CategoryDistribution(categories: dashboard.categories),
      ],
    );
  }
}

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

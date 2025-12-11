import 'package:flutter/foundation.dart';
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

    String? analyticsError;
    AnalyticsData? analytics;
    try {
      analytics = await _repository.fetchAnalytics();
    } catch (e) {
      analyticsError = e.toString();
    }

    return _TrackingData(
      dashboard: dashboard,
      analytics: analytics,
      analyticsError: analyticsError,
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
  final String? analyticsError;

  const _TrackingData({
    required this.dashboard,
    this.analytics,
    this.analyticsError,
  });
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
        // Summary Card (Always Visible)
        SummaryCard(summary: dashboard.summary),
        const SizedBox(height: 24),

        // Profile Scorecard (Gamification) - If available
        if (analytics != null) ...[
          ProfileScorecard(tier: analytics.comprehensiveContext.tier),
          const SizedBox(height: 24),
        ],

        // Financial Health Indicators (TPS, RDR, ILI) - If available
        if (analytics != null) ...[
          FinancialHealthIndicators(
            tps: analytics.comprehensiveContext.currentIndicators['tps'] ?? 0.0,
            rdr: analytics.comprehensiveContext.currentIndicators['rdr'] ?? 0.0,
            ili: analytics.comprehensiveContext.currentIndicators['ili'] ?? 0.0,
          ),
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

class _CategoryDistribution extends StatefulWidget {
  const _CategoryDistribution({required this.categories});

  final Map<String, List<CategorySlice>> categories;

  @override
  State<_CategoryDistribution> createState() => _CategoryDistributionState();
}

class _CategoryDistributionState extends State<_CategoryDistribution> {
  String _selectedType = 'EXPENSE';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final expenses = widget.categories['EXPENSE'] ?? [];
    final income = widget.categories['INCOME'] ?? [];
    final aportes = widget.categories['APORTES'] ?? [];

    if (kDebugMode) {
      debugPrint('📊 CategoryDistribution: Categorias recebidas:');
      debugPrint('  - EXPENSE: ${expenses.length} itens');
      debugPrint('  - INCOME: ${income.length} itens');
      debugPrint('  - APORTES: ${aportes.length} itens');
      debugPrint('  - Chaves disponíveis: ${widget.categories.keys.toList()}');
    }

    // Determine available tabs based on data
    final availableTabs = <String, String>{};
    if (income.isNotEmpty) availableTabs['INCOME'] = 'Receitas';
    if (expenses.isNotEmpty) availableTabs['EXPENSE'] = 'Despesas';
    if (aportes.isNotEmpty) availableTabs['APORTES'] = 'Aportes';

    // Default to first available if current selection has no data
    if (!availableTabs.containsKey(_selectedType) && availableTabs.isNotEmpty) {
      _selectedType = availableTabs.keys.first;
    }

    if (availableTabs.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Tab Selector
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white12),
          ),
          child: Row(
            children: availableTabs.entries.map((entry) {
              final isSelected = _selectedType == entry.key;
              final color = _getColorForType(entry.key);
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _selectedType = entry.key),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? color.withOpacity(0.2)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: isSelected
                          ? Border.all(color: color.withOpacity(0.5))
                          : null,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _getIconForType(entry.key),
                          size: 16,
                          color: isSelected ? color : Colors.grey[500],
                        ),
                        const SizedBox(width: 6),
                        Text(
                          entry.value,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: isSelected ? color : Colors.grey[500],
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 16),
        // Selected Chart
        _buildSelectedChart(),
      ],
    );
  }

  Color _getColorForType(String type) {
    switch (type) {
      case 'EXPENSE':
        return AppColors.alert;
      case 'APORTES':
        return AppColors.primary;
      case 'INCOME':
        return AppColors.success;
      default:
        return Colors.grey;
    }
  }

  IconData _getIconForType(String type) {
    switch (type) {
      case 'EXPENSE':
        return Icons.payments_rounded;
      case 'APORTES':
        return Icons.savings_rounded;
      case 'INCOME':
        return Icons.account_balance_wallet_rounded;
      default:
        return Icons.pie_chart;
    }
  }

  String _getTitleForType(String type) {
    switch (type) {
      case 'EXPENSE':
        return '${UxStrings.expense} por Categoria';
      case 'APORTES':
        return 'Aportes por Categoria';
      case 'INCOME':
        return '${UxStrings.income} por Categoria';
      default:
        return 'Distribuição por Categoria';
    }
  }

  Widget _buildSelectedChart() {
    final slices = widget.categories[_selectedType] ?? [];
    if (slices.isEmpty) {
      return const SizedBox.shrink();
    }
    return CategoryPieChart(
      title: _getTitleForType(_selectedType),
      slices: slices,
      baseColor: _getColorForType(_selectedType),
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

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/user_friendly_strings.dart';
import '../../../../core/models/dashboard.dart';
import '../../../../core/repositories/finance_repository.dart';
import '../../../../core/services/cache_manager.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme_extension.dart';

/// Página de Análise Financeira
/// 
/// Exibe análise temporal de receitas e despesas com gráficos interativos
class TrackingPage extends StatefulWidget {
  const TrackingPage({super.key});

  @override
  State<TrackingPage> createState() => _TrackingPageState();
}

class _TrackingPageState extends State<TrackingPage> {
  final _repository = FinanceRepository();
  final _cacheManager = CacheManager();
  late Future<DashboardData> _dashboardFuture;
  int _touchedExpenseIndex = -1;
  int _touchedIncomeIndex = -1;
  
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
    final tokens = theme.extension<AppDecorations>()!;

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
              return _buildErrorState(theme);
            }

            if (!snapshot.hasData) {
              return _buildEmptyState(theme);
            }

            final data = snapshot.data!;
            return _buildContent(context, data, theme, tokens);
          },
        ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    DashboardData data,
    ThemeData theme,
    AppDecorations tokens,
  ) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
      children: [
        // Resumo Geral
        _buildSummaryCard(data.summary, theme, tokens),
        const SizedBox(height: 24),

        // Gráfico de Evolução Temporal
        _buildCashflowChart(data.cashflow, theme, tokens),
        const SizedBox(height: 24),

        // Gráfico de Saldo Mensal
        _buildBalanceChart(data.cashflow, theme, tokens),
        const SizedBox(height: 24),

        // Distribuição por Categoria
        if (data.categories.isNotEmpty)
          _buildCategoryDistribution(data.categories, theme, tokens),
      ],
    );
  }

  Widget _buildSummaryCard(
    SummaryMetrics summary,
    ThemeData theme,
    AppDecorations tokens,
  ) {
    final balance = summary.totalIncome - summary.totalExpense;
    final isPositive = balance >= 0;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary.withOpacity(0.2),
            AppColors.primary.withOpacity(0.05),
          ],
        ),
        borderRadius: tokens.cardRadius,
        border: Border.all(
          color: AppColors.primary.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.account_balance_wallet_rounded,
                color: AppColors.primary,
                size: 28,
              ),
              const SizedBox(width: 12),
              Text(
                'Resumo do Período',
                style: theme.textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: _MetricItem(
                  label: UxStrings.income,
                  value: summary.totalIncome,
                  color: AppColors.success,
                  icon: Icons.trending_up,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _MetricItem(
                  label: UxStrings.expense,
                  value: summary.totalExpense,
                  color: AppColors.alert,
                  icon: Icons.trending_down,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Divider(color: Colors.white24),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                UxStrings.balance,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: Colors.white70,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Row(
                children: [
                  Icon(
                    isPositive ? Icons.arrow_upward : Icons.arrow_downward,
                    color: isPositive ? AppColors.success : AppColors.alert,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$')
                        .format(balance.abs()),
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: isPositive ? AppColors.success : AppColors.alert,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCashflowChart(
    List<CashflowPoint> cashflow,
    ThemeData theme,
    AppDecorations tokens,
  ) {
    if (cashflow.isEmpty) {
      return const SizedBox.shrink();
    }

    // Calcular valores máximos para ajustar intervalos dinamicamente
    final maxValue = cashflow
        .expand((e) => [e.income, e.expense])
        .reduce((a, b) => a > b ? a : b);
    final interval = _calculateInterval(maxValue);
    
    // Verificar se há projeções
    final hasProjections = cashflow.any((p) => p.isProjection);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: tokens.cardRadius,
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.show_chart_rounded,
                        color: AppColors.primary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Evolução Temporal',
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            '${cashflow.length} meses',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.grey[600],
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Indicador de dados
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.touch_app_rounded,
                      size: 14,
                      color: Colors.grey[500],
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Detalhes',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.grey[500],
                        fontSize: 9,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Legenda
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              _buildLegendItem(
                '💰 ${UxStrings.income}',
                AppColors.success,
                isDashed: false,
              ),
              _buildLegendItem(
                '💸 ${UxStrings.expense}',
                AppColors.alert,
                isDashed: false,
              ),
              if (hasProjections)
                _buildLegendItem(
                  '🔮 Projeção',
                  Colors.grey[400]!,
                  isDashed: true,
                ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 250,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: true,
                  horizontalInterval: interval,
                  verticalInterval: 1,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: Colors.white.withOpacity(0.05),
                      strokeWidth: 1,
                      dashArray: value == 0 ? null : [5, 5],
                    );
                  },
                  getDrawingVerticalLine: (value) {
                    return FlLine(
                      color: Colors.white.withOpacity(0.03),
                      strokeWidth: 1,
                    );
                  },
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 65,
                      interval: interval,
                      getTitlesWidget: (value, meta) {
                        if (value == 0) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Text(
                            NumberFormat.compactCurrency(
                              locale: 'pt_BR',
                              symbol: 'R\$',
                              decimalDigits: 0,
                            ).format(value),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.grey[600],
                              fontSize: 9,
                            ),
                            textAlign: TextAlign.right,
                          ),
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 32,
                      interval: 1,
                      getTitlesWidget: (value, meta) {
                        if (value.toInt() < 0 || value.toInt() >= cashflow.length) {
                          return const SizedBox.shrink();
                        }
                        final monthStr = cashflow[value.toInt()].month;
                        final monthLabel = _formatMonthLabel(monthStr);
                        
                        return Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: Text(
                            monthLabel,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.grey[600],
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                borderData: FlBorderData(
                  show: true,
                  border: Border(
                    left: BorderSide(color: Colors.white.withOpacity(0.1)),
                    bottom: BorderSide(color: Colors.white.withOpacity(0.1)),
                  ),
                ),
                lineBarsData: [
                  // Linha de Receitas (toda a série)
                  LineChartBarData(
                    spots: cashflow
                        .asMap()
                        .entries
                        .map((e) => FlSpot(
                              e.key.toDouble(),
                              e.value.income,
                            ))
                        .toList(),
                    isCurved: true,
                    curveSmoothness: 0.35,
                    color: AppColors.success,
                    barWidth: 3.5,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) {
                        final isProjection = index < cashflow.length && cashflow[index].isProjection;
                        return FlDotCirclePainter(
                          radius: isProjection ? 3 : 4,
                          color: isProjection ? AppColors.success.withOpacity(0.6) : AppColors.success,
                          strokeWidth: 2,
                          strokeColor: const Color(0xFF1E1E1E),
                        );
                      },
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          AppColors.success.withOpacity(0.3),
                          AppColors.success.withOpacity(0.05),
                        ],
                      ),
                    ),
                    shadow: Shadow(
                      color: AppColors.success.withOpacity(0.3),
                      blurRadius: 8,
                    ),
                  ),
                  // Linha tracejada de Receitas (apenas parte de projeção)
                  if (hasProjections) ..._buildProjectionLines(cashflow, true),
                  
                  // Linha de Despesas (toda a série)
                  LineChartBarData(
                    spots: cashflow
                        .asMap()
                        .entries
                        .map((e) => FlSpot(
                              e.key.toDouble(),
                              e.value.expense,
                            ))
                        .toList(),
                    isCurved: true,
                    curveSmoothness: 0.35,
                    color: AppColors.alert,
                    barWidth: 3.5,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) {
                        final isProjection = index < cashflow.length && cashflow[index].isProjection;
                        return FlDotCirclePainter(
                          radius: isProjection ? 3 : 4,
                          color: isProjection ? AppColors.alert.withOpacity(0.6) : AppColors.alert,
                          strokeWidth: 2,
                          strokeColor: const Color(0xFF1E1E1E),
                        );
                      },
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          AppColors.alert.withOpacity(0.3),
                          AppColors.alert.withOpacity(0.05),
                        ],
                      ),
                    ),
                    shadow: Shadow(
                      color: AppColors.alert.withOpacity(0.3),
                      blurRadius: 8,
                    ),
                  ),
                  // Linha tracejada de Despesas (apenas parte de projeção)
                  if (hasProjections) ..._buildProjectionLines(cashflow, false),
                ],
                lineTouchData: LineTouchData(
                  enabled: true,
                  handleBuiltInTouches: true,
                  touchSpotThreshold: 30,
                  getTouchedSpotIndicator: (barData, spotIndexes) {
                    return spotIndexes.map((index) {
                      return TouchedSpotIndicatorData(
                        FlLine(
                          color: Colors.white.withOpacity(0.5),
                          strokeWidth: 2,
                          dashArray: [5, 5],
                        ),
                        FlDotData(
                          show: true,
                          getDotPainter: (spot, percent, bar, index) {
                            return FlDotCirclePainter(
                              radius: 6,
                              color: bar.color ?? Colors.white,
                              strokeWidth: 3,
                              strokeColor: Colors.white,
                            );
                          },
                        ),
                      );
                    }).toList();
                  },
                  touchTooltipData: LineTouchTooltipData(
                    tooltipRoundedRadius: 12,
                    tooltipPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    tooltipMargin: 8,
                    fitInsideHorizontally: true,
                    fitInsideVertically: true,
                    getTooltipColor: (touchedSpot) => const Color(0xFF2D2D2D),
                    getTooltipItems: (touchedSpots) {
                      if (touchedSpots.isEmpty) return [];
                      
                      final index = touchedSpots.first.x.toInt();
                      if (index < 0 || index >= cashflow.length) return [];
                      
                      final point = cashflow[index];
                      final monthStr = point.month;
                      final monthName = _formatMonthName(monthStr);
                      final income = point.income;
                      final expense = point.expense;
                      final balance = income - expense;
                      final isProjection = point.isProjection;
                      
                      // Retorna apenas um tooltip consolidado (na primeira linha tocada)
                      return touchedSpots.asMap().entries.map((entry) {
                        final spotIndex = entry.key;
                        // Mostrar tooltip apenas no primeiro spot (evita duplicação)
                        if (spotIndex == 0) {
                          return LineTooltipItem(
                            '${isProjection ? '🔮 ' : ''}$monthName${isProjection ? ' (Projeção)' : ''}\n',
                            TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              fontStyle: isProjection ? FontStyle.italic : FontStyle.normal,
                            ),
                            children: [
                              const TextSpan(
                                text: '💰 ',
                                style: TextStyle(
                                  color: AppColors.success,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 11,
                                ),
                              ),
                              TextSpan(
                                text: '${UxStrings.income}: ',
                                style: const TextStyle(
                                  color: AppColors.success,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 11,
                                ),
                              ),
                              TextSpan(
                                text: '${NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$').format(income)}\n',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.normal,
                                  fontSize: 11,
                                ),
                              ),
                              const TextSpan(
                                text: '💸 ',
                                style: TextStyle(
                                  color: AppColors.alert,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 11,
                                ),
                              ),
                              TextSpan(
                                text: '${UxStrings.expense}: ',
                                style: const TextStyle(
                                  color: AppColors.alert,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 11,
                                ),
                              ),
                              TextSpan(
                                text: '${NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$').format(expense)}\n',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.normal,
                                  fontSize: 11,
                                ),
                              ),
                              TextSpan(
                                text: '📊 ${UxStrings.balance}: ',
                                style: TextStyle(
                                  color: balance >= 0 ? AppColors.success : AppColors.alert,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 11,
                                ),
                              ),
                              TextSpan(
                                text: NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$').format(balance),
                                style: TextStyle(
                                  color: balance >= 0 ? AppColors.success : AppColors.alert,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          );
                        } else {
                          // Retorna null para as outras linhas (evita duplicação)
                          return null;
                        }
                      }).toList();
                    },
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Legenda
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _LegendItem(
                color: AppColors.success,
                label: UxStrings.income,
              ),
              SizedBox(width: 24),
              _LegendItem(
                color: AppColors.alert,
                label: UxStrings.expense,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceChart(
    List<CashflowPoint> cashflow,
    ThemeData theme,
    AppDecorations tokens,
  ) {
    if (cashflow.isEmpty) {
      return const SizedBox.shrink();
    }

    // Calcular saldo mensal e estatísticas
    final balances = cashflow.map((e) => e.income - e.expense).toList();
    final maxBalance = balances.reduce((a, b) => a.abs() > b.abs() ? a : b).abs();
    
    // Garantir valor mínimo para evitar gráfico "achatado"
    final maxY = maxBalance < 100 ? 100.0 : maxBalance;
    final interval = _calculateInterval(maxY);
    
    final positiveCount = balances.where((b) => b > 0).length;
    final negativeCount = balances.where((b) => b < 0).length;
    final avgBalance = balances.isEmpty ? 0.0 : balances.reduce((a, b) => a + b) / balances.length;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: tokens.cardRadius,
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.highlight.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.bar_chart_rounded,
                        color: AppColors.highlight,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            UxStrings.balance,
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            'Média: ${NumberFormat.compactCurrency(locale: 'pt_BR', symbol: 'R\$', decimalDigits: 0).format(avgBalance)}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: avgBalance >= 0 ? AppColors.success : AppColors.alert,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Indicadores de performance
              Row(
                children: [
                  _buildBalanceIndicator(
                    icon: Icons.trending_up_rounded,
                    count: positiveCount,
                    color: AppColors.success,
                    theme: theme,
                  ),
                  const SizedBox(width: 8),
                  _buildBalanceIndicator(
                    icon: Icons.trending_down_rounded,
                    count: negativeCount,
                    color: AppColors.alert,
                    theme: theme,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 250,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceEvenly,
                maxY: maxY,
                minY: -maxY,
                barTouchData: BarTouchData(
                  enabled: true,
                  handleBuiltInTouches: true,
                  touchTooltipData: BarTouchTooltipData(
                    tooltipRoundedRadius: 12,
                    tooltipPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    tooltipMargin: 8,
                    fitInsideHorizontally: true,
                    fitInsideVertically: true,
                    getTooltipColor: (group) => const Color(0xFF2D2D2D),
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final index = group.x.toInt();
                      if (index < 0 || index >= cashflow.length) return null;
                      
                      final monthStr = cashflow[index].month;
                      final monthName = _formatMonthName(monthStr);
                      final balance = balances[index];
                      final income = cashflow[index].income;
                      final expense = cashflow[index].expense;
                      final percentChange = income > 0 
                          ? ((balance / income) * 100)
                          : 0.0;
                      
                      return BarTooltipItem(
                        '$monthName\n',
                        const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                        children: [
                          const TextSpan(
                            text: '💰 ',
                            style: TextStyle(
                              color: AppColors.success,
                              fontWeight: FontWeight.w600,
                              fontSize: 11,
                            ),
                          ),
                          TextSpan(
                            text: '${UxStrings.income}: ',
                            style: const TextStyle(
                              color: AppColors.success,
                              fontWeight: FontWeight.w600,
                              fontSize: 11,
                            ),
                          ),
                          TextSpan(
                            text: '${NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$').format(income)}\n',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.normal,
                              fontSize: 11,
                            ),
                          ),
                          const TextSpan(
                            text: '💸 ',
                            style: TextStyle(
                              color: AppColors.alert,
                              fontWeight: FontWeight.w600,
                              fontSize: 11,
                            ),
                          ),
                          TextSpan(
                            text: '${UxStrings.expense}: ',
                            style: const TextStyle(
                              color: AppColors.alert,
                              fontWeight: FontWeight.w600,
                              fontSize: 11,
                            ),
                          ),
                          TextSpan(
                            text: '${NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$').format(expense)}\n',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.normal,
                              fontSize: 11,
                            ),
                          ),
                          TextSpan(
                            text: '📊 ${UxStrings.balance}: ',
                            style: TextStyle(
                              color: balance >= 0 ? AppColors.success : AppColors.alert,
                              fontWeight: FontWeight.w600,
                              fontSize: 11,
                            ),
                          ),
                          TextSpan(
                            text: '${NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$').format(balance)}\n',
                            style: TextStyle(
                              color: balance >= 0 ? AppColors.success : AppColors.alert,
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                          const TextSpan(
                            text: '📈 Margem: ',
                            style: TextStyle(
                              color: Colors.white70,
                              fontWeight: FontWeight.w600,
                              fontSize: 11,
                            ),
                          ),
                          TextSpan(
                            text: '${percentChange.toStringAsFixed(1)}%',
                            style: TextStyle(
                              color: percentChange >= 0 ? AppColors.success : AppColors.alert,
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 65,
                      interval: interval,
                      getTitlesWidget: (value, meta) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Text(
                            NumberFormat.compactCurrency(
                              locale: 'pt_BR',
                              symbol: 'R\$',
                              decimalDigits: 0,
                            ).format(value),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.grey[600],
                              fontSize: 9,
                            ),
                            textAlign: TextAlign.right,
                          ),
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 32,
                      getTitlesWidget: (value, meta) {
                        if (value.toInt() < 0 || value.toInt() >= cashflow.length) {
                          return const SizedBox.shrink();
                        }
                        final monthStr = cashflow[value.toInt()].month;
                        final monthLabel = _formatMonthLabel(monthStr);
                        
                        return Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: Text(
                            monthLabel,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.grey[600],
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: interval,
                  getDrawingHorizontalLine: (value) {
                    if (value == 0) {
                      return FlLine(
                        color: Colors.white.withOpacity(0.3),
                        strokeWidth: 2,
                      );
                    }
                    return FlLine(
                      color: Colors.white.withOpacity(0.05),
                      strokeWidth: 1,
                      dashArray: [5, 5],
                    );
                  },
                ),
                borderData: FlBorderData(
                  show: true,
                  border: Border(
                    left: BorderSide(color: Colors.white.withOpacity(0.1)),
                    bottom: BorderSide(color: Colors.white.withOpacity(0.1)),
                  ),
                ),
                barGroups: balances
                    .asMap()
                    .entries
                    .map(
                      (entry) => BarChartGroupData(
                        x: entry.key,
                        barRods: [
                          BarChartRodData(
                            toY: entry.value,
                            width: 14,
                            borderRadius: BorderRadius.vertical(
                              top: entry.value >= 0 
                                  ? const Radius.circular(6) 
                                  : Radius.zero,
                              bottom: entry.value < 0 
                                  ? const Radius.circular(6) 
                                  : Radius.zero,
                            ),
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: entry.value >= 0
                                  ? [
                                      AppColors.success.withOpacity(0.7),
                                      AppColors.success,
                                    ]
                                  : [
                                      AppColors.alert,
                                      AppColors.alert.withOpacity(0.7),
                                    ],
                            ),
                            backDrawRodData: BackgroundBarChartRodData(
                              show: true,
                              toY: maxY,
                              fromY: -maxY,
                              color: Colors.white.withOpacity(0.02),
                            ),
                          ),
                        ],
                      ),
                    )
                    .toList(),
              ),
              swapAnimationDuration: const Duration(milliseconds: 300),
            ),
          ),
          const SizedBox(height: 16),
          // Legenda do gráfico de saldo
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.trending_up_rounded,
                      color: AppColors.success,
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Positivo',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.success,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Icon(
                      Icons.trending_down_rounded,
                      color: AppColors.alert,
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Negativo',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.alert,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceIndicator({
    required IconData icon,
    required int count,
    required Color color,
    required ThemeData theme,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            '$count',
            style: theme.textTheme.bodySmall?.copyWith(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryDistribution(
    Map<String, List<CategorySlice>> categories,
    ThemeData theme,
    AppDecorations tokens,
  ) {
    final expenses = categories['EXPENSE'] ?? [];
    final income = categories['INCOME'] ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (expenses.isNotEmpty) ...[
          _buildCategoryPieChart(
            '${UxStrings.expense} por Categoria',
            expenses,
            AppColors.alert,
            theme,
            tokens,
          ),
          const SizedBox(height: 24),
        ],
        if (income.isNotEmpty) ...[
          _buildCategoryPieChart(
            '${UxStrings.income} por Categoria',
            income,
            AppColors.success,
            theme,
            tokens,
          ),
        ],
      ],
    );
  }

  Widget _buildCategoryPieChart(
    String title,
    List<CategorySlice> slices,
    Color baseColor,
    ThemeData theme,
    AppDecorations tokens,
  ) {
    final total = slices.fold<double>(0, (sum, slice) => sum + slice.total);
    final isExpense = baseColor == AppColors.alert;
    final touchedIndex = isExpense ? _touchedExpenseIndex : _touchedIncomeIndex;
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: tokens.cardRadius,
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: baseColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        isExpense ? Icons.payments_rounded : Icons.account_balance_wallet_rounded,
                        color: baseColor,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            'Total: ${NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$').format(total)}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: baseColor,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white12),
                ),
                child: Text(
                  '${slices.length} categorias',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.grey[500],
                    fontSize: 9,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Gráfico de pizza
              SizedBox(
                width: 140,
                height: 140,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    PieChart(
                      PieChartData(
                        pieTouchData: PieTouchData(
                          touchCallback: (FlTouchEvent event, pieTouchResponse) {
                            setState(() {
                              if (!event.isInterestedForInteractions ||
                                  pieTouchResponse == null ||
                                  pieTouchResponse.touchedSection == null) {
                                if (isExpense) {
                                  _touchedExpenseIndex = -1;
                                } else {
                                  _touchedIncomeIndex = -1;
                                }
                                return;
                              }
                              if (isExpense) {
                                _touchedExpenseIndex = pieTouchResponse
                                    .touchedSection!.touchedSectionIndex;
                              } else {
                                _touchedIncomeIndex = pieTouchResponse
                                    .touchedSection!.touchedSectionIndex;
                              }
                            });
                          },
                        ),
                        sectionsSpace: 2,
                        centerSpaceRadius: 35,
                        sections: slices.asMap().entries.map((entry) {
                          final isTouched = entry.key == touchedIndex;
                          final percentage = (entry.value.total / total) * 100;
                          final radius = isTouched ? 52.0 : 45.0;
                          final fontSize = isTouched ? 12.0 : 10.0;
                          
                          return PieChartSectionData(
                            value: entry.value.total,
                            title: percentage >= 5 ? '${percentage.toStringAsFixed(0)}%' : '',
                            color: _getCategoryColor(entry.key, slices.length, baseColor),
                            radius: radius,
                            titleStyle: TextStyle(
                              fontSize: fontSize,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              shadows: [
                                Shadow(
                                  color: Colors.black.withOpacity(0.5),
                                  blurRadius: 4,
                                ),
                              ],
                            ),
                            badgeWidget: isTouched
                                ? Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF2D2D2D),
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.white, width: 2),
                                    ),
                                    child: Icon(
                                      Icons.touch_app_rounded,
                                      size: 16,
                                      color: baseColor,
                                    ),
                                  )
                                : null,
                            badgePositionPercentageOffset: 1.3,
                          );
                        }).toList(),
                      ),
                      swapAnimationDuration: const Duration(milliseconds: 300),
                      swapAnimationCurve: Curves.easeInOutCubic,
                    ),
                    // Centro do donut com ícone
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E1E1E),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: baseColor.withOpacity(0.3),
                          width: 2,
                        ),
                      ),
                      child: Icon(
                        isExpense ? Icons.trending_down : Icons.trending_up,
                        color: baseColor,
                        size: 28,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 24),
              // Legenda expandida
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ...slices.take(6).map((slice) {
                      final percentage = (slice.total / total) * 100;
                      final index = slices.indexOf(slice);
                      final isTouched = index == touchedIndex;
                      
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isTouched 
                              ? baseColor.withOpacity(0.1) 
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isTouched 
                                ? baseColor.withOpacity(0.3) 
                                : Colors.transparent,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: isTouched ? 14 : 12,
                              height: isTouched ? 14 : 12,
                              decoration: BoxDecoration(
                                color: _getCategoryColor(index, slices.length, baseColor),
                                shape: BoxShape.circle,
                                boxShadow: isTouched
                                    ? [
                                        BoxShadow(
                                          color: _getCategoryColor(index, slices.length, baseColor)
                                              .withOpacity(0.5),
                                          blurRadius: 8,
                                          spreadRadius: 2,
                                        ),
                                      ]
                                    : null,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    slice.name,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: isTouched ? Colors.white : Colors.white70,
                                      fontSize: isTouched ? 12 : 11,
                                      fontWeight: isTouched 
                                          ? FontWeight.w600 
                                          : FontWeight.normal,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (isTouched) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      NumberFormat.currency(
                                        locale: 'pt_BR',
                                        symbol: 'R\$',
                                      ).format(slice.total),
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: baseColor,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: isTouched
                                    ? baseColor.withOpacity(0.2)
                                    : Colors.white.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${percentage.toStringAsFixed(1)}%',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: isTouched ? baseColor : Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: isTouched ? 11 : 10,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                    if (slices.length > 6) ...[
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.03),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.more_horiz_rounded,
                              size: 16,
                              color: Colors.grey[600],
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '+${slices.length - 6} categorias',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: Colors.grey[600],
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Calcula cor para cada categoria baseado no índice
  Color _getCategoryColor(int index, int total, Color baseColor) {
    // Converte a cor base para HSL
    final hslColor = HSLColor.fromColor(baseColor);
    
    // Varia o matiz (hue) e luminosidade para criar variedade visual
    final hueVariation = (index / total) * 60; // Variação de até 60 graus
    final lightnessVariation = (index / total) * 0.2; // Variação de luminosidade
    
    return HSLColor.fromAHSL(
      1.0,
      (hslColor.hue + hueVariation) % 360,
      hslColor.saturation.clamp(0.5, 0.9),
      (hslColor.lightness + lightnessVariation).clamp(0.3, 0.7),
    ).toColor();
  }

  /// Calcula intervalo apropriado para os gráficos baseado no valor máximo
  double _calculateInterval(double maxValue) {
    if (maxValue == 0) return 100;
    
    // Determina a ordem de magnitude
    final magnitude = (maxValue / 5).ceilToDouble();
    const base = 10.0;
    
    // Calcula um intervalo "arredondado"
    final niceInterval = (magnitude / base.toInt()).ceilToDouble() * base;
    
    // Retorna um valor mínimo de 100 para evitar intervalos muito pequenos
    return niceInterval < 100 ? 100 : niceInterval;
  }

  /// Cria um item de legenda para o gráfico
  Widget _buildLegendItem(String label, Color color, {bool isDashed = false}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 24,
          height: 3,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
          child: isDashed
              ? CustomPaint(
                  painter: _DashedLinePainter(color: color),
                )
              : null,
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[400],
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  /// Formata o mês para exibição nas labels do gráfico (ex: "2025-01" -> "JAN")
  String _formatMonthLabel(String monthStr) {
    try {
      final parts = monthStr.split('-');
      if (parts.length != 2) return monthStr;
      
      final month = int.parse(parts[1]);
      const monthNames = [
        'JAN', 'FEV', 'MAR', 'ABR', 'MAI', 'JUN',
        'JUL', 'AGO', 'SET', 'OUT', 'NOV', 'DEZ'
      ];
      
      if (month >= 1 && month <= 12) {
        return monthNames[month - 1];
      }
      return monthStr;
    } catch (e) {
      return monthStr;
    }
  }

  /// Formata o mês para exibição completa no tooltip (ex: "2025-01" -> "Janeiro/2025")
  String _formatMonthName(String monthStr) {
    try {
      final parts = monthStr.split('-');
      if (parts.length != 2) return monthStr;
      
      final year = parts[0];
      final month = int.parse(parts[1]);
      const monthNames = [
        'Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho',
        'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro'
      ];
      
      if (month >= 1 && month <= 12) {
        return '${monthNames[month - 1]}/$year';
      }
      return monthStr;
    } catch (e) {
      return monthStr;
    }
  }

  /// Constrói linhas tracejadas para a parte de projeção do gráfico
  List<LineChartBarData> _buildProjectionLines(List<CashflowPoint> cashflow, bool isIncome) {
    final projectionLines = <LineChartBarData>[];
    
    // Encontrar o primeiro índice de projeção
    int? firstProjectionIndex;
    for (var i = 0; i < cashflow.length; i++) {
      if (cashflow[i].isProjection) {
        firstProjectionIndex = i;
        break;
      }
    }
    
    if (firstProjectionIndex == null || firstProjectionIndex == 0) {
      return projectionLines;
    }
    
    // Criar linha tracejada conectando último ponto real ao primeiro de projeção
    // e continuando por todos os pontos de projeção
    final projectionSpots = <FlSpot>[];
    
    // Adicionar último ponto real para criar transição suave
    projectionSpots.add(FlSpot(
      (firstProjectionIndex - 1).toDouble(),
      isIncome ? cashflow[firstProjectionIndex - 1].income : cashflow[firstProjectionIndex - 1].expense,
    ));
    
    // Adicionar todos os pontos de projeção
    for (var i = firstProjectionIndex; i < cashflow.length; i++) {
      if (cashflow[i].isProjection) {
        projectionSpots.add(FlSpot(
          i.toDouble(),
          isIncome ? cashflow[i].income : cashflow[i].expense,
        ));
      }
    }
    
    final baseColor = isIncome ? AppColors.success : AppColors.alert;
    
    projectionLines.add(
      LineChartBarData(
        spots: projectionSpots,
        isCurved: true,
        curveSmoothness: 0.35,
        color: baseColor.withOpacity(0.5),
        barWidth: 2.5,
        isStrokeCapRound: true,
        dashArray: [8, 4],
        dotData: const FlDotData(show: false), // Dots já são mostrados na linha principal
        belowBarData: BarAreaData(show: false),
      ),
    );
    
    return projectionLines;
  }

  Widget _buildErrorState(ThemeData theme) {
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
            onPressed: _refresh,
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

  Widget _buildEmptyState(ThemeData theme) {
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

class _MetricItem extends StatelessWidget {
  const _MetricItem({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  final String label;
  final double value;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 6),
              Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.grey[400],
                  fontSize: 11,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$').format(value),
            style: theme.textTheme.titleMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({
    required this.color,
    required this.label,
  });

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Row(
      children: [
        Container(
          width: 16,
          height: 3,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: Colors.grey[400],
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

/// CustomPainter para desenhar uma linha tracejada
class _DashedLinePainter extends CustomPainter {
  final Color color;

  _DashedLinePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    const dashWidth = 4.0;
    const dashSpace = 3.0;
    double startX = 0;

    while (startX < size.width) {
      canvas.drawLine(
        Offset(startX, size.height / 2),
        Offset(startX + dashWidth, size.height / 2),
        paint,
      );
      startX += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

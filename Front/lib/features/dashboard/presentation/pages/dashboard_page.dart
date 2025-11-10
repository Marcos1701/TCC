import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../../core/models/dashboard.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme_extension.dart';
import '../../../analytics/presentation/pages/analytics_page.dart';
import '../../data/dashboard_service.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  late Future<DashboardData> _dashboardFuture;
  final _dashboardService = DashboardService();

  @override
  void initState() {
    super.initState();
    _dashboardFuture = _dashboardService.getDashboard();
  }

  Future<void> _refreshDashboard() async {
    setState(() {
      _dashboardFuture = _dashboardService.getDashboard();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.extension<AppDecorations>()!;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text(
          'Dashboard',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        centerTitle: true,
        backgroundColor: Colors.black,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.analytics_outlined),
            tooltip: 'Ver Analytics',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AnalyticsPage(),
                ),
              );
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshDashboard,
        color: AppColors.primary,
        backgroundColor: const Color(0xFF1E1E1E),
        child: FutureBuilder<DashboardData>(
          future: _dashboardFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return _buildLoadingSkeleton(theme, tokens);
            }

            if (snapshot.hasError) {
              return _buildErrorState(snapshot.error!, theme);
            }

            if (!snapshot.hasData) {
              return Center(
                child: Text(
                  'Nenhum dado disponível',
                  style: TextStyle(color: Colors.grey[400]),
                ),
              );
            }

            final data = snapshot.data!;
            return _buildDashboardContent(data, theme, tokens);
          },
        ),
      ),
    );
  }

  Widget _buildDashboardContent(
    DashboardData data,
    ThemeData theme,
    AppDecorations tokens,
  ) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Título da seção com badge de tier
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Resumo do Mês',
                style: theme.textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 20,
                ),
              ),
              _buildTierBadge(data),
            ],
          ),
          const SizedBox(height: 16),
          
          // Cards de Indicadores com dados reais
          _IndicatorCard(
            title: 'Taxa de Poupança Pessoal',
            value: '${data.summary.tps.toStringAsFixed(1)}%',
            subtitle: data.insights['tps']?.message ?? 'Calculando...',
            icon: Icons.savings_outlined,
            color: _getColorBySeverity(data.insights['tps']?.severity ?? 'good'),
            tokens: tokens,
            theme: theme,
          ),
          const SizedBox(height: 12),
          _IndicatorCard(
            title: 'Razão Dívida-Renda',
            value: '${data.summary.rdr.toStringAsFixed(1)}%',
            subtitle: data.insights['rdr']?.message ?? 'Calculando...',
            icon: Icons.account_balance_outlined,
            color: _getColorBySeverity(data.insights['rdr']?.severity ?? 'good'),
            tokens: tokens,
            theme: theme,
          ),
          const SizedBox(height: 12),
          _IndicatorCard(
            title: 'Índice de Liquidez Imediata',
            value: '${data.summary.ili.toStringAsFixed(1)} meses',
            subtitle: data.insights['ili']?.message ?? 'Calculando...',
            icon: Icons.shield_outlined,
            color: _getColorBySeverity(data.insights['ili']?.severity ?? 'good'),
            tokens: tokens,
            theme: theme,
          ),
          const SizedBox(height: 32),
          
          // Gráfico de Evolução dos Indicadores
          if (data.cashflow.isNotEmpty) ...[
            Text(
              'Evolução dos Indicadores',
              style: theme.textTheme.titleLarge?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 20,
              ),
            ),
            const SizedBox(height: 16),
            _IndicatorsEvolutionChart(
              cashflowData: data.cashflow,
              tokens: tokens,
              theme: theme,
            ),
            const SizedBox(height: 32),
          ],
          
          // Comparação Mensal
          // Comparação Mensal
          Text(
            'Comparação Mensal',
            style: theme.textTheme.titleLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 20,
            ),
          ),
          const SizedBox(height: 16),
          _MonthlyComparisonCard(
            data: data,
            tokens: tokens,
            theme: theme,
          ),
        ],
      ),
    );
  }

  Widget _buildTierBadge(DashboardData data) {
    final tps = data.summary.tps;
    final rdr = data.summary.rdr;
    final ili = data.summary.ili;

    String tier;
    Color color;
    IconData icon;

    // Determinar tier baseado nos índices
    if (ili >= 6 && tps > 25 && rdr < 20) {
      tier = 'AVANÇADO';
      color = Colors.purple;
      icon = Icons.star;
    } else if (ili >= 3 && ili < 6) {
      tier = 'INTERMEDIÁRIO';
      color = AppColors.primary;
      icon = Icons.trending_up;
    } else {
      tier = 'INICIANTE';
      color = AppColors.highlight;
      icon = Icons.rocket_launch;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color, width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Text(
            tier,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 12,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Color _getColorBySeverity(String severity) {
    switch (severity) {
      case 'good':
        return AppColors.support; // Verde
      case 'attention':
        return AppColors.highlight; // Amarelo
      case 'warning':
        return Colors.orange;
      case 'critical':
        return AppColors.alert; // Vermelho
      default:
        return AppColors.primary;
    }
  }

  Widget _buildLoadingSkeleton(ThemeData theme, AppDecorations tokens) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
      child: Column(
        children: [
          _buildSkeletonCard(tokens),
          const SizedBox(height: 12),
          _buildSkeletonCard(tokens),
          const SizedBox(height: 12),
          _buildSkeletonCard(tokens),
        ],
      ),
    );
  }

  Widget _buildSkeletonCard(AppDecorations tokens) {
    return Container(
      height: 100,
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: tokens.cardRadius,
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: Colors.grey[800],
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    height: 12,
                    width: 120,
                    decoration: BoxDecoration(
                      color: Colors.grey[800],
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 20,
                    width: 80,
                    decoration: BoxDecoration(
                      color: Colors.grey[800],
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 10,
                    width: 160,
                    decoration: BoxDecoration(
                      color: Colors.grey[800],
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(Object error, ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: AppColors.alert.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'Erro ao carregar dados',
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error.toString(),
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _refreshDashboard,
              icon: const Icon(Icons.refresh),
              label: const Text('Tentar Novamente'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IndicatorCard extends StatelessWidget {
  const _IndicatorCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.tokens,
    required this.theme,
  });

  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;
  final AppDecorations tokens;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: tokens.cardRadius,
        boxShadow: tokens.mediumShadow,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: color,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.grey[400],
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 24,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.grey[500],
                    fontSize: 11,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _IndicatorsEvolutionChart extends StatelessWidget {
  const _IndicatorsEvolutionChart({
    required this.cashflowData,
    required this.tokens,
    required this.theme,
  });

  final List<CashflowPoint> cashflowData;
  final AppDecorations tokens;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    if (cashflowData.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: tokens.cardRadius,
          boxShadow: tokens.mediumShadow,
        ),
        child: Center(
          child: Text(
            'Dados insuficientes para gráfico',
            style: TextStyle(color: Colors.grey[500]),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: tokens.cardRadius,
        boxShadow: tokens.mediumShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'TPS e RDR - Evolução',
            style: theme.textTheme.titleMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          // Legenda
          Wrap(
            spacing: 16,
            children: [
              _ChartLegendItem(
                color: AppColors.support,
                label: 'TPS',
                theme: theme,
              ),
              _ChartLegendItem(
                color: AppColors.primary,
                label: 'RDR',
                theme: theme,
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 200,
            child: LineChart(
              LineChartData(
                minX: 0,
                maxX: (cashflowData.length - 1).toDouble(),
                minY: 0,
                maxY: 100,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 20,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: Colors.grey[800]!,
                      strokeWidth: 1,
                    );
                  },
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 42,
                      interval: 20,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          '${value.toInt()}%',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.grey[600],
                            fontSize: 11,
                          ),
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index >= 0 && index < cashflowData.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              cashflowData[index].month,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: Colors.grey[600],
                                fontSize: 11,
                              ),
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  // Linha TPS
                  LineChartBarData(
                    isCurved: true,
                    color: AppColors.support,
                    barWidth: 3,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) {
                        return FlDotCirclePainter(
                          radius: 4,
                          color: AppColors.support,
                          strokeWidth: 2,
                          strokeColor: const Color(0xFF1E1E1E),
                        );
                      },
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [
                          AppColors.support.withOpacity(0.2),
                          AppColors.support.withOpacity(0.0),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                    spots: cashflowData.asMap().entries.map((entry) {
                      return FlSpot(
                        entry.key.toDouble(),
                        entry.value.tps,
                      );
                    }).toList(),
                  ),
                  // Linha RDR
                  LineChartBarData(
                    isCurved: true,
                    color: AppColors.primary,
                    barWidth: 3,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) {
                        return FlDotCirclePainter(
                          radius: 4,
                          color: AppColors.primary,
                          strokeWidth: 2,
                          strokeColor: const Color(0xFF1E1E1E),
                        );
                      },
                    ),
                    spots: cashflowData.asMap().entries.map((entry) {
                      return FlSpot(
                        entry.key.toDouble(),
                        entry.value.rdr,
                      );
                    }).toList(),
                  ),
                ],
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipItems: (touchedSpots) {
                      return touchedSpots.map((spot) {
                        final color = spot.bar.color ?? Colors.white;
                        final label = color == AppColors.support ? 'TPS' : 'RDR';
                        return LineTooltipItem(
                          '$label: ${spot.y.toStringAsFixed(1)}%',
                          theme.textTheme.bodySmall!.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        );
                      }).toList();
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChartLegendItem extends StatelessWidget {
  const _ChartLegendItem({
    required this.color,
    required this.label,
    required this.theme,
  });

  final Color color;
  final String label;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
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

class _MonthlyComparisonCard extends StatelessWidget {
  const _MonthlyComparisonCard({
    required this.data,
    required this.tokens,
    required this.theme,
  });

  final DashboardData data;
  final AppDecorations tokens;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    // Pega últimos 2 meses se disponível
    final hasComparison = data.cashflow.length >= 2;
    
    if (!hasComparison) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: tokens.cardRadius,
          boxShadow: tokens.mediumShadow,
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Text(
              'Dados insuficientes para comparação',
              style: TextStyle(color: Colors.grey[500]),
            ),
          ),
        ),
      );
    }

    final current = data.cashflow.last;
    final previous = data.cashflow[data.cashflow.length - 2];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: tokens.cardRadius,
        boxShadow: tokens.mediumShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${current.month} vs ${previous.month}',
            style: theme.textTheme.titleMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 20),
          _ComparisonRow(
            label: 'Receitas',
            currentValue: 'R\$ ${current.income.toStringAsFixed(0)}',
            previousValue: 'R\$ ${previous.income.toStringAsFixed(0)}',
            isPositive: current.income >= previous.income,
            theme: theme,
          ),
          const SizedBox(height: 16),
          _ComparisonRow(
            label: 'Despesas',
            currentValue: 'R\$ ${current.expense.toStringAsFixed(0)}',
            previousValue: 'R\$ ${previous.expense.toStringAsFixed(0)}',
            isPositive: current.expense <= previous.expense,
            theme: theme,
          ),
          const SizedBox(height: 16),
          _ComparisonRow(
            label: 'TPS',
            currentValue: '${current.tps.toStringAsFixed(1)}%',
            previousValue: '${previous.tps.toStringAsFixed(1)}%',
            isPositive: current.tps >= previous.tps,
            theme: theme,
          ),
        ],
      ),
    );
  }
}

class _ComparisonRow extends StatelessWidget {
  const _ComparisonRow({
    required this.label,
    required this.currentValue,
    required this.previousValue,
    required this.isPositive,
    required this.theme,
  });

  final String label;
  final String currentValue;
  final String previousValue;
  final bool isPositive;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.grey[400],
            ),
          ),
        ),
        Expanded(
          flex: 3,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                currentValue,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                previousValue,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.grey[600],
                  fontSize: 11,
                  decoration: TextDecoration.lineThrough,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Icon(
          isPositive ? Icons.arrow_upward : Icons.arrow_downward,
          color: isPositive ? AppColors.support : AppColors.alert,
          size: 18,
        ),
      ],
    );
  }
}

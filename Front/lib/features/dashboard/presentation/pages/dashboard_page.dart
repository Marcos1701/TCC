import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../../core/widgets/metric_card.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Resumo do mês',
            style: theme.textTheme.headlineSmall,
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 600;
              return Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  SizedBox(
                    width: isWide ? (constraints.maxWidth - 16) / 2 : constraints.maxWidth,
                    child: const MetricCard(
                      title: 'Taxa de Poupança Pessoal',
                      value: '18,4%',
                      subtitle: 'Meta ideal: 20% - continue avançando! ',
                    ),
                  ),
                  SizedBox(
                    width: isWide ? (constraints.maxWidth - 16) / 2 : constraints.maxWidth,
                    child: const MetricCard(
                      title: 'Razão Dívida-Renda',
                      value: '32,0%',
                      subtitle: 'Situação saudável • mantenha o foco nas metas.',
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 32),
          Text(
            'Evolução da poupança',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 24, 24, 24),
              child: SizedBox(
                height: 220,
                child: LineChart(
                  LineChartData(
                    minX: 0,
                    maxX: 5,
                    minY: 0,
                    maxY: 10,
                    gridData: const FlGridData(
                      show: true,
                      drawHorizontalLine: true,
                      horizontalInterval: 2,
                      drawVerticalLine: false,
                    ),
                    titlesData: FlTitlesData(
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 42,
                          interval: 2,
                          getTitlesWidget: (value, meta) => Text('${value.toInt()}k'),
                        ),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 28,
                          getTitlesWidget: (value, meta) {
                            const labels = ['Jul', 'Ago', 'Set', 'Out', 'Nov', 'Dez'];
                            final index = value.toInt();
                            return index >= 0 && index < labels.length
                                ? Text(labels[index])
                                : const SizedBox.shrink();
                          },
                        ),
                      ),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    ),
                    borderData: FlBorderData(show: false),
                    lineBarsData: [
                      LineChartBarData(
                        isCurved: true,
                        color: theme.colorScheme.primary,
                        barWidth: 4,
                        dotData: const FlDotData(show: false),
                        spots: const [
                          FlSpot(0, 3.2),
                          FlSpot(1, 3.8),
                          FlSpot(2, 4.5),
                          FlSpot(3, 5.6),
                          FlSpot(4, 6.4),
                          FlSpot(5, 7.1),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 32),
          Text(
            'Missões em destaque',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          ...[
            const _MissionCard(
              title: 'Reduza gastos variáveis em 10%',
              description:
                  'Analise suas últimas despesas e identifique três categorias para otimizar.',
              progress: 0.45,
            ),
            const SizedBox(height: 12),
            const _MissionCard(
              title: 'Construa reserva de emergência',
              description:
                  'Programe uma transferência automática semanal para alcançar R\$ 1.500 em 3 meses.',
              progress: 0.25,
            ),
          ],
        ],
      ),
    );
  }
}

class _MissionCard extends StatelessWidget {
  const _MissionCard({
    required this.title,
    required this.description,
    required this.progress,
  });

  final String title;
  final String description;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              description,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 10,
              ),
            ),
            const SizedBox(height: 8),
            Text('${(progress * 100).round()}% concluído'),
          ],
        ),
      ),
    );
  }
}

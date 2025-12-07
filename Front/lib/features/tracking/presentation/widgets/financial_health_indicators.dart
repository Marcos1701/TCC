import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// Displays the three key financial health indicators: TPS, RDR, ILI.
class FinancialHealthIndicators extends StatelessWidget {
  const FinancialHealthIndicators({
    super.key,
    required this.tps,
    required this.rdr,
    required this.ili,
  });

  final double tps;
  final double rdr;
  final double ili;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(10),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Saúde Financeira',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          _buildIndicatorRow(
            context,
            label: 'TPS',
            sublabel: 'Taxa de Poupança',
            value: tps,
            unit: '%',
            status: _getTpsStatus(tps),
            tooltip: 'Percentual da renda que você consegue poupar. Meta: > 15%',
          ),
          const Divider(color: Colors.white24, height: 24),
          _buildIndicatorRow(
            context,
            label: 'RDR',
            sublabel: 'Razão Dívida/Renda',
            value: rdr,
            unit: '%',
            status: _getRdrStatus(rdr),
            tooltip: 'Quanto da sua renda está comprometida com dívidas. Meta: < 35%',
          ),
          const Divider(color: Colors.white24, height: 24),
          _buildIndicatorRow(
            context,
            label: 'ILI',
            sublabel: 'Liquidez Imediata',
            value: ili,
            unit: ' meses',
            status: _getIliStatus(ili),
            tooltip: 'Quantos meses de despesas essenciais sua reserva cobre. Meta: > 6',
          ),
        ],
      ),
    );
  }

  Widget _buildIndicatorRow(
    BuildContext context, {
    required String label,
    required String sublabel,
    required double value,
    required String unit,
    required _IndicatorStatus status,
    required String tooltip,
  }) {
    return Tooltip(
      message: tooltip,
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: status.color.withAlpha(30),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                label,
                style: TextStyle(
                  color: status.color,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  sublabel,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  status.label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: status.color,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '${value.toStringAsFixed(1)}$unit',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: status.color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  _IndicatorStatus _getTpsStatus(double value) {
    if (value >= 20) {
      return _IndicatorStatus('Excelente', AppColors.success);
    } else if (value >= 10) {
      return _IndicatorStatus('Atenção', AppColors.highlight);
    } else {
      return _IndicatorStatus('Crítico', AppColors.alert);
    }
  }

  _IndicatorStatus _getRdrStatus(double value) {
    if (value <= 30) {
      return _IndicatorStatus('Saudável', AppColors.success);
    } else if (value <= 40) {
      return _IndicatorStatus('Atenção', AppColors.highlight);
    } else {
      return _IndicatorStatus('Crítico', AppColors.alert);
    }
  }

  _IndicatorStatus _getIliStatus(double value) {
    if (value >= 6) {
      return _IndicatorStatus('Seguro', AppColors.success);
    } else if (value >= 3) {
      return _IndicatorStatus('Atenção', AppColors.highlight);
    } else {
      return _IndicatorStatus('Crítico', AppColors.alert);
    }
  }
}

class _IndicatorStatus {
  final String label;
  final Color color;

  _IndicatorStatus(this.label, this.color);
}

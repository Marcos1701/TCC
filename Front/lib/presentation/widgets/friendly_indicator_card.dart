import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/constants/user_friendly_strings.dart';
import '../../core/theme/app_colors.dart';

/// Widget reutilizável para exibir indicadores financeiros de forma visual e amigável.
/// 
/// Substitui a exibição técnica de métricas (TPS, RDR, ILI) por cards visuais
/// com badges de status, barras de progresso e mensagens contextuais.
class FriendlyIndicatorCard extends StatelessWidget {
  /// Título do indicador (ex: "Você está guardando")
  final String title;
  
  /// Valor atual do indicador
  final double value;
  
  /// Valor alvo/meta do indicador
  final double target;
  
  /// Tipo de formatação do valor
  final IndicatorType type;
  
  /// Subtítulo opcional com contexto adicional
  final String? subtitle;
  
  /// Ícone personalizado (opcional, usa ícone do status por padrão)
  final IconData? customIcon;

  const FriendlyIndicatorCard({
    required this.title,
    required this.value,
    required this.target,
    required this.type,
    this.subtitle,
    this.customIcon,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final status = _getStatus();
    final progress = _calculateProgress();
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: status.color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: status.color.withOpacity(0.3),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cabeçalho com ícone e badge de status
          Row(
            children: [
              Icon(
                customIcon ?? status.icon,
                color: status.color,
                size: 24,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
              _buildStatusBadge(status),
            ],
          ),
          
          const SizedBox(height: 12),
          
          // Valor principal
          Text(
            _formatValue(),
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: status.color,
            ),
          ),
          
          // Subtítulo opcional
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[400],
              ),
            ),
          ],
          
          const SizedBox(height: 12),
          
          // Barra de progresso
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.grey[800],
              valueColor: AlwaysStoppedAnimation(status.color),
              minHeight: 8,
            ),
          ),
          
          const SizedBox(height: 8),
          
          // Meta
          Text(
            'Meta: ${_formatTarget()}',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  /// Determina o status baseado no progresso
  _IndicatorStatus _getStatus() {
    final progress = _calculateProgress();
    
    if (progress >= 1.0) {
      return _IndicatorStatus(
        label: UxStrings.excellent,
        color: Colors.green,
        icon: Icons.check_circle,
      );
    } else if (progress >= 0.7) {
      return _IndicatorStatus(
        label: UxStrings.good,
        color: Colors.lightGreen,
        icon: Icons.trending_up,
      );
    } else if (progress >= 0.4) {
      return _IndicatorStatus(
        label: UxStrings.warning,
        color: Colors.orange,
        icon: Icons.warning_amber,
      );
    } else {
      return _IndicatorStatus(
        label: UxStrings.critical,
        color: Colors.red,
        icon: Icons.error_outline,
      );
    }
  }

  /// Calcula o progresso (0.0 a 1.0)
  double _calculateProgress() {
    if (target == 0) return 0;
    return (value / target).clamp(0.0, 1.0);
  }

  /// Formata o valor atual conforme o tipo
  String _formatValue() {
    switch (type) {
      case IndicatorType.currency:
        return NumberFormat.currency(
          locale: 'pt_BR',
          symbol: 'R\$',
        ).format(value);
      case IndicatorType.percentage:
        return '${value.toStringAsFixed(0)}%';
      case IndicatorType.months:
        return '${value.toStringAsFixed(1)} meses';
    }
  }

  /// Formata o valor alvo conforme o tipo
  String _formatTarget() {
    switch (type) {
      case IndicatorType.currency:
        return NumberFormat.currency(
          locale: 'pt_BR',
          symbol: 'R\$',
        ).format(target);
      case IndicatorType.percentage:
        return '${target.toStringAsFixed(0)}%';
      case IndicatorType.months:
        return '${target.toStringAsFixed(1)} meses';
    }
  }

  /// Constrói o badge de status
  Widget _buildStatusBadge(_IndicatorStatus status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: status.color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: status.color,
        ),
      ),
    );
  }
}

/// Tipos de formatação de indicadores
enum IndicatorType {
  /// Valores monetários (R$)
  currency,
  
  /// Porcentagem (%)
  percentage,
  
  /// Meses
  months,
}

/// Status interno do indicador
class _IndicatorStatus {
  final String label;
  final Color color;
  final IconData icon;

  _IndicatorStatus({
    required this.label,
    required this.color,
    required this.icon,
  });
}

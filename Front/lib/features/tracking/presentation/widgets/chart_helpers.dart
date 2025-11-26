import 'package:flutter/material.dart';

/// Funções auxiliares para formatação de dados em gráficos.
class ChartHelpers {
  const ChartHelpers._();

  /// Calcula intervalo apropriado para os gráficos baseado no valor máximo.
  static double calculateInterval(double maxValue) {
    if (maxValue == 0) return 100;

    // Determina a ordem de magnitude
    final magnitude = (maxValue / 5).ceilToDouble();
    const base = 10.0;

    // Calcula um intervalo "arredondado"
    final niceInterval = (magnitude / base.toInt()).ceilToDouble() * base;

    // Retorna um valor mínimo de 100 para evitar intervalos muito pequenos
    return niceInterval < 100 ? 100 : niceInterval;
  }

  /// Formata o mês para exibição nas labels do gráfico (ex: "2025-01" -> "JAN").
  static String formatMonthLabel(String monthStr) {
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

  /// Formata o mês para exibição completa no tooltip (ex: "2025-01" -> "Janeiro/2025").
  static String formatMonthName(String monthStr) {
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

  /// Calcula cor para cada categoria baseado no índice.
  static Color getCategoryColor(int index, int total, Color baseColor) {
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
}

/// Item de legenda para gráficos.
class LegendItem extends StatelessWidget {
  const LegendItem({
    super.key,
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

/// Item de legenda com suporte a linha tracejada.
class DashedLegendItem extends StatelessWidget {
  const DashedLegendItem({
    super.key,
    required this.label,
    required this.color,
    this.isDashed = false,
  });

  final String label;
  final Color color;
  final bool isDashed;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 24,
          height: 3,
          decoration: BoxDecoration(
            color: isDashed ? null : color,
            borderRadius: BorderRadius.circular(2),
          ),
          child: isDashed
              ? CustomPaint(
                  painter: DashedLinePainter(color: color),
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
}

/// CustomPainter para desenhar uma linha tracejada.
class DashedLinePainter extends CustomPainter {
  const DashedLinePainter({required this.color});

  final Color color;

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

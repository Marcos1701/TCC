import 'package:flutter/material.dart';

class ChartHelpers {
  const ChartHelpers._();

  static double calculateInterval(double maxValue) {
    if (maxValue == 0) return 100;

    final magnitude = (maxValue / 5).ceilToDouble();
    const base = 10.0;

    final niceInterval = (magnitude / base.toInt()).ceilToDouble() * base;

    return niceInterval < 100 ? 100 : niceInterval;
  }

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

  static Color getCategoryColor(int index, int total, Color baseColor) {
    final hslColor = HSLColor.fromColor(baseColor);

    final hueVariation = (index / total) * 60;
    final lightnessVariation = (index / total) * 0.2;

    return HSLColor.fromAHSL(
      1.0,
      (hslColor.hue + hueVariation) % 360,
      hslColor.saturation.clamp(0.5, 0.9),
      (hslColor.lightness + lightnessVariation).clamp(0.3, 0.7),
    ).toColor();
  }
}

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

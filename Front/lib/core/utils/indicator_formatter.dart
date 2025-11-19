/// Utilities for formatting and validating financial indicators
library;

/// Formats an indicator value with validation and error handling
String formatIndicator(double? value, {int decimals = 1, String suffix = '%'}) {
  if (value == null || value.isNaN || value.isInfinite) {
    return '0.0$suffix';
  }
  
  // Ensure value is within reasonable limits
  final clampedValue = value.clamp(-9999.99, 9999.99);
  return '${clampedValue.toStringAsFixed(decimals)}$suffix';
}

/// Validates and sanitizes an indicator value
double sanitizeIndicatorValue(double? value, {double defaultValue = 0.0}) {
  if (value == null || value.isNaN || value.isInfinite) {
    return defaultValue;
  }
  
  // Limit to reasonable values
  return value.clamp(-9999.99, 9999.99);
}

/// Returns appropriate color for an indicator based on severity
String getIndicatorColor(String severity) {
  switch (severity) {
    case 'good':
      return '#4CAF50'; // Green
    case 'attention':
      return '#FFC107'; // Yellow
    case 'warning':
      return '#FF9800'; // Orange
    case 'critical':
      return '#F44336'; // Red
    default:
      return '#607D8B'; // Gray
  }
}

/// Class to store formatted indicator data
class FormattedIndicator {
  const FormattedIndicator({
    required this.value,
    required this.formattedValue,
    required this.target,
    required this.formattedTarget,
    required this.isValid,
  });

  final double value;
  final String formattedValue;
  final double target;
  final String formattedTarget;
  final bool isValid;

  /// Creates a FormattedIndicator from raw values
  factory FormattedIndicator.fromRaw({
    required double? value,
    required double? target,
    int decimals = 1,
    String suffix = '%',
  }) {
    final sanitizedValue = sanitizeIndicatorValue(value);
    final sanitizedTarget = sanitizeIndicatorValue(target);
    final isValid = value != null && !value.isNaN && !value.isInfinite;

    return FormattedIndicator(
      value: sanitizedValue,
      formattedValue: formatIndicator(value, decimals: decimals, suffix: suffix),
      target: sanitizedTarget,
      formattedTarget: formatIndicator(target, decimals: decimals, suffix: suffix),
      isValid: isValid,
    );
  }

  /// Checks if indicator is above target (for TPS and ILI)
  bool isAboveTarget() => value >= target;

  /// Checks if indicator is below target (for RDR)
  bool isBelowTarget() => value <= target;

  /// Calculates percentage difference from target
  double percentageDifferenceFromTarget() {
    if (target == 0) return 0.0;
    return ((value - target) / target) * 100;
  }
}

/// Specific class for TPS (Personal Savings Rate)
class TPSIndicator extends FormattedIndicator {
  const TPSIndicator({
    required super.value,
    required super.formattedValue,
    required super.target,
    required super.formattedTarget,
    required super.isValid,
  });

  factory TPSIndicator.fromRaw({
    required double? value,
    required double? target,
  }) {
    final formatted = FormattedIndicator.fromRaw(
      value: value,
      target: target,
      decimals: 0,
      suffix: '%',
    );

    return TPSIndicator(
      value: formatted.value,
      formattedValue: formatted.formattedValue,
      target: formatted.target,
      formattedTarget: formatted.formattedTarget,
      isValid: formatted.isValid,
    );
  }

  /// Retorna a faixa de classificação do TPS
  String getClassification() {
    if (value >= 20) return 'Excelente';
    if (value >= 15) return 'Boa';
    if (value >= 10) return 'Regular';
    if (value >= 5) return 'Baixa';
    return 'Crítica';
  }
}

/// Classe específica para RDR (Razão Dívida/Renda)
class RDRIndicator extends FormattedIndicator {
  const RDRIndicator({
    required super.value,
    required super.formattedValue,
    required super.target,
    required super.formattedTarget,
    required super.isValid,
  });

  factory RDRIndicator.fromRaw({
    required double? value,
    required double? target,
  }) {
    final formatted = FormattedIndicator.fromRaw(
      value: value,
      target: target,
      decimals: 0,
      suffix: '%',
    );

    return RDRIndicator(
      value: formatted.value,
      formattedValue: formatted.formattedValue,
      target: formatted.target,
      formattedTarget: formatted.formattedTarget,
      isValid: formatted.isValid,
    );
  }

  /// Retorna a faixa de classificação do RDR
  String getClassification() {
    if (value <= 30) return 'Saudável';
    if (value <= 35) return 'Aceitável';
    if (value <= 42) return 'Atenção';
    if (value <= 49) return 'Risco';
    return 'Crítico';
  }
}

/// Classe específica para ILI (Índice de Liquidez Imediata)
class ILIIndicator extends FormattedIndicator {
  const ILIIndicator({
    required super.value,
    required super.formattedValue,
    required super.target,
    required super.formattedTarget,
    required super.isValid,
  });

  factory ILIIndicator.fromRaw({
    required double? value,
    required double? target,
  }) {
    final formatted = FormattedIndicator.fromRaw(
      value: value,
      target: target,
      decimals: 1,
      suffix: 'm',
    );

    return ILIIndicator(
      value: formatted.value,
      formattedValue: formatted.formattedValue,
      target: formatted.target,
      formattedTarget: formatted.formattedTarget,
      isValid: formatted.isValid,
    );
  }

  /// Retorna a faixa de classificação do ILI
  String getClassification() {
    if (value >= 6) return 'Sólida';
    if (value >= 3) return 'Construindo';
    if (value >= 1) return 'Mínima';
    return 'Insuficiente';
  }
}

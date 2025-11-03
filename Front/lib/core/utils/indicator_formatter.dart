/// Utilitários para formatação e validação de indicadores financeiros

/// Formata um valor de indicador com validação e tratamento de erros
String formatIndicator(double? value, {int decimals = 1, String suffix = '%'}) {
  if (value == null || value.isNaN || value.isInfinite) {
    return '0.0$suffix';
  }
  
  // Garantir que o valor está dentro de limites razoáveis
  final clampedValue = value.clamp(-9999.99, 9999.99);
  return '${clampedValue.toStringAsFixed(decimals)}$suffix';
}

/// Valida e sanitiza um valor de indicador
double sanitizeIndicatorValue(double? value, {double defaultValue = 0.0}) {
  if (value == null || value.isNaN || value.isInfinite) {
    return defaultValue;
  }
  
  // Limitar a valores razoáveis
  return value.clamp(-9999.99, 9999.99);
}

/// Retorna a cor apropriada para um indicador baseado em sua severidade
String getIndicatorColor(String severity) {
  switch (severity) {
    case 'good':
      return '#4CAF50'; // Verde
    case 'attention':
      return '#FFC107'; // Amarelo
    case 'warning':
      return '#FF9800'; // Laranja
    case 'critical':
      return '#F44336'; // Vermelho
    default:
      return '#607D8B'; // Cinza
  }
}

/// Classe para armazenar dados formatados de um indicador
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

  /// Cria um FormattedIndicator a partir de valores brutos
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

  /// Verifica se o indicador está acima da meta (para TPS e ILI)
  bool isAboveTarget() => value >= target;

  /// Verifica se o indicador está abaixo da meta (para RDR)
  bool isBelowTarget() => value <= target;

  /// Calcula a diferença percentual em relação à meta
  double percentageDifferenceFromTarget() {
    if (target == 0) return 0.0;
    return ((value - target) / target) * 100;
  }
}

/// Classe específica para TPS (Taxa de Poupança Pessoal)
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

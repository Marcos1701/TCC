library;

import 'package:flutter/material.dart';

abstract final class MissionTypes {
  static const String onboarding = 'ONBOARDING';

  static const String tpsImprovement = 'TPS_IMPROVEMENT';

  static const String rdrReduction = 'RDR_REDUCTION';

  static const String iliBuilding = 'ILI_BUILDING';

  static const String categoryReduction = 'CATEGORY_REDUCTION';

  static const List<String> all = [
    onboarding,
    tpsImprovement,
    rdrReduction,
    iliBuilding,
    categoryReduction,
  ];
}

abstract final class MissionDifficulties {
  static const String easy = 'EASY';
  static const String medium = 'MEDIUM';
  static const String hard = 'HARD';

  static const List<String> all = [easy, medium, hard];
}

abstract final class UserTiers {
  static const String beginner = 'BEGINNER';

  static const String intermediate = 'INTERMEDIATE';

  static const String advanced = 'ADVANCED';

  static const List<String> all = [beginner, intermediate, advanced];
}

abstract final class MissionTypeLabels {
  static const Map<String, String> short = {
    MissionTypes.onboarding: 'Primeiros Passos',
    MissionTypes.tpsImprovement: 'Poupança',
    MissionTypes.rdrReduction: 'Controle de Dívidas',
    MissionTypes.iliBuilding: 'Reserva de Emergência',
    MissionTypes.categoryReduction: 'Redução de Gastos',
  };

  static const Map<String, String> descriptive = {
    MissionTypes.onboarding: 'Primeiros Passos',
    MissionTypes.tpsImprovement: 'Aumentar Poupança (TPS)',
    MissionTypes.rdrReduction: 'Reduzir Gastos Recorrentes (RDR)',
    MissionTypes.iliBuilding: 'Construir Reserva (ILI)',
    MissionTypes.categoryReduction: 'Reduzir Gastos em Categoria',
  };

  static String getShort(String type) => short[type] ?? 'Missão';

  static String getDescriptive(String type) => descriptive[type] ?? type;
}

abstract final class DifficultyLabels {
  static const Map<String, String> labels = {
    MissionDifficulties.easy: 'Fácil',
    MissionDifficulties.medium: 'Média',
    MissionDifficulties.hard: 'Difícil',
  };

  static String get(String difficulty) => labels[difficulty] ?? difficulty;
}

abstract final class TierLabels {
  static const Map<String, String> labels = {
    UserTiers.beginner: 'Iniciante',
    UserTiers.intermediate: 'Intermediário',
    UserTiers.advanced: 'Avançado',
  };

  static const Map<String, String> withLevels = {
    UserTiers.beginner: 'Iniciante (níveis 1-5)',
    UserTiers.intermediate: 'Intermediário (níveis 6-15)',
    UserTiers.advanced: 'Avançado (níveis 16+)',
  };

  static String get(String tier) => labels[tier] ?? tier;
  static String getWithLevels(String tier) => withLevels[tier] ?? tier;
}

abstract final class MissionTypeColors {
  static const Map<String, Color> colors = {
    MissionTypes.onboarding: Color(0xFF9C27B0),
    MissionTypes.tpsImprovement: Color(0xFF4CAF50),
    MissionTypes.rdrReduction: Color(0xFFF44336),
    MissionTypes.iliBuilding: Color(0xFF2196F3),
    MissionTypes.categoryReduction: Color(0xFFFF9800),
  };

  static const Color defaultColor = Color(0xFF607D8B);

  static Color get(String type) => colors[type] ?? defaultColor;
}

abstract final class DifficultyColors {
  static const Map<String, Color> colors = {
    MissionDifficulties.easy: Color(0xFF4CAF50),
    MissionDifficulties.medium: Color(0xFFFFC107),
    MissionDifficulties.hard: Color(0xFFF44336),
  };

  static const Color defaultColor = Color(0xFFFFC107);

  static Color get(String difficulty) => colors[difficulty] ?? defaultColor;
}

abstract final class MissionTypeIcons {
  static const Map<String, IconData> icons = {
    MissionTypes.onboarding: Icons.rocket_launch_outlined,
    MissionTypes.tpsImprovement: Icons.savings_outlined,
    MissionTypes.rdrReduction: Icons.trending_down_outlined,
    MissionTypes.iliBuilding: Icons.shield_outlined,
    MissionTypes.categoryReduction: Icons.pie_chart_outline,
  };

  static const IconData defaultIcon = Icons.assignment_outlined;

  static IconData get(String type) => icons[type] ?? defaultIcon;
}

/// Descrições detalhadas para cada tipo de missão (usadas no admin)
abstract final class MissionTypeDescriptions {
  static const Map<String, String> descriptions = {
    MissionTypes.onboarding:
        'Missões para familiarizar o usuário com o registro de transações e funcionalidades básicas.',
    MissionTypes.tpsImprovement:
        'Missões para incentivar o aumento da Taxa de Poupança Pessoal do usuário.',
    MissionTypes.rdrReduction:
        'Missões para diminuir a Razão Dívida/Renda, focando em despesas fixas.',
    MissionTypes.iliBuilding:
        'Missões para aumentar o Índice de Liquidez Imediata, construindo reserva de emergência.',
    MissionTypes.categoryReduction:
        'Missões para controlar gastos em categorias específicas.',
  };

  static String get(String type) => descriptions[type] ?? 'Missão personalizada';
}

/// Dicas contextuais para cada tipo de missão
abstract final class MissionTypeTips {
  static const Map<String, List<String>> tips = {
    MissionTypes.onboarding: [
      'Ideal para usuários que estão começando',
      'Mantenha metas alcançáveis para não desmotivar',
      'Duração curta (7-14 dias) funciona melhor',
    ],
    MissionTypes.tpsImprovement: [
      'TPS = (Receitas - Despesas) / Receitas × 100',
      'Metas entre 10-20% são mais realistas para iniciantes',
      'Considere a renda média do usuário ao definir metas',
    ],
    MissionTypes.rdrReduction: [
      'RDR = Despesas Recorrentes / Receitas × 100',
      'Incentive revisão de assinaturas e custos fixos',
      'Metas graduais são mais efetivas',
    ],
    MissionTypes.iliBuilding: [
      'ILI = Reservas / Despesas Mensais Médias',
      'Especialistas recomendam 3-6 meses de reserva',
      'Missões de longo prazo funcionam melhor para este tipo',
    ],
    MissionTypes.categoryReduction: [
      'Categorias de lazer/entretenimento são bons alvos',
      'Reduções graduais têm maior taxa de sucesso',
      'Combine com dicas específicas da categoria',
    ],
  };

  static List<String> get(String type) => tips[type] ?? [];
}

/// Configuração de campos por tipo de missão
class MissionTypeFieldConfig {
  final String fieldKey;
  final String label;
  final String hint;
  final String validationType;
  final num defaultValue;
  final num min;
  final num max;
  final num recommendedMin;
  final num recommendedMax;
  final String? unit;
  final bool isDecimal;

  const MissionTypeFieldConfig({
    required this.fieldKey,
    required this.label,
    required this.hint,
    required this.validationType,
    required this.defaultValue,
    required this.min,
    required this.max,
    required this.recommendedMin,
    required this.recommendedMax,
    this.unit,
    this.isDecimal = false,
  });
}

abstract final class MissionTypeFields {
  static const Map<String, MissionTypeFieldConfig> configs = {
    MissionTypes.onboarding: MissionTypeFieldConfig(
      fieldKey: 'min_transactions',
      label: 'Transações Mínimas',
      hint: 'Recomendado: 5-20 para iniciantes',
      validationType: 'TRANSACTION_COUNT',
      defaultValue: 10,
      min: 1,
      max: 100,
      recommendedMin: 5,
      recommendedMax: 20,
    ),
    MissionTypes.tpsImprovement: MissionTypeFieldConfig(
      fieldKey: 'target_tps',
      label: 'Meta TPS',
      hint: 'Média recomendada: 10-30%',
      validationType: 'INDICATOR_THRESHOLD',
      defaultValue: 15,
      min: 1,
      max: 80,
      recommendedMin: 10,
      recommendedMax: 30,
      unit: '%',
    ),
    MissionTypes.rdrReduction: MissionTypeFieldConfig(
      fieldKey: 'target_rdr',
      label: 'Meta RDR Máximo',
      hint: 'Ideal: manter abaixo de 30-40%',
      validationType: 'INDICATOR_THRESHOLD',
      defaultValue: 40,
      min: 5,
      max: 95,
      recommendedMin: 25,
      recommendedMax: 45,
      unit: '%',
    ),
    MissionTypes.iliBuilding: MissionTypeFieldConfig(
      fieldKey: 'min_ili',
      label: 'ILI Mínimo',
      hint: 'Recomendado: 3-6 meses de despesas',
      validationType: 'INDICATOR_THRESHOLD',
      defaultValue: 3,
      min: 0.5,
      max: 24,
      recommendedMin: 3,
      recommendedMax: 6,
      unit: 'meses',
      isDecimal: true,
    ),
    MissionTypes.categoryReduction: MissionTypeFieldConfig(
      fieldKey: 'target_reduction_percent',
      label: 'Redução Alvo',
      hint: 'Reduções de 10-20% são mais alcançáveis',
      validationType: 'CATEGORY_REDUCTION',
      defaultValue: 15,
      min: 5,
      max: 80,
      recommendedMin: 10,
      recommendedMax: 25,
      unit: '%',
    ),
  };

  static MissionTypeFieldConfig? get(String type) => configs[type];
}

/// Presets de XP e duração por dificuldade
class DifficultyPreset {
  final int xpMin;
  final int xpMax;
  final int xpDefault;
  final int durationMin;
  final int durationMax;
  final int durationDefault;

  const DifficultyPreset({
    required this.xpMin,
    required this.xpMax,
    required this.xpDefault,
    required this.durationMin,
    required this.durationMax,
    required this.durationDefault,
  });
}

abstract final class DifficultyPresets {
  static const Map<String, DifficultyPreset> presets = {
    MissionDifficulties.easy: DifficultyPreset(
      xpMin: 30,
      xpMax: 80,
      xpDefault: 50,
      durationMin: 7,
      durationMax: 14,
      durationDefault: 7,
    ),
    MissionDifficulties.medium: DifficultyPreset(
      xpMin: 80,
      xpMax: 180,
      xpDefault: 100,
      durationMin: 14,
      durationMax: 21,
      durationDefault: 14,
    ),
    MissionDifficulties.hard: DifficultyPreset(
      xpMin: 180,
      xpMax: 350,
      xpDefault: 200,
      durationMin: 21,
      durationMax: 30,
      durationDefault: 21,
    ),
  };

  static DifficultyPreset? get(String difficulty) => presets[difficulty];
}

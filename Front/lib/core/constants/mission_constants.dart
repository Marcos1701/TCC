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

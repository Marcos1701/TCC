/// Constantes centralizadas para tipos de missão.
///
/// Este arquivo define os 5 tipos oficiais de missão do sistema,
/// suas cores, ícones e labels para exibição.
///
/// Os tipos são alinhados com o backend (Api/finance/models/mission.py).
library;

import 'package:flutter/material.dart';

/// Tipos de missão suportados pelo sistema.
///
/// Alinhados com [Mission.MissionType] no backend.
abstract final class MissionTypes {
  /// Primeiros passos do usuário - registrar transações iniciais.
  static const String onboarding = 'ONBOARDING';

  /// Aumentar a Taxa de Poupança Pessoal (TPS).
  static const String tpsImprovement = 'TPS_IMPROVEMENT';

  /// Reduzir a Razão Dívida/Renda (RDR).
  static const String rdrReduction = 'RDR_REDUCTION';

  /// Construir o Índice de Liquidez Imediata (ILI).
  static const String iliBuilding = 'ILI_BUILDING';

  /// Reduzir gastos em categoria específica.
  static const String categoryReduction = 'CATEGORY_REDUCTION';

  /// Lista de todos os tipos válidos.
  static const List<String> all = [
    onboarding,
    tpsImprovement,
    rdrReduction,
    iliBuilding,
    categoryReduction,
  ];
}

/// Níveis de dificuldade das missões.
abstract final class MissionDifficulties {
  static const String easy = 'EASY';
  static const String medium = 'MEDIUM';
  static const String hard = 'HARD';

  static const List<String> all = [easy, medium, hard];
}

/// Tiers de usuário para geração de missões.
abstract final class UserTiers {
  /// Níveis 1-5: Usuários iniciantes.
  static const String beginner = 'BEGINNER';

  /// Níveis 6-15: Usuários intermediários.
  static const String intermediate = 'INTERMEDIATE';

  /// Níveis 16+: Usuários avançados.
  static const String advanced = 'ADVANCED';

  static const List<String> all = [beginner, intermediate, advanced];
}

/// Labels amigáveis para tipos de missão.
///
/// Retorna descrições curtas em português para exibição ao usuário.
abstract final class MissionTypeLabels {
  /// Mapa de tipo -> label curto.
  static const Map<String, String> short = {
    MissionTypes.onboarding: 'Primeiros Passos',
    MissionTypes.tpsImprovement: 'Poupança',
    MissionTypes.rdrReduction: 'Controle de Dívidas',
    MissionTypes.iliBuilding: 'Reserva de Emergência',
    MissionTypes.categoryReduction: 'Redução de Gastos',
  };

  /// Mapa de tipo -> label descritivo.
  static const Map<String, String> descriptive = {
    MissionTypes.onboarding: 'Primeiros Passos',
    MissionTypes.tpsImprovement: 'Aumentar Poupança (TPS)',
    MissionTypes.rdrReduction: 'Reduzir Gastos Recorrentes (RDR)',
    MissionTypes.iliBuilding: 'Construir Reserva (ILI)',
    MissionTypes.categoryReduction: 'Reduzir Gastos em Categoria',
  };

  /// Retorna o label curto para um tipo de missão.
  static String getShort(String type) => short[type] ?? 'Missão';

  /// Retorna o label descritivo para um tipo de missão.
  static String getDescriptive(String type) => descriptive[type] ?? type;
}

/// Labels amigáveis para dificuldades.
abstract final class DifficultyLabels {
  static const Map<String, String> labels = {
    MissionDifficulties.easy: 'Fácil',
    MissionDifficulties.medium: 'Média',
    MissionDifficulties.hard: 'Difícil',
  };

  static String get(String difficulty) => labels[difficulty] ?? difficulty;
}

/// Labels amigáveis para tiers de usuário.
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

/// Cores associadas a cada tipo de missão.
abstract final class MissionTypeColors {
  static const Map<String, Color> colors = {
    MissionTypes.onboarding: Color(0xFF9C27B0), // Roxo
    MissionTypes.tpsImprovement: Color(0xFF4CAF50), // Verde
    MissionTypes.rdrReduction: Color(0xFFF44336), // Vermelho
    MissionTypes.iliBuilding: Color(0xFF2196F3), // Azul
    MissionTypes.categoryReduction: Color(0xFFFF9800), // Laranja
  };

  /// Cor padrão para tipos desconhecidos.
  static const Color defaultColor = Color(0xFF607D8B); // Cinza

  /// Retorna a cor para um tipo de missão.
  static Color get(String type) => colors[type] ?? defaultColor;
}

/// Cores associadas a cada nível de dificuldade.
abstract final class DifficultyColors {
  static const Map<String, Color> colors = {
    MissionDifficulties.easy: Color(0xFF4CAF50), // Verde
    MissionDifficulties.medium: Color(0xFFFFC107), // Amarelo
    MissionDifficulties.hard: Color(0xFFF44336), // Vermelho
  };

  static const Color defaultColor = Color(0xFFFFC107);

  static Color get(String difficulty) => colors[difficulty] ?? defaultColor;
}

/// Ícones associados a cada tipo de missão.
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

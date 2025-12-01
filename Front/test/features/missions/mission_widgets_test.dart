import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tcc_gen_app/core/models/category.dart';
import 'package:tcc_gen_app/core/models/mission.dart';
import 'package:tcc_gen_app/core/network/api_client.dart';
import 'package:tcc_gen_app/core/repositories/finance_repository.dart';
import 'package:tcc_gen_app/core/services/analytics_service.dart';
import 'package:tcc_gen_app/features/missions/data/missions_viewmodel.dart';
import 'package:tcc_gen_app/features/missions/presentation/widgets/mission_catalog_highlights.dart';
import 'package:tcc_gen_app/features/missions/presentation/widgets/mission_impact_visualization.dart';
import 'package:tcc_gen_app/features/missions/presentation/widgets/mission_progress_detail_widget.dart';

import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockPathProviderPlatform extends Fake
    with MockPlatformInterfaceMixin
    implements PathProviderPlatform {
  @override
  Future<String?> getApplicationDocumentsPath() async {
    return '.';
  }
}

class MockApiClient extends Fake implements ApiClient {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  
  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    FlutterSecureStorage.setMockInitialValues({});
    PathProviderPlatform.instance = MockPathProviderPlatform();
    
    await Hive.initFlutter();
    await Hive.openBox('categories_cache');
    await Hive.openBox('missions_cache');
    await Hive.openBox('dashboard_cache');
  });

  AnalyticsService.clearEvents();

  group('Mission widgets', () {
    testWidgets('MissionProgressDetailWidget renders actionable summaries', (tester) async {
      final mission = _buildMission();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MissionProgressDetailWidget(mission: mission),
          ),
        ),
      );

      expect(find.text('O que precisa ser feito'), findsOneWidget);
      expect(find.textContaining('Reduza alimentação em 15%'), findsOneWidget);
      expect(find.text('Como avançar'), findsOneWidget);
      expect(
        find.text('Complete 2 ações rápidas por semana.'),
        findsOneWidget,
      );
      expect(find.text('Como o progresso é acompanhado'), findsOneWidget);
    });

    testWidgets('MissionRecommendationsSection shows fetched missions', skip: true, (tester) async {
      final missions = [_buildMission()];
      final repository = _FakeFinanceRepository(
        recommended: missions,
        categoryMissions: {1: missions},
        goalMissions: {10: missions},
        context: _sampleContext,
      );
      final viewModel = MissionsViewModel(repository: repository);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MissionRecommendationsSection(viewModel: viewModel),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Redução Alimentação'), findsOneWidget);
      expect(find.text('Missões prioritárias'), findsOneWidget);
    });

    testWidgets('MissionImpactVisualization renders indicators and opportunities', (tester) async {
      final repository = _FakeFinanceRepository(
        recommended: [_buildMission()],
        categoryMissions: const {},
        goalMissions: const {},
        context: _sampleContext,
      );
      final viewModel = MissionsViewModel(repository: repository);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MissionImpactVisualization(viewModel: viewModel),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Impacto atual'), findsOneWidget);
      expect(find.textContaining('Próximos ajustes'), findsOneWidget);
      expect(find.text('Reduza Alimentação'), findsOneWidget);
    });
  });
}

class _FakeFinanceRepository extends FinanceRepository {
  _FakeFinanceRepository({
    required this.recommended,
    required this.categoryMissions,
    required this.goalMissions,
    required this.context,
  }) : super(client: MockApiClient());

  final List<MissionModel> recommended;
  final Map<int, List<MissionModel>> categoryMissions;
  final Map<int, List<MissionModel>> goalMissions;
  final Map<String, dynamic> context;

  @override
  Future<List<MissionModel>> fetchRecommendedMissions({
    String? missionType,
    String? difficulty,
    int? limit,
  }) async {
    return recommended;
  }

  @override
  Future<List<MissionModel>> fetchMissionsByCategory(
    int categoryId, {
    String? difficulty,
    bool includeInactive = false,
  }) async {
    return categoryMissions[categoryId] ?? const [];
  }

  @override
  Future<List<MissionModel>> fetchMissionsByGoal(
    int goalId, {
    String? missionType,
    bool includeCompleted = false,
  }) async {
    return goalMissions[goalId] ?? const [];
  }

  @override
  Future<Map<String, dynamic>> fetchMissionContextAnalysis({
    bool forceRefresh = false,
  }) async {
    return context;
  }
}

MissionModel _buildMission() {
  const category = CategoryModel(
    id: 1,
    name: 'Alimentação',
    type: 'expense',
    color: '#FF5722',
  );

  return MissionModel(
    id: 1,
    title: 'Redução Alimentação',
    description: 'Reduza o orçamento de alimentação neste mês.',
    rewardPoints: 120,
    difficulty: 'MEDIUM',
    missionType: 'CATEGORY_REDUCTION',
    priority: 1,
    isActive: true,
    targetTps: null,
    targetRdr: null,
    minIli: null,
    maxIli: null,
    minTransactions: null,
    durationDays: 30,
    validationType: 'CATEGORY_REDUCTION',
    requiresConsecutiveDays: true,
    minConsecutiveDays: 7,
    targetCategory: category.id,
    targetCategoryData: category,
    targetCategories: const [],
    targetReductionPercent: 15,
    categorySpendingLimit: null,
    targetGoal: 10,
    goalProgressTarget: 0.6,
    savingsIncreaseAmount: null,
    requiresDailyAction: true,
    minDailyActions: 2,
    impacts: const [
      {'label': 'TPS', 'value': '+5%'}
    ],
    tips: const [
      {'text': 'Complete 2 ações rápidas por semana.'},
    ],
    minTransactionFrequency: null,
    transactionTypeFilter: 'EXPENSE',
    requiresPaymentTracking: false,
    minPaymentsCount: null,
    isSystemGenerated: true,
    generationContext: const {'category': 'food'},
    typeDisplay: 'Redução categoria',
    difficultyDisplay: 'Moderado',
    validationTypeDisplay: 'Redução percentual',
    source: 'template',
    targetInfo: const {
      'headline': 'Reduza alimentação em 15%',
      'targets': [
        {'metric': 'CATEGORY', 'label': 'Alimentação'}
      ],
    },
    createdAt: DateTime(2024, 1, 1),
    updatedAt: DateTime(2024, 1, 10),
  );
}

const Map<String, dynamic> _sampleContext = {
  'indicators': {
    'TPS': {'current': 0.35, 'target': 0.50},
    'RDR': {'current': 0.22, 'target': 0.18},
  },
  'opportunities': [
    {
      'metric': 'CATEGORY',
      'title': 'Reduza Alimentação',
      'detail': 'Últimas semanas acima da média histórica.',
      'delta': '-12%',
      'next_step': 'Revise pedidos de delivery.',
    }
  ],
};

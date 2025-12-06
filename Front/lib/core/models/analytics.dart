library;

class TierInfo {
  final String tier;
  final int level;
  final int xp;
  final int nextLevelXp;
  final int xpNeeded;
  final double xpProgressInLevel;
  final TierRange tierRange;
  final double tierProgress;
  final String? nextTier;
  final List<RecommendedMissionType> recommendedMissionTypes;
  final String tierDescription;

  TierInfo({
    required this.tier,
    required this.level,
    required this.xp,
    required this.nextLevelXp,
    required this.xpNeeded,
    required this.xpProgressInLevel,
    required this.tierRange,
    required this.tierProgress,
    this.nextTier,
    required this.recommendedMissionTypes,
    required this.tierDescription,
  });

  factory TierInfo.fromJson(Map<String, dynamic> json) {
    return TierInfo(
      tier: json['tier'] as String,
      level: json['level'] as int,
      xp: json['xp'] as int,
      nextLevelXp: json['next_level_xp'] as int,
      xpNeeded: json['xp_needed'] as int,
      xpProgressInLevel: (json['xp_progress_in_level'] as num).toDouble(),
      tierRange: TierRange.fromJson(json['tier_range'] as Map<String, dynamic>),
      tierProgress: (json['tier_progress'] as num).toDouble(),
      nextTier: json['next_tier'] as String?,
      recommendedMissionTypes: (json['recommended_mission_types'] as List)
          .map((e) => RecommendedMissionType.fromJson(e as Map<String, dynamic>))
          .toList(),
      tierDescription: json['tier_description'] as String,
    );
  }
}

class TierRange {
  final int min;
  final int max;

  TierRange({required this.min, required this.max});

  factory TierRange.fromJson(Map<String, dynamic> json) {
    return TierRange(
      min: json['min'] as int,
      max: json['max'] as int,
    );
  }
}

class RecommendedMissionType {
  final String type;
  final String description;

  RecommendedMissionType({
    required this.type,
    required this.description,
  });

  factory RecommendedMissionType.fromJson(Map<String, dynamic> json) {
    return RecommendedMissionType(
      type: json['type'] as String,
      description: json['description'] as String,
    );
  }
}

class IndicatorEvolution {
  final double average;
  final double min;
  final double max;
  final double first;
  final double last;
  final String trend;

  IndicatorEvolution({
    required this.average,
    required this.min,
    required this.max,
    required this.first,
    required this.last,
    required this.trend,
  });

  factory IndicatorEvolution.fromJson(Map<String, dynamic> json) {
    return IndicatorEvolution(
      average: (json['average'] as num).toDouble(),
      min: (json['min'] as num).toDouble(),
      max: (json['max'] as num).toDouble(),
      first: (json['first'] as num).toDouble(),
      last: (json['last'] as num).toDouble(),
      trend: json['trend'] as String,
    );
  }
}

class ConsistencyData {
  final double rate;
  final int daysRegistered;
  final int totalDays;

  ConsistencyData({
    required this.rate,
    required this.daysRegistered,
    required this.totalDays,
  });

  factory ConsistencyData.fromJson(Map<String, dynamic> json) {
    return ConsistencyData(
      rate: (json['rate'] as num).toDouble(),
      daysRegistered: json['days_registered'] as int,
      totalDays: json['total_days'] as int,
    );
  }
}

class EvolutionData {
  final bool hasData;
  final int periodDays;
  final IndicatorEvolution? tps;
  final IndicatorEvolution? rdr;
  final IndicatorEvolution? ili;
  final ConsistencyData? consistency;
  final List<String> problems;
  final List<String> strengths;

  EvolutionData({
    required this.hasData,
    required this.periodDays,
    this.tps,
    this.rdr,
    this.ili,
    this.consistency,
    this.problems = const [],
    this.strengths = const [],
  });

  factory EvolutionData.fromJson(Map<String, dynamic> json) {
    final hasData = json['has_data'] as bool? ?? false;
    
    return EvolutionData(
      hasData: hasData,
      periodDays: json['period_days'] as int? ?? 0,
      tps: hasData && json.containsKey('tps') 
          ? IndicatorEvolution.fromJson(json['tps'] as Map<String, dynamic>) 
          : null,
      rdr: hasData && json.containsKey('rdr')
          ? IndicatorEvolution.fromJson(json['rdr'] as Map<String, dynamic>)
          : null,
      ili: hasData && json.containsKey('ili')
          ? IndicatorEvolution.fromJson(json['ili'] as Map<String, dynamic>)
          : null,
      consistency: hasData && json.containsKey('consistency')
          ? ConsistencyData.fromJson(json['consistency'] as Map<String, dynamic>)
          : null,
      problems: hasData ? List<String>.from(json['problems'] as List? ?? []) : [],
      strengths: hasData ? List<String>.from(json['strengths'] as List? ?? []) : [],
    );
  }
}

class CategoryPattern {
  final double total;
  final int count;
  final int daysWithSpending;
  final double averageDaily;
  final double maxDaily;
  final double frequency;

  CategoryPattern({
    required this.total,
    required this.count,
    required this.daysWithSpending,
    required this.averageDaily,
    required this.maxDaily,
    required this.frequency,
  });

  factory CategoryPattern.fromJson(Map<String, dynamic> json) {
    return CategoryPattern(
      total: (json['total'] as num).toDouble(),
      count: json['count'] as int,
      daysWithSpending: json['days_with_spending'] as int,
      averageDaily: (json['average_daily'] as num).toDouble(),
      maxDaily: (json['max_daily'] as num).toDouble(),
      frequency: (json['frequency'] as num).toDouble(),
    );
  }
}

class CategoryRecommendation {
  final String category;
  final String type;
  final String reason;
  final double? suggestedLimit;
  final String priority;

  CategoryRecommendation({
    required this.category,
    required this.type,
    required this.reason,
    this.suggestedLimit,
    required this.priority,
  });

  factory CategoryRecommendation.fromJson(Map<String, dynamic> json) {
    return CategoryRecommendation(
      category: json['category'] as String,
      type: json['type'] as String,
      reason: json['reason'] as String,
      suggestedLimit: json['suggested_limit'] != null
          ? (json['suggested_limit'] as num).toDouble()
          : null,
      priority: json['priority'] as String,
    );
  }
}

class CategoryPatternsAnalysis {
  final bool hasData;
  final int periodDays;
  final Map<String, CategoryPattern> categories;
  final List<CategoryRecommendation> recommendations;
  final int totalCategories;

  CategoryPatternsAnalysis({
    required this.hasData,
    required this.periodDays,
    required this.categories,
    required this.recommendations,
    required this.totalCategories,
  });

  factory CategoryPatternsAnalysis.fromJson(Map<String, dynamic> json) {
    final categoriesMap = json['categories'] as Map<String, dynamic>? ?? {};
    
    return CategoryPatternsAnalysis(
      hasData: json['has_data'] as bool,
      periodDays: json['period_days'] as int,
      categories: categoriesMap.map(
        (k, v) => MapEntry(
          k,
          CategoryPattern.fromJson(v as Map<String, dynamic>),
        ),
      ),
      recommendations: (json['recommendations'] as List? ?? [])
          .map((e) => CategoryRecommendation.fromJson(e as Map<String, dynamic>))
          .toList(),
      totalCategories: json['total_categories'] as int,
    );
  }
}

class TierProgressionAnalysis {
  final String tier;
  final int level;
  final int xp;
  final int nextLevelXp;
  final String? nextTier;
  final double tierProgress;

  TierProgressionAnalysis({
    required this.tier,
    required this.level,
    required this.xp,
    required this.nextLevelXp,
    this.nextTier,
    required this.tierProgress,
  });

  factory TierProgressionAnalysis.fromJson(Map<String, dynamic> json) {
    return TierProgressionAnalysis(
      tier: json['tier'] as String,
      level: json['level'] as int,
      xp: json['xp'] as int,
      nextLevelXp: json['next_level_xp'] as int,
      nextTier: json['next_tier'] as String?,
      tierProgress: (json['tier_progress'] as num).toDouble(),
    );
  }
}

class MissionDistributionAnalysis {
  final int totalMissions;
  final int activeMissions;
  final int completedMissions;
  final List<String> underutilizedMissionTypes;
  final List<String> underutilizedValidationTypes;
  final Map<String, double> successRates;

  MissionDistributionAnalysis({
    required this.totalMissions,
    required this.activeMissions,
    required this.completedMissions,
    required this.underutilizedMissionTypes,
    required this.underutilizedValidationTypes,
    required this.successRates,
  });

  factory MissionDistributionAnalysis.fromJson(Map<String, dynamic> json) {
    final successRatesMap = json['success_rates'] as Map<String, dynamic>? ?? {};
    
    return MissionDistributionAnalysis(
      totalMissions: json['total_missions'] as int,
      activeMissions: json['active_missions'] as int,
      completedMissions: json['completed_missions'] as int,
      underutilizedMissionTypes:
          List<String>.from(json['underutilized_mission_types'] as List? ?? []),
      underutilizedValidationTypes:
          List<String>.from(json['underutilized_validation_types'] as List? ?? []),
      successRates: successRatesMap.map(
        (k, v) => MapEntry(k, (v as num).toDouble()),
      ),
    );
  }
}

class ComprehensiveContext {
  final int userId;
  final String username;
  final TierInfo tier;
  final Map<String, double> currentIndicators;
  final EvolutionData evolution;
  final List<String> recommendedFocus;
  final Map<String, bool> flags;

  ComprehensiveContext({
    required this.userId,
    required this.username,
    required this.tier,
    required this.currentIndicators,
    required this.evolution,
    required this.recommendedFocus,
    required this.flags,
  });

  factory ComprehensiveContext.fromJson(Map<String, dynamic> json) {
    final indicatorsMap = json['current_indicators'] as Map<String, dynamic>? ?? {};
    final flagsMap = json['flags'] as Map<String, dynamic>? ?? {};
    
    return ComprehensiveContext(
      userId: json['user_id'] as int,
      username: json['username'] as String,
      tier: TierInfo.fromJson(json['tier'] as Map<String, dynamic>),
      currentIndicators: indicatorsMap.map(
        (k, v) => MapEntry(k, (v as num).toDouble()),
      ),
      evolution: EvolutionData.fromJson(json['evolution'] as Map<String, dynamic>),
      recommendedFocus: List<String>.from(json['recommended_focus'] as List? ?? []),
      flags: flagsMap.map(
        (k, v) => MapEntry(k, v as bool),
      ),
    );
  }
}

class AnalyticsData {
  final bool success;
  final ComprehensiveContext comprehensiveContext;
  final CategoryPatternsAnalysis categoryPatterns;
  final TierProgressionAnalysis tierProgression;
  final MissionDistributionAnalysis missionDistribution;

  AnalyticsData({
    required this.success,
    required this.comprehensiveContext,
    required this.categoryPatterns,
    required this.tierProgression,
    required this.missionDistribution,
  });

  factory AnalyticsData.fromJson(Map<String, dynamic> json) {
    return AnalyticsData(
      success: json['success'] as bool,
      comprehensiveContext:
          ComprehensiveContext.fromJson(json['comprehensive_context'] as Map<String, dynamic>),
      categoryPatterns:
          CategoryPatternsAnalysis.fromJson(json['category_patterns'] as Map<String, dynamic>),
      tierProgression:
          TierProgressionAnalysis.fromJson(json['tier_progression'] as Map<String, dynamic>),
      missionDistribution:
          MissionDistributionAnalysis.fromJson(json['mission_distribution'] as Map<String, dynamic>),
    );
  }
}

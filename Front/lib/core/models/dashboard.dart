import 'mission.dart';
import 'mission_progress.dart';
import 'profile.dart';

class SummaryMetrics {
  const SummaryMetrics({
    required this.tps,
    required this.rdr,
    required this.ili,
    required this.totalIncome,
    required this.totalExpense,
  });

  final double tps;
  final double rdr;
  final double ili;
  final double totalIncome;
  final double totalExpense;

  factory SummaryMetrics.fromMap(Map<String, dynamic> map) {
    if (map.isEmpty) {
      return const SummaryMetrics(
        tps: 0.0,
        rdr: 0.0,
        ili: 0.0,
        totalIncome: 0.0,
        totalExpense: 0.0,
      );
    }
    
    return SummaryMetrics(
      tps: double.parse(map['tps']?.toString() ?? '0'),
      rdr: double.parse(map['rdr']?.toString() ?? '0'),
      ili: double.parse(map['ili']?.toString() ?? '0'),
      totalIncome: double.parse(map['total_income']?.toString() ?? '0'),
      totalExpense: double.parse(map['total_expense']?.toString() ?? '0'),
    );
  }
}

class CategorySlice {
  const CategorySlice({
    required this.name,
    required this.total,
    this.group,
  });

  final String name;
  final double total;
  final String? group;

  factory CategorySlice.fromMap(Map<String, dynamic> map) {
    return CategorySlice(
      name: map['name']?.toString() ?? 'Desconhecido',
      total: double.parse(map['total']?.toString() ?? '0'),
      group: map['group'] as String?,
    );
  }
}

class CashflowPoint {
  const CashflowPoint({
    required this.month,
    required this.income,
    required this.expense,
    required this.tps,
    required this.rdr,
    this.isProjection = false,
  });

  final String month;
  final double income;
  final double expense;
  final double tps;
  final double rdr;
  final bool isProjection;

  factory CashflowPoint.fromMap(Map<String, dynamic> map) {
    return CashflowPoint(
      month: map['month']?.toString() ?? '',
      income: double.parse(map['income']?.toString() ?? '0'),
      expense: double.parse(map['expense']?.toString() ?? '0'),
      tps: double.parse(map['tps']?.toString() ?? '0'),
      rdr: double.parse(map['rdr']?.toString() ?? '0'),
      isProjection: map['is_projection'] == true || map['isProjection'] == true,
    );
  }
}

class IndicatorInsight {
  const IndicatorInsight({
    required this.indicator,
    required this.severity,
    required this.title,
    required this.message,
    required this.value,
    required this.target,
  });

  final String indicator;
  final String severity;
  final String title;
  final String message;
  final double value;
  final double target;

  factory IndicatorInsight.fromMap(String indicator, Map<String, dynamic> map) {
    return IndicatorInsight(
      indicator: indicator,
      severity: map['severity']?.toString() ?? 'info',
      title: map['title']?.toString() ?? '',
      message: map['message']?.toString() ?? '',
      value: double.parse(map['value']?.toString() ?? '0'),
      target: double.parse(map['target']?.toString() ?? '0'),
    );
  }
}

class DashboardData {
  const DashboardData({
    required this.summary,
    required this.categories,
    required this.cashflow,
    required this.insights,
    required this.activeMissions,
    required this.recommendedMissions,
    required this.profile,
  });

  final SummaryMetrics summary;
  final Map<String, List<CategorySlice>> categories;
  final List<CashflowPoint> cashflow;
  final Map<String, IndicatorInsight> insights;
  final List<MissionProgressModel> activeMissions;
  final List<MissionModel> recommendedMissions;
  final ProfileModel profile;

  factory DashboardData.fromMap(Map<String, dynamic> map) {
    final rawCategories = map['categories'] as Map<String, dynamic>? ?? {};
    final parsedCategories = <String, List<CategorySlice>>{};
    for (final entry in rawCategories.entries) {
      final slices = (entry.value as List<dynamic>? ?? <dynamic>[])
          .map((e) => CategorySlice.fromMap(e as Map<String, dynamic>))
          .toList();
      parsedCategories[entry.key] = slices;
    }

    final rawInsights = map['insights'] as Map<String, dynamic>? ?? {};

    return DashboardData(
      summary: SummaryMetrics.fromMap(map['summary'] as Map<String, dynamic>? ?? {}),
      categories: parsedCategories,
      cashflow: (map['cashflow'] as List<dynamic>? ?? <dynamic>[])
          .map((e) => CashflowPoint.fromMap(e as Map<String, dynamic>))
          .toList(),
      insights: rawInsights.map(
        (key, value) => MapEntry(
          key,
          IndicatorInsight.fromMap(key, value as Map<String, dynamic>),
        ),
      ),
      activeMissions: (map['active_missions'] as List<dynamic>? ?? <dynamic>[])
          .map((e) => MissionProgressModel.fromMap(e as Map<String, dynamic>))
          .toList(),
      recommendedMissions:
          (map['recommended_missions'] as List<dynamic>? ?? <dynamic>[])
              .map((e) => MissionModel.fromMap(e as Map<String, dynamic>))
              .toList(),
      profile: ProfileModel.fromMap(map['profile'] as Map<String, dynamic>? ?? {}),
    );
  }
}

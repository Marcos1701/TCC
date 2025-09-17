import 'mission.dart';
import 'mission_progress.dart';
import 'profile.dart';

class SummaryMetrics {
  const SummaryMetrics({
    required this.tps,
    required this.rdr,
    required this.totalIncome,
    required this.totalExpense,
    required this.totalDebt,
  });

  final double tps;
  final double rdr;
  final double totalIncome;
  final double totalExpense;
  final double totalDebt;

  factory SummaryMetrics.fromMap(Map<String, dynamic> map) {
    return SummaryMetrics(
      tps: double.parse(map['tps'].toString()),
      rdr: double.parse(map['rdr'].toString()),
      totalIncome: double.parse(map['total_income'].toString()),
      totalExpense: double.parse(map['total_expense'].toString()),
      totalDebt: double.parse(map['total_debt'].toString()),
    );
  }
}

class CategorySlice {
  const CategorySlice({required this.name, required this.total});

  final String name;
  final double total;

  factory CategorySlice.fromMap(Map<String, dynamic> map) {
    return CategorySlice(
      name: map['name'] as String,
      total: double.parse(map['total'].toString()),
    );
  }
}

class CashflowPoint {
  const CashflowPoint({required this.month, required this.income, required this.expense});

  final String month;
  final double income;
  final double expense;

  factory CashflowPoint.fromMap(Map<String, dynamic> map) {
    return CashflowPoint(
      month: map['month'] as String,
      income: double.parse(map['income'].toString()),
      expense: double.parse(map['expense'].toString()),
    );
  }
}

class DashboardData {
  const DashboardData({
    required this.summary,
    required this.categories,
    required this.cashflow,
    required this.activeMissions,
    required this.recommendedMissions,
    required this.profile,
  });

  final SummaryMetrics summary;
  final Map<String, List<CategorySlice>> categories;
  final List<CashflowPoint> cashflow;
  final List<MissionProgressModel> activeMissions;
  final List<MissionModel> recommendedMissions;
  final ProfileModel profile;

  factory DashboardData.fromMap(Map<String, dynamic> map) {
    final rawCategories = map['categories'] as Map<String, dynamic>? ?? {};
    final parsedCategories = <String, List<CategorySlice>>{};
    for (final entry in rawCategories.entries) {
      parsedCategories[entry.key] = (entry.value as List<dynamic>)
          .map((e) => CategorySlice.fromMap(e as Map<String, dynamic>))
          .toList();
    }

    return DashboardData(
      summary: SummaryMetrics.fromMap(map['summary'] as Map<String, dynamic>),
      categories: parsedCategories,
      cashflow: (map['cashflow'] as List<dynamic>)
          .map((e) => CashflowPoint.fromMap(e as Map<String, dynamic>))
          .toList(),
      activeMissions: (map['active_missions'] as List<dynamic>)
          .map((e) => MissionProgressModel.fromMap(e as Map<String, dynamic>))
          .toList(),
      recommendedMissions: (map['recommended_missions'] as List<dynamic>)
          .map((e) => MissionModel.fromMap(e as Map<String, dynamic>))
          .toList(),
      profile: ProfileModel.fromMap(map['profile'] as Map<String, dynamic>),
    );
  }
}

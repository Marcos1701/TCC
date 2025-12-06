import 'mission.dart';

class MissionProgressModel {
  const MissionProgressModel({
    required this.id,
    required this.status,
    required this.progress,
    this.initialTps,
    this.initialRdr,
    this.initialIli,
    this.initialTransactionCount,
    this.startedAt,
    this.completedAt,
    required this.updatedAt,
    required this.mission,
    this.baselineCategorySpending,
    this.baselinePeriodDays,
    this.initialSavingsAmount,
    this.currentStreak,
    this.maxStreak,
    this.daysMetCriteria,
    this.daysViolatedCriteria,
    this.lastViolationDate,
    this.validationDetails,
    this.daysRemaining,
    this.progressPercentage,
    this.currentVsInitial,
    this.detailedMetrics,
    this.progressStatus,
  });

  final int id;
  final String status;
  final double progress;
  final double? initialTps;
  final double? initialRdr;
  final double? initialIli;
  final int? initialTransactionCount;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final DateTime updatedAt;
  final MissionModel mission;
  
  final double? baselineCategorySpending;
  final int? baselinePeriodDays;
  final double? initialSavingsAmount;
  final int? currentStreak;
  final int? maxStreak;
  final int? daysMetCriteria;
  final int? daysViolatedCriteria;
  final DateTime? lastViolationDate;
  final Map<String, dynamic>? validationDetails;
  
  final int? daysRemaining;
  final String? progressPercentage;
  final Map<String, dynamic>? currentVsInitial;
  final List<Map<String, dynamic>>? detailedMetrics;
  final Map<String, dynamic>? progressStatus;

  factory MissionProgressModel.fromMap(Map<String, dynamic> map) {
    return MissionProgressModel(
      id: int.parse(map['id'].toString()),
      status: map['status'] as String,
      progress: double.parse(map['progress'].toString()),
      initialTps: map['initial_tps'] != null
          ? double.parse(map['initial_tps'].toString())
          : null,
      initialRdr: map['initial_rdr'] != null
          ? double.parse(map['initial_rdr'].toString())
          : null,
      initialIli: map['initial_ili'] != null
          ? double.parse(map['initial_ili'].toString())
          : null,
      initialTransactionCount: map['initial_transaction_count'] as int?,
      startedAt: map['started_at'] != null
          ? DateTime.parse(map['started_at'] as String)
          : null,
      completedAt: map['completed_at'] != null
          ? DateTime.parse(map['completed_at'] as String)
          : null,
      updatedAt: DateTime.parse(map['updated_at'] as String),
      mission: MissionModel.fromMap(map['mission'] as Map<String, dynamic>),
      baselineCategorySpending: map['baseline_category_spending'] != null
          ? double.parse(map['baseline_category_spending'].toString())
          : null,
      baselinePeriodDays: map['baseline_period_days'] as int?,
      initialSavingsAmount: map['initial_savings_amount'] != null
          ? double.parse(map['initial_savings_amount'].toString())
          : null,
      currentStreak: map['current_streak'] as int?,
      maxStreak: map['max_streak'] as int?,
      daysMetCriteria: map['days_met_criteria'] as int?,
      daysViolatedCriteria: map['days_violated_criteria'] as int?,
      lastViolationDate: map['last_violation_date'] != null
          ? DateTime.parse(map['last_violation_date'] as String)
          : null,
      validationDetails: map['validation_details'] as Map<String, dynamic>?,
      daysRemaining: map['days_remaining'] as int?,
      progressPercentage: map['progress_percentage'] as String?,
      currentVsInitial: map['current_vs_initial'] as Map<String, dynamic>?,
      detailedMetrics: map['detailed_metrics'] != null
          ? (map['detailed_metrics'] as List<dynamic>)
              .map((e) => e as Map<String, dynamic>)
              .toList()
          : null,
      progressStatus: map['progress_status'] as Map<String, dynamic>?,
    );
  }

  bool get isActive => status == 'PENDING' || status == 'ACTIVE';

  bool get isCompleted => status == 'COMPLETED';

  bool get isFailed => status == 'FAILED';

  int get statusColor {
    switch (status) {
      case 'COMPLETED':
        return 0xFF007932;
      case 'FAILED':
        return 0xFFEF4123;
      case 'ACTIVE':
        return 0xFF034EA2;
      default:
        return 0xFF808080;
    }
  }

  String get statusLabel {
    switch (status) {
      case 'PENDING':
        return 'Pendente';
      case 'ACTIVE':
        return 'Em andamento';
      case 'COMPLETED':
        return 'Concluída';
      case 'FAILED':
        return 'Expirada';
      default:
        return status;
    }
  }
  
  bool get hasActiveStreak => (currentStreak ?? 0) > 0;
  
  String get streakDescription {
    if (currentStreak == null || currentStreak == 0) {
      return 'Nenhuma sequência ativa';
    }
    final days = currentStreak == 1 ? 'dia' : 'dias';
    return '$currentStreak $days consecutivos';
  }
  
  String get progressFormatted {
    return '${progress.toStringAsFixed(1)}%';
  }
  
  String? get progressMessage {
    return progressStatus?['message'] as String?;
  }
  
  bool get canComplete {
    return progressStatus?['can_complete'] as bool? ?? false;
  }
  
  bool get isOnTrack {
    return progressStatus?['on_track'] as bool? ?? false;
  }
  
  List<Map<String, dynamic>> get metrics {
    return detailedMetrics ?? [];
  }
}



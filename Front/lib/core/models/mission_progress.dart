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

  factory MissionProgressModel.fromMap(Map<String, dynamic> map) {
    return MissionProgressModel(
      id: map['id'] as int,
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
    );
  }

  /// Retorna true se a missão está ativa (PENDING ou ACTIVE)
  bool get isActive => status == 'PENDING' || status == 'ACTIVE';

  /// Retorna true se a missão foi completada
  bool get isCompleted => status == 'COMPLETED';

  /// Retorna true se a missão falhou
  bool get isFailed => status == 'FAILED';

  /// Retorna a cor baseada no status
  int get statusColor {
    switch (status) {
      case 'COMPLETED':
        return 0xFF007932; // Verde
      case 'FAILED':
        return 0xFFEF4123; // Vermelho
      case 'ACTIVE':
        return 0xFF034EA2; // Azul
      default:
        return 0xFF808080; // Cinza
    }
  }

  /// Retorna label amigável do status
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
}

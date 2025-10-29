import 'mission.dart';

class MissionProgressModel {
  const MissionProgressModel({
    required this.id,
    required this.status,
    required this.progress,
    this.startedAt,
    this.completedAt,
    required this.updatedAt,
    required this.mission,
  });

  final int id;
  final String status;
  final double progress;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final DateTime updatedAt;
  final MissionModel mission;

  factory MissionProgressModel.fromMap(Map<String, dynamic> map) {
    return MissionProgressModel(
      id: map['id'] as int,
      status: map['status'] as String,
      progress: double.parse(map['progress'].toString()),
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
}

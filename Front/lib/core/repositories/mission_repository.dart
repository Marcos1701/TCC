import 'package:flutter/foundation.dart';

import '../models/mission.dart';
import '../models/mission_progress.dart';
import '../network/endpoints.dart';
import '../services/cache_service.dart';
import 'base_repository.dart';

/// Repositório para operações de missões.
class MissionRepository extends BaseRepository {
  MissionRepository({super.client});

  Future<MissionProgressModel> startMission(int missionId) async {
    final response = await client.client.post<Map<String, dynamic>>(
      ApiEndpoints.missionProgress,
      data: {'mission_id': missionId},
    );
    return MissionProgressModel.fromMap(response.data ?? <String, dynamic>{});
  }

  Future<MissionProgressModel> updateMission({
    required int progressId,
    String? status,
    double? progress,
  }) async {
    final payload = <String, dynamic>{};
    if (status != null) payload['status'] = status;
    if (progress != null) payload['progress'] = progress;
    final response = await client.client.patch<Map<String, dynamic>>(
      '${ApiEndpoints.missionProgress}$progressId/',
      data: payload,
    );
    return MissionProgressModel.fromMap(response.data ?? <String, dynamic>{});
  }

  Future<List<MissionModel>> fetchMissions() async {
    final cached = CacheService.getCachedMissions();
    if (cached != null) {
      return cached.map((e) => MissionModel.fromMap(e)).toList();
    }
    
    final response = await client.client.get<dynamic>(ApiEndpoints.missions);
    final items = extractListFromResponse(response.data);
    final missions = items
        .map((e) => MissionModel.fromMap(e as Map<String, dynamic>))
        .toList();
    
    final invalidMissions = missions.where((m) => m.hasPlaceholders()).toList();
    if (invalidMissions.isNotEmpty) {
      debugPrint(
        '⚠️ API returned ${invalidMissions.length} mission(s) with placeholders:\n'
        '${invalidMissions.map((m) => '  - ID ${m.id}: "${m.title}" -> ${m.getPlaceholders()}').join('\n')}'
      );
    }
    
    await CacheService.cacheMissions(
      missions.map((m) => m.toMap()).toList(),
    );
    
    return missions;
  }

  Future<List<MissionModel>> fetchRecommendedMissions({
    String? missionType,
    String? difficulty,
    int? limit,
  }) async {
    final query = <String, dynamic>{};
    if (missionType != null && missionType.isNotEmpty) {
      query['type'] = missionType;
    }
    if (difficulty != null && difficulty.isNotEmpty) {
      query['difficulty'] = difficulty;
    }
    if (limit != null && limit > 0) {
      query['limit'] = limit;
    }

    final response = await client.client.get<dynamic>(
      ApiEndpoints.missionsRecommend,
      queryParameters: query.isEmpty ? null : query,
    );

    final items = extractListFromResponse(response.data);
    return items
        .map((e) => MissionModel.fromMap(
              Map<String, dynamic>.from(e as Map),
            ))
        .toList();
  }

  Future<List<MissionModel>> fetchMissionsByCategory(
    int categoryId, {
    String? difficulty,
    bool includeInactive = false,
  }) async {
    final query = <String, dynamic>{};
    if (difficulty != null && difficulty.isNotEmpty) {
      query['difficulty'] = difficulty;
    }
    if (includeInactive) {
      query['include_inactive'] = true;
    }

    final response = await client.client.get<dynamic>(
      '${ApiEndpoints.missionsByCategory}$categoryId/',
      queryParameters: query.isEmpty ? null : query,
    );

    final items = extractListFromResponse(response.data);
    return items
        .map((e) => MissionModel.fromMap(
              Map<String, dynamic>.from(e as Map),
            ))
        .toList();
  }

  Future<List<MissionModel>> fetchMissionsByGoal(
    int goalId, {
    String? missionType,
    bool includeCompleted = false,
  }) async {
    final query = <String, dynamic>{};
    if (missionType != null && missionType.isNotEmpty) {
      query['type'] = missionType;
    }
    if (includeCompleted) {
      query['include_completed'] = true;
    }

    final response = await client.client.get<dynamic>(
      '${ApiEndpoints.missionsByGoal}$goalId/',
      queryParameters: query.isEmpty ? null : query,
    );

    final items = extractListFromResponse(response.data);
    return items
        .map((e) => MissionModel.fromMap(
              Map<String, dynamic>.from(e as Map),
            ))
        .toList();
  }

  Future<Map<String, dynamic>?> fetchMissionContextAnalysis({
    bool forceRefresh = false,
  }) async {
    try {
      final query = forceRefresh ? {'force_refresh': true} : null;
      final response = await client.client.get<Map<String, dynamic>>(
        ApiEndpoints.missionsContextAnalysis,
        queryParameters: query,
      );
      return response.data != null
          ? Map<String, dynamic>.from(response.data!)
          : null;
    } catch (e) {
      debugPrint('⚠️ Context analysis not available');
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> fetchMissionTemplates({
    bool includeInactive = false,
  }) async {
    final response = await client.client.get<dynamic>(
      ApiEndpoints.missionsTemplates,
      queryParameters: includeInactive ? {'include_inactive': true} : null,
    );
    final items = extractListFromResponse(response.data);
    return items
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  Future<MissionModel> generateMissionFromTemplate({
    required String templateKey,
    Map<String, dynamic>? overrides,
  }) async {
    final payload = {
      'template_key': templateKey,
      if (overrides != null && overrides.isNotEmpty) 'overrides': overrides,
    };
    final response = await client.client.post<Map<String, dynamic>>(
      ApiEndpoints.missionsGenerateFromTemplate,
      data: payload,
    );
    return MissionModel.fromMap(response.data ?? <String, dynamic>{});
  }

  Future<Map<String, dynamic>> fetchMissionProgressDetails(int id) async {
    final response = await client.client.get<Map<String, dynamic>>(
        '${ApiEndpoints.missionProgress}$id/details/');
    return response.data ?? <String, dynamic>{};
  }
}

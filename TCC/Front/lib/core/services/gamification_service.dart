import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';

import '../models/mission_progress.dart';
import '../models/profile.dart';
import '../widgets/celebration_overlay.dart';

class GamificationService {
  static const _storage = FlutterSecureStorage();
  static const _lastLevelKey = 'last_level';
  static const _completedMissionsKey = 'completed_missions';

  static Future<void> checkLevelUp({
    required BuildContext context,
    required ProfileModel profile,
  }) async {
    final lastLevelStr = await _storage.read(key: _lastLevelKey);
    final lastLevel = lastLevelStr != null ? int.tryParse(lastLevelStr) ?? 1 : 1;

    if (profile.level > lastLevel) {
      final coinsEarned = (profile.level - lastLevel) * 100;

      await _storage.write(key: _lastLevelKey, value: profile.level.toString());

      if (context.mounted) {
        CelebrationOverlay.showLevelUp(
          context: context,
          newLevel: profile.level,
          coinsEarned: coinsEarned,
        );
      }
    }
  }

  static Future<void> checkMissionCompletions({
    required BuildContext context,
    required List<MissionProgressModel> missions,
  }) async {
    final completedStr = await _storage.read(key: _completedMissionsKey);
    final Set<int> alreadyCelebrated = completedStr != null
        ? (jsonDecode(completedStr) as List).cast<int>().toSet()
        : {};

    final newlyCompleted = missions.where((m) =>
        m.isCompleted &&
        m.completedAt != null &&
        !alreadyCelebrated.contains(m.id)).toList();

    for (final mission in newlyCompleted) {
      alreadyCelebrated.add(mission.id);

      final coinsEarned = mission.mission.rewardPoints;

      if (context.mounted) {
        CelebrationOverlay.showMissionComplete(
          context: context,
          missionTitle: mission.mission.title,
          coinsEarned: coinsEarned,
        );

        await Future.delayed(const Duration(milliseconds: 500));
      }
    }

    await _storage.write(
      key: _completedMissionsKey,
      value: jsonEncode(alreadyCelebrated.toList()),
    );
  }

  static Future<void> clearCelebrationHistory() async {
    await _storage.delete(key: _lastLevelKey);
    await _storage.delete(key: _completedMissionsKey);
  }

  static Future<void> initialize(ProfileModel profile) async {
    final lastLevelStr = await _storage.read(key: _lastLevelKey);
    if (lastLevelStr == null) {
      await _storage.write(key: _lastLevelKey, value: profile.level.toString());
    }
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';

import '../models/mission_progress.dart';
import '../models/profile.dart';
import '../widgets/celebration_overlay.dart';

/// Service to manage gamification and celebrations
class GamificationService {
  static const _storage = FlutterSecureStorage();
  static const _lastLevelKey = 'last_level';
  static const _completedMissionsKey = 'completed_missions';

  /// Checks if level up occurred and shows celebration
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

  /// Checks for newly completed missions and shows celebration
  static Future<void> checkMissionCompletions({
    required BuildContext context,
    required List<MissionProgressModel> missions,
  }) async {
    // Get list of already celebrated missions
    final completedStr = await _storage.read(key: _completedMissionsKey);
    final Set<int> alreadyCelebrated = completedStr != null
        ? (jsonDecode(completedStr) as List).cast<int>().toSet()
        : {};

    // Check completed missions that haven't been celebrated yet
    final newlyCompleted = missions.where((m) =>
        m.isCompleted &&
        m.completedAt != null &&
        !alreadyCelebrated.contains(m.id)).toList();

    // Celebrate each new mission
    for (final mission in newlyCompleted) {
      // Add to celebrated list
      alreadyCelebrated.add(mission.id);

      // Calculate coins earned based on mission reward
      final coinsEarned = mission.mission.rewardPoints;

      // Show celebration if context is still mounted
      if (context.mounted) {
        CelebrationOverlay.showMissionComplete(
          context: context,
          missionTitle: mission.mission.title,
          coinsEarned: coinsEarned,
        );

        // Wait a bit before next celebration
        await Future.delayed(const Duration(milliseconds: 500));
      }
    }

    // Save updated list
    await _storage.write(
      key: _completedMissionsKey,
      value: jsonEncode(alreadyCelebrated.toList()),
    );
  }

  /// Clears celebration history (useful for debug)
  static Future<void> clearCelebrationHistory() async {
    await _storage.delete(key: _lastLevelKey);
    await _storage.delete(key: _completedMissionsKey);
  }

  /// Initializes the service with current level (should be called on first run)
  static Future<void> initialize(ProfileModel profile) async {
    final lastLevelStr = await _storage.read(key: _lastLevelKey);
    if (lastLevelStr == null) {
      // First time - save current level without celebrating
      await _storage.write(key: _lastLevelKey, value: profile.level.toString());
    }
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';

import '../models/mission_progress.dart';
import 'feedback_service.dart';

/// Service to notify about mission status
class MissionNotificationService {
  static const _storage = FlutterSecureStorage();
  static const _notifiedExpiringKey = 'notified_expiring_missions';
  static const _notifiedNewKey = 'notified_new_missions';
  static const _lastMissionCheckKey = 'last_mission_check';

  /// Checks for missions close to expiring and notifies the user
  static Future<void> checkExpiringMissions({
    required BuildContext context,
    required List<MissionProgressModel> missions,
  }) async {
    if (!context.mounted) return;

    // Get list of already notified missions
    final notifiedStr = await _storage.read(key: _notifiedExpiringKey);
    final Set<int> alreadyNotified = notifiedStr != null
        ? (jsonDecode(notifiedStr) as List).cast<int>().toSet()
        : {};

    final now = DateTime.now();
    final List<MissionProgressModel> expiringMissions = [];

    for (final mission in missions) {
      if (mission.isCompleted || alreadyNotified.contains(mission.id)) {
        continue;
      }

      final startedAt = mission.startedAt;
      if (startedAt == null) continue;

      final expiresAt = startedAt.add(Duration(days: mission.mission.durationDays));
      final timeUntilExpiry = expiresAt.difference(now);

      if (timeUntilExpiry.inHours > 0 && timeUntilExpiry.inHours <= 24) {
        expiringMissions.add(mission);
        alreadyNotified.add(mission.id);
      }
      else if (timeUntilExpiry.inHours > 24 && timeUntilExpiry.inDays <= 3) {
        if (!alreadyNotified.contains(mission.id)) {
          expiringMissions.add(mission);
          alreadyNotified.add(mission.id);
        }
      }
    }

    await _storage.write(
      key: _notifiedExpiringKey,
      value: jsonEncode(alreadyNotified.toList()),
    );

    for (final mission in expiringMissions) {
      final startedAt = mission.startedAt;
      if (startedAt == null) continue;

      final expiresAt = startedAt.add(Duration(days: mission.mission.durationDays));
      final timeUntilExpiry = expiresAt.difference(now);
      
      String timeMessage;
      if (timeUntilExpiry.inHours <= 24) {
        timeMessage = timeUntilExpiry.inHours == 1
            ? 'Expira em 1 hora'
            : 'Expira em ${timeUntilExpiry.inHours} horas';
      } else {
        timeMessage = timeUntilExpiry.inDays == 1
            ? 'Expira amanhã'
            : 'Expira em ${timeUntilExpiry.inDays} dias';
      }

      if (context.mounted) {
        FeedbackService.showBanner(
          context,
          '⏰ ${mission.mission.title}\n$timeMessage',
          type: FeedbackType.warning,
          duration: const Duration(seconds: 6),
        );
        
        await Future.delayed(const Duration(milliseconds: 500));
      }
    }
  }

  /// Checks if there are new missions available
  static Future<void> checkNewMissions({
    required BuildContext context,
    required List<MissionProgressModel> missions,
  }) async {
    if (!context.mounted) return;

    // Get timestamp of last check
    final lastCheckStr = await _storage.read(key: _lastMissionCheckKey);
    final lastCheck = lastCheckStr != null
        ? DateTime.tryParse(lastCheckStr)
        : null;

    // Get list of already notified new missions
    final notifiedStr = await _storage.read(key: _notifiedNewKey);
    final Set<int> alreadyNotified = notifiedStr != null
        ? (jsonDecode(notifiedStr) as List).cast<int>().toSet()
        : {};

    final now = DateTime.now();
    final List<MissionProgressModel> newMissions = [];

    for (final mission in missions) {
      // Check if it's a new mission (started recently)
      if (alreadyNotified.contains(mission.id)) {
        continue;
      }

      final startedAt = mission.startedAt;
      if (startedAt == null) continue;

      // If it's the first check, don't notify old missions
      if (lastCheck == null) {
        alreadyNotified.add(mission.id);
        continue;
      }

      // Mission was started after the last check
      if (startedAt.isAfter(lastCheck)) {
        newMissions.add(mission);
        alreadyNotified.add(mission.id);
      }
    }

    // Save current check timestamp
    await _storage.write(
      key: _lastMissionCheckKey,
      value: now.toIso8601String(),
    );

    // Save updated list of notified missions
    await _storage.write(
      key: _notifiedNewKey,
      value: jsonEncode(alreadyNotified.toList()),
    );

    // Show notifications for new missions
    if (newMissions.isNotEmpty && context.mounted) {
      if (newMissions.length == 1) {
        FeedbackService.showBanner(
          context,
          '🎯 Nova missão disponível!\n${newMissions.first.mission.title}',
          type: FeedbackType.info,
          duration: const Duration(seconds: 5),
        );
      } else {
        FeedbackService.showBanner(
          context,
          '🎯 ${newMissions.length} novas missões disponíveis!',
          type: FeedbackType.info,
          duration: const Duration(seconds: 5),
        );
      }
    }
  }

  /// Initializes the service by saving the current timestamp (first time)
  static Future<void> initialize() async {
    final lastCheckStr = await _storage.read(key: _lastMissionCheckKey);
    if (lastCheckStr == null) {
      // First time - save current timestamp
      await _storage.write(
        key: _lastMissionCheckKey,
        value: DateTime.now().toIso8601String(),
      );
    }
  }

  /// Clears notification history (useful for debug)
  static Future<void> clearNotificationHistory() async {
    await _storage.delete(key: _notifiedExpiringKey);
    await _storage.delete(key: _notifiedNewKey);
    await _storage.delete(key: _lastMissionCheckKey);
  }

  /// Gets summary of critical missions (to display in UI)
  static Future<MissionSummary> getMissionSummary(
    List<MissionProgressModel> missions,
  ) async {
    final now = DateTime.now();
    int expiringSoon = 0;
    int expiredCount = 0;
    int completedToday = 0;
    int activeCount = 0;

    for (final mission in missions) {
      if (mission.isCompleted) {
        final completedAt = mission.completedAt;
        if (completedAt != null) {
          final diff = now.difference(completedAt);
          if (diff.inHours < 24) {
            completedToday++;
          }
        }
        continue;
      }

      activeCount++;
      
      // Calculate expiration date
      final startedAt = mission.startedAt;
      if (startedAt == null) continue;

      final expiresAt = startedAt.add(Duration(days: mission.mission.durationDays));
      final timeUntilExpiry = expiresAt.difference(now);
      
      if (timeUntilExpiry.isNegative) {
        expiredCount++;
      } else if (timeUntilExpiry.inHours <= 24) {
        expiringSoon++;
      }
    }

    return MissionSummary(
      activeCount: activeCount,
      expiringSoon: expiringSoon,
      expiredCount: expiredCount,
      completedToday: completedToday,
    );
  }
}

/// Summary of mission status
class MissionSummary {
  final int activeCount;
  final int expiringSoon;
  final int expiredCount;
  final int completedToday;

  const MissionSummary({
    required this.activeCount,
    required this.expiringSoon,
    required this.expiredCount,
    required this.completedToday,
  });

  bool get hasUrgentMissions => expiringSoon > 0;
  bool get hasExpiredMissions => expiredCount > 0;
  bool get hasCompletedToday => completedToday > 0;
}

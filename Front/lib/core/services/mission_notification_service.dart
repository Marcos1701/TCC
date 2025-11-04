import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';

import '../models/mission_progress.dart';
import 'feedback_service.dart';

/// Serviço para notificar sobre status de missões
class MissionNotificationService {
  static const _storage = FlutterSecureStorage();
  static const _notifiedExpiringKey = 'notified_expiring_missions';
  static const _notifiedNewKey = 'notified_new_missions';
  static const _lastMissionCheckKey = 'last_mission_check';

  /// Verifica missões próximas de expirar e notifica o usuário
  static Future<void> checkExpiringMissions({
    required BuildContext context,
    required List<MissionProgressModel> missions,
  }) async {
    if (!context.mounted) return;

    // Obter lista de missões já notificadas
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

      // Calcular data de expiração: startedAt + durationDays
      final startedAt = mission.startedAt;
      if (startedAt == null) continue;

      final expiresAt = startedAt.add(Duration(days: mission.mission.durationDays));
      final timeUntilExpiry = expiresAt.difference(now);

      // Notificar missões que expiram em menos de 24 horas
      if (timeUntilExpiry.inHours > 0 && timeUntilExpiry.inHours <= 24) {
        expiringMissions.add(mission);
        alreadyNotified.add(mission.id);
      }
      // Notificar missões que expiram em menos de 3 dias (mas mais de 24h)
      else if (timeUntilExpiry.inHours > 24 && timeUntilExpiry.inDays <= 3) {
        if (!alreadyNotified.contains(mission.id)) {
          expiringMissions.add(mission);
          alreadyNotified.add(mission.id);
        }
      }
    }

    // Salvar lista atualizada
    await _storage.write(
      key: _notifiedExpiringKey,
      value: jsonEncode(alreadyNotified.toList()),
    );

    // Exibir notificações
    for (final mission in expiringMissions) {
      // Calcular data de expiração
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
        
        // Aguardar um pouco antes da próxima notificação
        await Future.delayed(const Duration(milliseconds: 500));
      }
    }
  }

  /// Verifica se há novas missões disponíveis
  static Future<void> checkNewMissions({
    required BuildContext context,
    required List<MissionProgressModel> missions,
  }) async {
    if (!context.mounted) return;

    // Obter timestamp da última verificação
    final lastCheckStr = await _storage.read(key: _lastMissionCheckKey);
    final lastCheck = lastCheckStr != null
        ? DateTime.tryParse(lastCheckStr)
        : null;

    // Obter lista de missões já notificadas como novas
    final notifiedStr = await _storage.read(key: _notifiedNewKey);
    final Set<int> alreadyNotified = notifiedStr != null
        ? (jsonDecode(notifiedStr) as List).cast<int>().toSet()
        : {};

    final now = DateTime.now();
    final List<MissionProgressModel> newMissions = [];

    for (final mission in missions) {
      // Verificar se é uma missão nova (iniciada recentemente)
      if (alreadyNotified.contains(mission.id)) {
        continue;
      }

      final startedAt = mission.startedAt;
      if (startedAt == null) continue;

      // Se é a primeira verificação, não notificar missões antigas
      if (lastCheck == null) {
        alreadyNotified.add(mission.id);
        continue;
      }

      // Missão foi iniciada depois da última verificação
      if (startedAt.isAfter(lastCheck)) {
        newMissions.add(mission);
        alreadyNotified.add(mission.id);
      }
    }

    // Salvar timestamp da verificação atual
    await _storage.write(
      key: _lastMissionCheckKey,
      value: now.toIso8601String(),
    );

    // Salvar lista atualizada de missões notificadas
    await _storage.write(
      key: _notifiedNewKey,
      value: jsonEncode(alreadyNotified.toList()),
    );

    // Exibir notificações de novas missões
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

  /// Inicializa o serviço salvando o timestamp atual (primeira vez)
  static Future<void> initialize() async {
    final lastCheckStr = await _storage.read(key: _lastMissionCheckKey);
    if (lastCheckStr == null) {
      // Primeira vez - salvar timestamp atual
      await _storage.write(
        key: _lastMissionCheckKey,
        value: DateTime.now().toIso8601String(),
      );
    }
  }

  /// Limpa histórico de notificações (útil para debug)
  static Future<void> clearNotificationHistory() async {
    await _storage.delete(key: _notifiedExpiringKey);
    await _storage.delete(key: _notifiedNewKey);
    await _storage.delete(key: _lastMissionCheckKey);
  }

  /// Obtém resumo de missões críticas (para exibir em UI)
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
      
      // Calcular data de expiração
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

/// Resumo do status das missões
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

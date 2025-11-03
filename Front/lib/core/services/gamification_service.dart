import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';

import '../models/mission_progress.dart';
import '../models/profile.dart';
import '../widgets/celebration_overlay.dart';

/// Serviço para gerenciar gamificação e celebrações
class GamificationService {
  static const _storage = FlutterSecureStorage();
  static const _lastLevelKey = 'last_level';
  static const _completedMissionsKey = 'completed_missions';

  /// Verifica se houve subida de nível e exibe celebração
  static Future<void> checkLevelUp({
    required BuildContext context,
    required ProfileModel profile,
  }) async {
    // Obter último nível conhecido
    final lastLevelStr = await _storage.read(key: _lastLevelKey);
    final lastLevel = lastLevelStr != null ? int.tryParse(lastLevelStr) ?? 1 : 1;

    // Se subiu de nível
    if (profile.level > lastLevel) {
      // Calcular moedas ganhas (exemplo: 100 moedas por nível)
      final coinsEarned = (profile.level - lastLevel) * 100;

      // Salvar novo nível
      await _storage.write(key: _lastLevelKey, value: profile.level.toString());

      // Exibir celebração
      if (context.mounted) {
        CelebrationOverlay.showLevelUp(
          context: context,
          newLevel: profile.level,
          coinsEarned: coinsEarned,
        );
      }
    }
  }

  /// Verifica se há novas missões completadas e exibe celebração
  static Future<void> checkMissionCompletions({
    required BuildContext context,
    required List<MissionProgressModel> missions,
  }) async {
    // Obter lista de missões já celebradas
    final completedStr = await _storage.read(key: _completedMissionsKey);
    final Set<int> alreadyCelebrated = completedStr != null
        ? (jsonDecode(completedStr) as List).cast<int>().toSet()
        : {};

    // Verificar missões completadas que ainda não foram celebradas
    final newlyCompleted = missions.where((m) =>
        m.isCompleted &&
        m.completedAt != null &&
        !alreadyCelebrated.contains(m.id)).toList();

    // Celebrar cada missão nova
    for (final mission in newlyCompleted) {
      // Adicionar à lista de celebradas
      alreadyCelebrated.add(mission.id);

      // Calcular moedas ganhas baseado na recompensa da missão
      final coinsEarned = mission.mission.rewardPoints;

      // Exibir celebração se o contexto ainda está montado
      if (context.mounted) {
        CelebrationOverlay.showMissionComplete(
          context: context,
          missionTitle: mission.mission.title,
          coinsEarned: coinsEarned,
        );

        // Aguardar um pouco antes da próxima celebração
        await Future.delayed(const Duration(milliseconds: 500));
      }
    }

    // Salvar lista atualizada
    await _storage.write(
      key: _completedMissionsKey,
      value: jsonEncode(alreadyCelebrated.toList()),
    );
  }

  /// Limpa histórico de celebrações (útil para debug)
  static Future<void> clearCelebrationHistory() async {
    await _storage.delete(key: _lastLevelKey);
    await _storage.delete(key: _completedMissionsKey);
  }

  /// Inicializa o serviço com o nível atual (deve ser chamado na primeira vez)
  static Future<void> initialize(ProfileModel profile) async {
    final lastLevelStr = await _storage.read(key: _lastLevelKey);
    if (lastLevelStr == null) {
      // Primeira vez - salvar nível atual sem celebrar
      await _storage.write(key: _lastLevelKey, value: profile.level.toString());
    }
  }
}

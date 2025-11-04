import 'package:flutter/foundation.dart';

/// Gerenciador centralizado de cache e invalidação de dados
/// 
/// Este serviço notifica listeners quando dados precisam ser recarregados,
/// garantindo que toda a UI seja atualizada após operações como:
/// - Criar/editar/deletar transações
/// - Pagar despesas
/// - Completar missões
class CacheManager extends ChangeNotifier {
  static final CacheManager _instance = CacheManager._internal();
  factory CacheManager() => _instance;
  CacheManager._internal();

  /// Timestamp da última invalidação global
  DateTime _lastInvalidation = DateTime.now();
  DateTime get lastInvalidation => _lastInvalidation;

  /// Tipos de cache que podem ser invalidados individualmente
  final Set<CacheType> _invalidatedCaches = {};

  /// Invalida todos os caches e notifica listeners
  void invalidateAll({String? reason}) {
    _lastInvalidation = DateTime.now();
    _invalidatedCaches.clear();
    _invalidatedCaches.addAll(CacheType.values);
    
    if (kDebugMode) {
      print('🔄 Cache invalidated: ${reason ?? "manual"}');
    }
    
    notifyListeners();
  }

  /// Invalida caches específicos
  void invalidate(List<CacheType> types, {String? reason}) {
    _lastInvalidation = DateTime.now();
    _invalidatedCaches.addAll(types);
    
    if (kDebugMode) {
      print('🔄 Cache invalidated [${types.map((t) => t.name).join(", ")}]: ${reason ?? "manual"}');
    }
    
    notifyListeners();
  }

  /// Verifica se um tipo de cache específico foi invalidado
  bool isInvalidated(CacheType type) {
    return _invalidatedCaches.contains(type);
  }

  /// Limpa a marcação de invalidação (chamado após recarregamento)
  void clearInvalidation(CacheType type) {
    _invalidatedCaches.remove(type);
  }

  /// Invalida cache após criar/editar/deletar transação
  void invalidateAfterTransaction({String? action}) {
    invalidate(
      [
        CacheType.dashboard,
        CacheType.transactions,
        CacheType.missions,
        CacheType.profile,
        CacheType.progress,
        CacheType.leaderboard,
      ],
      reason: action ?? 'transaction modified',
    );
  }

  /// Invalida cache após pagar despesa (vincular transações)
  void invalidateAfterPayment() {
    invalidate(
      [
        CacheType.dashboard,
        CacheType.transactions,
        CacheType.missions,
        CacheType.profile,
      ],
      reason: 'debt payment',
    );
  }

  /// Invalida cache após completar missão
  void invalidateAfterMissionComplete() {
    invalidate(
      [
        CacheType.dashboard,
        CacheType.missions,
        CacheType.profile,
        CacheType.leaderboard,
      ],
      reason: 'mission completed',
    );
  }

  /// Invalida cache após mudanças no perfil
  void invalidateAfterProfileUpdate() {
    invalidate(
      [
        CacheType.profile,
        CacheType.dashboard,
        CacheType.leaderboard,
      ],
      reason: 'profile updated',
    );
  }

  /// Invalida cache após mudanças em metas
  void invalidateAfterGoalUpdate() {
    invalidate(
      [
        CacheType.progress,
        CacheType.dashboard,
      ],
      reason: 'goal updated',
    );
  }
}

/// Tipos de cache que podem ser invalidados
enum CacheType {
  dashboard,
  transactions,
  missions,
  profile,
  progress,
  leaderboard,
}

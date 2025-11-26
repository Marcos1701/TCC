import 'package:flutter/foundation.dart';

/// Centralized cache and data invalidation manager
/// 
/// This service notifies listeners when data needs to be reloaded,
/// ensuring the entire UI is updated after operations like:
/// - Create/edit/delete transactions
/// - Pay expenses
/// - Complete missions
class CacheManager extends ChangeNotifier {
  static final CacheManager _instance = CacheManager._internal();
  factory CacheManager() => _instance;
  CacheManager._internal();

  /// Timestamp of the last global invalidation
  DateTime _lastInvalidation = DateTime.now();
  DateTime get lastInvalidation => _lastInvalidation;

  /// Cache types that can be invalidated individually
  final Set<CacheType> _invalidatedCaches = {};

  /// Invalidates all caches and notifies listeners
  void invalidateAll({String? reason}) {
    _lastInvalidation = DateTime.now();
    _invalidatedCaches.clear();
    _invalidatedCaches.addAll(CacheType.values);
    
    if (kDebugMode) {
      debugPrint('🔄 Cache invalidated: ${reason ?? "manual"}');
    }
    
    notifyListeners();
  }

  /// Invalidates specific caches
  void invalidate(List<CacheType> types, {String? reason}) {
    _lastInvalidation = DateTime.now();
    _invalidatedCaches.addAll(types);
    
    if (kDebugMode) {
      debugPrint('🔄 Cache invalidated [${types.map((t) => t.name).join(", ")}]: ${reason ?? "manual"}');
    }
    
    notifyListeners();
  }

  /// Checks if a specific cache type has been invalidated
  bool isInvalidated(CacheType type) {
    return _invalidatedCaches.contains(type);
  }

  /// Clears the invalidation flag (called after reloading)
  void clearInvalidation(CacheType type) {
    _invalidatedCaches.remove(type);
  }

  /// Invalidates cache after creating/editing/deleting transaction
  void invalidateAfterTransaction({String? action}) {
    invalidate(
      [
        CacheType.dashboard,
        CacheType.transactions,
        CacheType.missions,
        CacheType.profile,
        CacheType.progress,
      ],
      reason: action ?? 'transaction modified',
    );
  }

  /// Invalidates cache after paying expense (linking transactions)
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

  /// Invalidates cache after completing mission
  void invalidateAfterMissionComplete() {
    invalidate(
      [
        CacheType.dashboard,
        CacheType.missions,
        CacheType.profile,
      ],
      reason: 'mission completed',
    );
  }

  /// Invalidates cache after profile changes
  void invalidateAfterProfileUpdate() {
    invalidate(
      [
        CacheType.profile,
        CacheType.dashboard,
      ],
      reason: 'profile updated',
    );
  }

  /// Invalidates cache after goal updates
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

/// Cache types that can be invalidated
enum CacheType {
  dashboard,
  transactions,
  missions,
  profile,
  progress,
}

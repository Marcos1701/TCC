import 'package:flutter/foundation.dart';
import 'cache_service.dart';

class CacheManager extends ChangeNotifier {
  static final CacheManager _instance = CacheManager._internal();
  factory CacheManager() => _instance;
  CacheManager._internal();

  DateTime _lastInvalidation = DateTime.now();
  DateTime get lastInvalidation => _lastInvalidation;

  final Set<CacheType> _invalidatedCaches = {};

  void invalidateAll({String? reason}) {
    _lastInvalidation = DateTime.now();
    _invalidatedCaches.clear();
    _invalidatedCaches.addAll(CacheType.values);
    
    // Explicitly wipe data from Hive to prevent any timestamp race conditions
    CacheService.invalidateDashboard();
    CacheService.invalidateMissions();
    CacheService.invalidateCategories();
    
    if (kDebugMode) {
      debugPrint('🔄 Cache invalidated: ${reason ?? "manual"}');
    }
    
    notifyListeners();
  }

  void invalidate(List<CacheType> types, {String? reason}) {
    _lastInvalidation = DateTime.now();
    _invalidatedCaches.addAll(types);
    
    if (kDebugMode) {
      debugPrint('🔄 Cache invalidated [${types.map((t) => t.name).join(", ")}]: ${reason ?? "manual"}');
    }
    
    notifyListeners();
  }

  bool isInvalidated(CacheType type) {
    return _invalidatedCaches.contains(type);
  }

  void clearInvalidation(CacheType type) {
    _invalidatedCaches.remove(type);
  }

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

  void invalidateAfterMissionComplete() {
    // Explicitly wipe data from Hive to prevent stale data
    CacheService.invalidateDashboard();
    CacheService.invalidateMissions();
    
    invalidate(
      [
        CacheType.dashboard,
        CacheType.missions,
        CacheType.profile,
      ],
      reason: 'mission completed',
    );
  }

  void invalidateAfterProfileUpdate() {
    invalidate(
      [
        CacheType.profile,
        CacheType.dashboard,
      ],
      reason: 'profile updated',
    );
  }

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

enum CacheType {
  dashboard,
  transactions,
  missions,
  profile,
  progress,
}

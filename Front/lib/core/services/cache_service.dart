import 'package:hive_flutter/hive_flutter.dart';

class CacheService {
  static const String _categoriesBox = 'categories_cache';
  static const String _missionsBox = 'missions_cache';
  static const String _dashboardBox = 'dashboard_cache';
  
  static Future<void> init() async {
    await Hive.initFlutter();
    await Hive.openBox(_categoriesBox);
    await Hive.openBox(_missionsBox);
    await Hive.openBox(_dashboardBox);
  }

  static Box get _categories => Hive.box(_categoriesBox);
  static Box get _missions => Hive.box(_missionsBox);
  static Box get _dashboard => Hive.box(_dashboardBox);

  static Future<void> cacheCategories(List<Map<String, dynamic>> categories) async {
    await _categories.put('data', categories);
    await _categories.put('timestamp', DateTime.now().millisecondsSinceEpoch);
  }

  static List<Map<String, dynamic>>? getCachedCategories({
    int maxAgeMinutes = 30,
    DateTime? invalidatedAfter,
  }) {
    final timestamp = _categories.get('timestamp') as int?;
    if (timestamp == null) return null;
    
    if (invalidatedAfter != null && timestamp < invalidatedAfter.millisecondsSinceEpoch) {
      return null;
    }
    
    final age = DateTime.now().millisecondsSinceEpoch - timestamp;
    if (age > maxAgeMinutes * 60 * 1000) return null;
    
    final data = _categories.get('data');
    if (data is List) {
      return List<Map<String, dynamic>>.from(data.map((e) => Map<String, dynamic>.from(e as Map)));
    }
    return null;
  }

  static Future<void> cacheMissions(List<Map<String, dynamic>> missions) async {
    await _missions.put('data', missions);
    await _missions.put('timestamp', DateTime.now().millisecondsSinceEpoch);
  }

  static List<Map<String, dynamic>>? getCachedMissions({
    int maxAgeMinutes = 10,
    DateTime? invalidatedAfter,
  }) {
    final timestamp = _missions.get('timestamp') as int?;
    if (timestamp == null) return null;
    
    if (invalidatedAfter != null && timestamp < invalidatedAfter.millisecondsSinceEpoch) {
      return null;
    }
    
    final age = DateTime.now().millisecondsSinceEpoch - timestamp;
    if (age > maxAgeMinutes * 60 * 1000) return null;
    
    final data = _missions.get('data');
    if (data is List) {
      return List<Map<String, dynamic>>.from(data.map((e) => Map<String, dynamic>.from(e as Map)));
    }
    return null;
  }

  static Future<void> cacheDashboard(Map<String, dynamic> dashboard) async {
    await _dashboard.put('data', dashboard);
    await _dashboard.put('timestamp', DateTime.now().millisecondsSinceEpoch);
  }

  static Map<String, dynamic>? getCachedDashboard({
    int maxAgeMinutes = 5,
    DateTime? invalidatedAfter,
  }) {
    final timestamp = _dashboard.get('timestamp') as int?;
    if (timestamp == null) return null;
    
    if (invalidatedAfter != null && timestamp < invalidatedAfter.millisecondsSinceEpoch) {
      return null;
    }
    
    final age = DateTime.now().millisecondsSinceEpoch - timestamp;
    if (age > maxAgeMinutes * 60 * 1000) return null;
    
    final data = _dashboard.get('data');
    if (data is Map<String, dynamic>) {
      return data;
    }
    return null;
  }

  static Future<void> invalidateCategories() async {
    await _categories.delete('timestamp');
  }

  static Future<void> invalidateMissions() async {
    await _missions.delete('timestamp');
  }

  static Future<void> invalidateDashboard() async {
    await _dashboard.delete('timestamp');
  }

  static Future<void> clearAll() async {
    await _categories.clear();
    await _missions.clear();
    await _dashboard.clear();
  }
}




library;




int getSafeInt(Map<String, dynamic>? map, String key) {
  if (map == null) return 0;
  final value = map[key];
  if (value == null) return 0;
  if (value is int) return value;
  if (value is double) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}


double getSafeDouble(Map<String, dynamic>? map, String key) {
  if (map == null) return 0.0;
  final value = map[key];
  if (value == null) return 0.0;
  if (value is double) return value;
  if (value is int) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? 0.0;
  return 0.0;
}


String getSafeString(Map<String, dynamic>? map, String key, {String defaultValue = ''}) {
  if (map == null) return defaultValue;
  final value = map[key];
  if (value == null) return defaultValue;
  return value.toString();
}


List<T> getSafeList<T>(Map<String, dynamic>? map, String key) {
  if (map == null) return [];
  final value = map[key];
  if (value == null) return [];
  if (value is! List) return [];
  return value.cast<T>();
}

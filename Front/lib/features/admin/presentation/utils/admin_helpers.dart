/// Funções auxiliares compartilhadas para páginas admin
/// 
/// Evita duplicação de lógica comum entre diferentes páginas administrativas
library;

/// Obtém valor inteiro de forma segura de um mapa dinâmico
/// 
/// Substitui múltiplas implementações do método getSafeInt/getSafeValue
int getSafeInt(Map<String, dynamic>? map, String key) {
  if (map == null) return 0;
  final value = map[key];
  if (value == null) return 0;
  if (value is int) return value;
  if (value is double) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}

/// Obtém valor double de forma segura de um mapa dinâmico
double getSafeDouble(Map<String, dynamic>? map, String key) {
  if (map == null) return 0.0;
  final value = map[key];
  if (value == null) return 0.0;
  if (value is double) return value;
  if (value is int) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? 0.0;
  return 0.0;
}

/// Obtém string de forma segura de um mapa dinâmico
String getSafeString(Map<String, dynamic>? map, String key, {String defaultValue = ''}) {
  if (map == null) return defaultValue;
  final value = map[key];
  if (value == null) return defaultValue;
  return value.toString();
}

/// Obtém lista de forma segura de um mapa dinâmico
List<T> getSafeList<T>(Map<String, dynamic>? map, String key) {
  if (map == null) return [];
  final value = map[key];
  if (value == null) return [];
  if (value is! List) return [];
  return value.cast<T>();
}

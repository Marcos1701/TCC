import 'package:drift/drift.dart';
import 'package:drift/web.dart';

/// Creates a web database connection using IndexedDB.
/// This implementation is used when running on web platforms.
QueryExecutor driftDatabase() {
  return WebDatabase('app_db');
}

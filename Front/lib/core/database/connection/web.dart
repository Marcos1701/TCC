import 'package:drift/drift.dart';
import 'package:drift/web.dart';

QueryExecutor driftDatabase() {
  return WebDatabase('app_db');
}

import 'package:drift/drift.dart';

import 'unsupported.dart'
    if (dart.library.html) 'web.dart'
    if (dart.library.io) 'native.dart';

/// Opens a connection to the database based on the current platform.
/// 
/// On web: Uses IndexedDB via WebDatabase
/// On native platforms: Uses SQLite via NativeDatabase
QueryExecutor connect() {
  return driftDatabase();
}

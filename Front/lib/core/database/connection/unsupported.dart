import 'package:drift/drift.dart';

/// Fallback implementation that throws an error.
/// This should never be called as the conditional imports should handle all platforms.
QueryExecutor driftDatabase() {
  throw UnsupportedError(
    'No suitable database implementation was found on this platform.',
  );
}

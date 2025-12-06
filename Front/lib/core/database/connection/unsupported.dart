import 'package:drift/drift.dart';

QueryExecutor driftDatabase() {
  throw UnsupportedError(
    'No suitable database implementation was found on this platform.',
  );
}

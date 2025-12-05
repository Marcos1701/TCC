import 'package:drift/drift.dart';

import 'connection/connection.dart';
import 'daos/transactions_dao.dart';

part 'app_database.g.dart';

class Transactions extends Table {
  TextColumn get id => text()();
  TextColumn get description => text()();
  RealColumn get amount => real()();
  DateTimeColumn get date => dateTime()();
  TextColumn get type => text()();
  TextColumn get categoryId => text().nullable()();
  BoolColumn get isRecurring => boolean().withDefault(const Constant(false))();
  IntColumn get recurrenceValue => integer().nullable()();
  TextColumn get recurrenceUnit => text().nullable()();
  DateTimeColumn get recurrenceEndDate => dateTime().nullable()();
  
  // Sync fields
  BoolColumn get isSynced => boolean().withDefault(const Constant(true))();
  DateTimeColumn get lastUpdated => dateTime().nullable()();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

class Categories extends Table {
  IntColumn get id => integer()();
  TextColumn get name => text()();
  TextColumn get type => text()();
  TextColumn get color => text().nullable()();
  TextColumn get group => text().nullable()();
  
  // Sync fields
  BoolColumn get isSynced => boolean().withDefault(const Constant(true))();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}



@DriftDatabase(tables: [Transactions, Categories], daos: [TransactionsDao])
class AppDatabase extends _$AppDatabase {
  /// Singleton instance
  static AppDatabase? _instance;
  
  /// Private constructor
  AppDatabase._internal() : super(connect());
  
  /// Factory constructor that returns the singleton instance
  factory AppDatabase() {
    _instance ??= AppDatabase._internal();
    return _instance!;
  }
  
  /// Get the singleton instance (alternative accessor)
  static AppDatabase get instance => AppDatabase();
  
  /// Reset the singleton (useful for testing)
  static void resetInstance() {
    _instance?.close();
    _instance = null;
  }

  @override
  int get schemaVersion => 2;  // Incremented for Goals removal
}

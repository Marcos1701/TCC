import 'package:drift/drift.dart';

import 'connection/connection.dart';
import 'daos/transactions_dao.dart';
import 'daos/goals_dao.dart';

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

class Goals extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  TextColumn get description => text()();
  RealColumn get targetAmount => real()();
  RealColumn get currentAmount => real()();
  RealColumn get initialAmount => real().withDefault(const Constant(0.0))();
  DateTimeColumn get deadline => dateTime().nullable()();
  TextColumn get goalType => text()();
  RealColumn get progressPercentage => real()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  
  // New fields
  TextColumn get targetCategory => text().nullable()();
  TextColumn get targetCategoryName => text().nullable()();
  RealColumn get baselineAmount => real().nullable()();
  IntColumn get trackingPeriodMonths => integer().withDefault(const Constant(3))();

  // Sync fields
  BoolColumn get isSynced => boolean().withDefault(const Constant(true))();
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



@DriftDatabase(tables: [Transactions, Goals, Categories], daos: [TransactionsDao, GoalsDao])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(connect());

  @override
  int get schemaVersion => 1;
}

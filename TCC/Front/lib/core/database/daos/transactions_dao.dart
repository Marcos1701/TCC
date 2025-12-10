import 'package:drift/drift.dart';
import '../app_database.dart';

part 'transactions_dao.g.dart';

@DriftAccessor(tables: [Transactions, Categories])
class TransactionsDao extends DatabaseAccessor<AppDatabase> with _$TransactionsDaoMixin {
  TransactionsDao(super.db);

  Future<List<Transaction>> getAllTransactions() => 
      (select(transactions)..where((t) => t.isDeleted.equals(false))).get();
  
  Stream<List<Transaction>> watchAllTransactions() => 
      (select(transactions)..where((t) => t.isDeleted.equals(false))).watch();

  Future<Transaction?> getTransactionById(String id) =>
      (select(transactions)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<int> insertTransaction(TransactionsCompanion entry) =>
      into(transactions).insert(entry, mode: InsertMode.insertOrReplace);

  Future<bool> updateTransaction(TransactionsCompanion entry) =>
      update(transactions).replace(entry);

  Future<int> deleteTransaction(String id) =>
      (delete(transactions)..where((t) => t.id.equals(id))).go();
      
  Future<List<Transaction>> getUnsyncedTransactions() =>
      (select(transactions)..where((t) => t.isSynced.equals(false))).get();
      
  Future<void> markAsSynced(String id) =>
      (update(transactions)..where((t) => t.id.equals(id)))
          .write(const TransactionsCompanion(isSynced: Value(true)));
}

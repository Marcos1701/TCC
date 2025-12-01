import 'package:drift/drift.dart';
import '../app_database.dart';

part 'goals_dao.g.dart';

@DriftAccessor(tables: [Goals])
class GoalsDao extends DatabaseAccessor<AppDatabase> with _$GoalsDaoMixin {
  GoalsDao(super.db);

  Future<List<Goal>> getAllGoals() => select(goals).get();
  
  Stream<List<Goal>> watchAllGoals() => select(goals).watch();

  Future<Goal?> getGoalById(String id) =>
      (select(goals)..where((g) => g.id.equals(id))).getSingleOrNull();

  Future<int> insertGoal(GoalsCompanion entry) =>
      into(goals).insert(entry, mode: InsertMode.insertOrReplace);

  Future<bool> updateGoal(GoalsCompanion entry) =>
      update(goals).replace(entry);

  Future<int> deleteGoal(String id) =>
      (delete(goals)..where((g) => g.id.equals(id))).go();
      
  Future<List<Goal>> getUnsyncedGoals() =>
      (select(goals)..where((g) => g.isSynced.equals(false))).get();
      
  Future<void> markAsSynced(String id) =>
      (update(goals)..where((g) => g.id.equals(id)))
          .write(const GoalsCompanion(isSynced: Value(true)));
}

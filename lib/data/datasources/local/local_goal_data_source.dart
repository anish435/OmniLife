import 'package:sqflite/sqflite.dart';

import '../../models/goal_model.dart';
import 'app_database.dart';

/// SQLite access for goals.
///
/// The goals table is not part of [AppDatabase]'s versioned schema (owned by
/// another stream), so this data source creates it lazily with
/// `CREATE TABLE IF NOT EXISTS` before its first use on each database.
class LocalGoalDataSource {
  LocalGoalDataSource({Future<Database> Function()? databaseProvider})
    : _databaseProvider =
          databaseProvider ?? (() => AppDatabase.instance.database);

  static const goalsTable = 'goals';

  final Future<Database> Function() _databaseProvider;
  Database? _preparedDb;

  /// Idempotent. Safe to call from tests and on every open.
  static Future<void> ensureSchema(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $goalsTable (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        title TEXT NOT NULL,
        target_description TEXT NOT NULL DEFAULT '',
        target_date INTEGER,
        linked_habit_id TEXT,
        milestones TEXT NOT NULL DEFAULT '[]',
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_goals_user ON $goalsTable (user_id)
    ''');
  }

  Future<Database> _db() async {
    final db = await _databaseProvider();
    if (!identical(_preparedDb, db)) {
      await ensureSchema(db);
      _preparedDb = db;
    }
    return db;
  }

  Future<void> insertGoal(GoalModel goal) async {
    final db = await _db();
    await db.insert(
      goalsTable,
      goal.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<GoalModel>> getGoals(String userId) async {
    final db = await _db();
    final rows = await db.query(
      goalsTable,
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'created_at ASC',
    );
    return rows.map(GoalModel.fromMap).toList();
  }

  Future<bool> updateGoal(GoalModel goal) async {
    final db = await _db();
    final count = await db.update(
      goalsTable,
      goal.toMap(),
      where: 'id = ?',
      whereArgs: [goal.id],
    );
    return count > 0;
  }

  Future<bool> deleteGoal(String id) async {
    final db = await _db();
    final count = await db.delete(goalsTable, where: 'id = ?', whereArgs: [id]);
    return count > 0;
  }
}

import 'package:sqflite/sqflite.dart';

import '../../models/habit_model.dart';
import 'app_database.dart';

class LocalHabitDataSource {
  LocalHabitDataSource({Future<Database> Function()? databaseProvider})
    : _databaseProvider =
          databaseProvider ?? (() => AppDatabase.instance.database);

  final Future<Database> Function() _databaseProvider;

  Future<void> insertHabit(HabitModel habit) async {
    final db = await _databaseProvider();
    await db.insert(
      AppDatabase.habitsTable,
      habit.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<HabitModel>> getHabits(String userId) async {
    final db = await _databaseProvider();
    final rows = await db.query(
      AppDatabase.habitsTable,
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'created_at ASC',
    );
    return rows.map(HabitModel.fromMap).toList();
  }

  Future<bool> updateHabit(HabitModel habit) async {
    final db = await _databaseProvider();
    final count = await db.update(
      AppDatabase.habitsTable,
      habit.toMap(),
      where: 'id = ?',
      whereArgs: [habit.id],
    );
    return count > 0;
  }

  Future<bool> deleteHabit(String id) async {
    final db = await _databaseProvider();
    // Explicit, in case foreign keys are off on this connection.
    await db.delete(
      AppDatabase.habitLogsTable,
      where: 'habit_id = ?',
      whereArgs: [id],
    );
    final count = await db.delete(
      AppDatabase.habitsTable,
      where: 'id = ?',
      whereArgs: [id],
    );
    return count > 0;
  }

  Future<void> insertHabitLog(HabitLogModel log) async {
    final db = await _databaseProvider();
    await db.insert(
      AppDatabase.habitLogsTable,
      log.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<HabitLogModel>> getHabitLogs(String habitId) async {
    final db = await _databaseProvider();
    final rows = await db.query(
      AppDatabase.habitLogsTable,
      where: 'habit_id = ? AND is_completed = 1',
      whereArgs: [habitId],
      orderBy: 'date DESC',
    );
    return rows.map(HabitLogModel.fromMap).toList();
  }

  Future<bool> deleteHabitLog(String habitId, String date) async {
    final db = await _databaseProvider();
    final count = await db.delete(
      AppDatabase.habitLogsTable,
      where: 'habit_id = ? AND date = ?',
      whereArgs: [habitId, date],
    );
    return count > 0;
  }
}

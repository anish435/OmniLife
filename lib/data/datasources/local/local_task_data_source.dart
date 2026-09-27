import 'package:sqflite/sqflite.dart';

import '../../models/task_model.dart';
import 'app_database.dart';

/// Raw SQLite access for the `tasks` table. Contains no business rules
/// (no id generation, no timestamp management) — that belongs to
/// [TaskRepositoryImpl]. This class only knows how to read/write rows.
class LocalTaskDataSource {
  LocalTaskDataSource({Future<Database> Function()? databaseProvider})
    : _databaseProvider =
          databaseProvider ?? (() => AppDatabase.instance.database);

  final Future<Database> Function() _databaseProvider;

  Future<void> insertTask(TaskModel task) async {
    final db = await _databaseProvider();
    await db.insert(
      AppDatabase.tasksTable,
      task.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<TaskModel>> getAllTasks(String userId) async {
    final db = await _databaseProvider();
    final rows = await db.query(
      AppDatabase.tasksTable,
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'created_at DESC',
    );
    return rows.map(TaskModel.fromMap).toList();
  }

  Future<TaskModel?> getTaskById(String id) async {
    final db = await _databaseProvider();
    final rows = await db.query(
      AppDatabase.tasksTable,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return TaskModel.fromMap(rows.first);
  }

  /// Returns `false` if no row with this id exists.
  Future<bool> updateTask(TaskModel task) async {
    final db = await _databaseProvider();
    final count = await db.update(
      AppDatabase.tasksTable,
      task.toMap(),
      where: 'id = ?',
      whereArgs: [task.id],
    );
    return count > 0;
  }

  /// Returns `false` if no row with this id existed to delete.
  Future<bool> deleteTask(String id) async {
    final db = await _databaseProvider();
    final count = await db.delete(
      AppDatabase.tasksTable,
      where: 'id = ?',
      whereArgs: [id],
    );
    return count > 0;
  }

  /// Returns `false` if no row with this id exists.
  Future<bool> setCompleted(
    String id, {
    required bool completed,
    required DateTime updatedAt,
  }) async {
    final db = await _databaseProvider();
    final count = await db.update(
      AppDatabase.tasksTable,
      {
        'completed': completed ? 1 : 0,
        'updated_at': updatedAt.millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
    return count > 0;
  }
}

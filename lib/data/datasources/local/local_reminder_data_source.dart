import 'package:sqflite/sqflite.dart';

import '../../models/reminder_model.dart';
import 'app_database.dart';

/// SQLite access for reminders. Owns its own table (created lazily) so it
/// does not depend on the shared schema version.
class LocalReminderDataSource {
  LocalReminderDataSource({Future<Database> Function()? databaseProvider})
    : _databaseProvider =
          databaseProvider ?? (() => AppDatabase.instance.database);

  final Future<Database> Function() _databaseProvider;
  static const table = 'reminders';

  static Future<void> ensureSchema(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $table (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        title TEXT NOT NULL,
        scheduled_at INTEGER NOT NULL,
        repeat TEXT NOT NULL DEFAULT 'none',
        note TEXT,
        enabled INTEGER NOT NULL DEFAULT 1,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_reminders_user '
      'ON $table (user_id, scheduled_at)',
    );
  }

  Future<Database> get _db async {
    final db = await _databaseProvider();
    await ensureSchema(db);
    return db;
  }

  Future<void> upsert(ReminderModel model) async {
    final db = await _db;
    await db.insert(
      table,
      model.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<ReminderModel?> getById(String id) async {
    final db = await _db;
    final rows = await db.query(table, where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : ReminderModel.fromMap(rows.first);
  }

  Future<List<ReminderModel>> list(String userId) async {
    final db = await _db;
    final rows = await db.query(
      table,
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'scheduled_at ASC',
    );
    return rows.map(ReminderModel.fromMap).toList();
  }

  Future<void> delete(String id) async {
    final db = await _db;
    await db.delete(table, where: 'id = ?', whereArgs: [id]);
  }
}

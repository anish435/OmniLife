import 'package:sqflite/sqflite.dart';

import '../../models/focus_session_model.dart';
import 'app_database.dart';

/// SQLite access for focus sessions. The table is created on demand with
/// [ensureSchema] so this module needs no change to [AppDatabase]'s schema
/// version.
class LocalFocusDataSource {
  LocalFocusDataSource({Future<Database> Function()? databaseProvider})
    : _databaseProvider =
          databaseProvider ?? (() => AppDatabase.instance.database);

  static const table = 'focus_sessions';

  final Future<Database> Function() _databaseProvider;
  Database? _prepared;

  /// Creates the table and index if they do not exist yet. Idempotent.
  static Future<void> ensureSchema(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $table (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        started_at INTEGER NOT NULL,
        ended_at INTEGER NOT NULL,
        planned_seconds INTEGER NOT NULL,
        focused_seconds INTEGER NOT NULL,
        completed INTEGER NOT NULL DEFAULT 1
      )
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_focus_sessions_user_started
      ON $table (user_id, started_at)
    ''');
  }

  Future<Database> _db() async {
    final db = await _databaseProvider();
    if (!identical(_prepared, db)) {
      await ensureSchema(db);
      _prepared = db;
    }
    return db;
  }

  Future<void> insert(FocusSessionModel session) async {
    final db = await _db();
    await db.insert(
      table,
      session.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<FocusSessionModel>> getSessions(
    String userId, {
    DateTime? since,
  }) async {
    final db = await _db();
    final rows = await db.query(
      table,
      where: since == null ? 'user_id = ?' : 'user_id = ? AND started_at >= ?',
      whereArgs: [userId, if (since != null) since.millisecondsSinceEpoch],
      orderBy: 'started_at DESC',
    );
    return rows.map(FocusSessionModel.fromMap).toList();
  }
}

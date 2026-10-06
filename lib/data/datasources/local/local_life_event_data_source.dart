import 'package:sqflite/sqflite.dart';

import '../../models/life_event_model.dart';
import 'app_database.dart';

/// SQLite access for OmniPulse events. Owns its own table (created lazily)
/// so it does not depend on the shared schema version.
class LocalLifeEventDataSource {
  LocalLifeEventDataSource({Future<Database> Function()? databaseProvider})
    : _databaseProvider =
          databaseProvider ?? (() => AppDatabase.instance.database);

  final Future<Database> Function() _databaseProvider;
  static const table = 'life_events';

  static Future<void> ensureSchema(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $table (
        id TEXT PRIMARY KEY,
        uid TEXT NOT NULL,
        type TEXT NOT NULL,
        timestamp INTEGER NOT NULL,
        metadata TEXT,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        deleted INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_life_events_uid_ts '
      'ON $table (uid, timestamp)',
    );
  }

  Future<Database> get _db async {
    final db = await _databaseProvider();
    await ensureSchema(db);
    return db;
  }

  Future<void> upsert(LifeEventModel model) async {
    final db = await _db;
    await db.insert(
      table,
      model.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<LifeEventModel?> getById(String id) async {
    final db = await _db;
    final rows = await db.query(table, where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : LifeEventModel.fromMap(rows.first);
  }

  /// Live (non-deleted) events with `from <= timestamp < to`.
  Future<List<LifeEventModel>> range(
    String uid,
    DateTime from,
    DateTime to,
  ) async {
    final db = await _db;
    final rows = await db.query(
      table,
      where: 'uid = ? AND deleted = 0 AND timestamp >= ? AND timestamp < ?',
      whereArgs: [uid, from.millisecondsSinceEpoch, to.millisecondsSinceEpoch],
      orderBy: 'timestamp ASC',
    );
    return rows.map(LifeEventModel.fromMap).toList();
  }
}

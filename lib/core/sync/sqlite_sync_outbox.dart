import 'package:sqflite/sqflite.dart';

import 'sync_operation.dart';
import 'sync_outbox.dart';

/// SQLite-backed outbox. Creates its own table so it does not depend on
/// the shared schema version.
class SqliteSyncOutbox implements SyncOutbox {
  SqliteSyncOutbox(this._databaseProvider);

  final Future<Database> Function() _databaseProvider;
  static const table = 'sync_outbox';

  static Future<void> ensureSchema(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $table (
        id TEXT PRIMARY KEY,
        uid TEXT NOT NULL,
        collection TEXT NOT NULL,
        doc_id TEXT NOT NULL,
        type TEXT NOT NULL,
        data TEXT,
        updated_at INTEGER NOT NULL,
        created_at INTEGER NOT NULL,
        attempts INTEGER NOT NULL DEFAULT 0,
        next_attempt_at INTEGER NOT NULL DEFAULT 0,
        last_error TEXT,
        state TEXT NOT NULL DEFAULT 'pending'
      )
    ''');
  }

  Future<Database> get _db async {
    final db = await _databaseProvider();
    await ensureSchema(db);
    return db;
  }

  @override
  Future<void> upsert(SyncOperation op) async {
    final db = await _db;
    await db.insert(
      table,
      op.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> remove(String id) async {
    final db = await _db;
    await db.delete(table, where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<SyncOperation?> get(String id) async {
    final db = await _db;
    final rows = await db.query(table, where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : SyncOperation.fromMap(rows.first);
  }

  @override
  Future<List<SyncOperation>> all() async {
    final db = await _db;
    final rows = await db.query(table, orderBy: 'created_at ASC');
    return rows.map(SyncOperation.fromMap).toList();
  }
}

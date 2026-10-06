import 'package:sqflite/sqflite.dart';

import '../../../domain/entities/saved_location.dart';
import '../../models/saved_location_model.dart';
import 'app_database.dart';

/// A local row that has not been confirmed by Firestore yet.
class PendingLocationChange {
  const PendingLocationChange(this.location, {required this.deleted});
  final SavedLocation location;

  /// True when the user deleted it and the remote delete is outstanding.
  final bool deleted;
}

/// Local persistence for saved locations. SQLite on mobile, in-memory on
/// web (where Firestore is the durable store), both behind this interface.
abstract class SavedLocationLocalStore {
  Future<List<SavedLocation>> getAll(String userId);
  Future<void> upsert(SavedLocation location, {required bool synced});
  Future<void> markSynced(String id);

  /// Tombstones the row (hidden from [getAll], remote delete still due).
  Future<void> markDeleted(String id);

  /// Removes the row entirely (after the remote delete succeeded).
  Future<void> purge(String id);
  Future<List<PendingLocationChange>> getPending(String userId);
}

/// SQLite implementation. The table is created lazily through
/// [ensureSchema] so this module does not touch the shared
/// [AppDatabase] schema version.
class SqliteSavedLocationStore implements SavedLocationLocalStore {
  SqliteSavedLocationStore({Future<Database> Function()? databaseProvider})
    : _databaseProvider =
          databaseProvider ?? (() => AppDatabase.instance.database);

  static const table = 'saved_locations';

  final Future<Database> Function() _databaseProvider;
  bool _schemaReady = false;

  static Future<void> ensureSchema(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $table (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        name TEXT NOT NULL,
        latitude REAL NOT NULL,
        longitude REAL NOT NULL,
        radius_m REAL NOT NULL,
        linked_event_id TEXT,
        linked_task_id TEXT,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        synced INTEGER NOT NULL DEFAULT 0,
        deleted INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_${table}_user ON $table (user_id)',
    );
  }

  Future<Database> _db() async {
    final db = await _databaseProvider();
    if (!_schemaReady) {
      await ensureSchema(db);
      _schemaReady = true;
    }
    return db;
  }

  @override
  Future<List<SavedLocation>> getAll(String userId) async {
    final db = await _db();
    final rows = await db.query(
      table,
      where: 'user_id = ? AND deleted = 0',
      whereArgs: [userId],
      orderBy: 'created_at ASC',
    );
    return rows.map(SavedLocationModel.fromMap).toList();
  }

  @override
  Future<void> upsert(SavedLocation location, {required bool synced}) async {
    final db = await _db();
    await db.insert(table, {
      ...SavedLocationModel.fromEntity(location).toMap(),
      'synced': synced ? 1 : 0,
      'deleted': 0,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<void> markSynced(String id) async {
    final db = await _db();
    await db.update(table, {'synced': 1}, where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<void> markDeleted(String id) async {
    final db = await _db();
    await db.update(
      table,
      {'deleted': 1, 'synced': 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  @override
  Future<void> purge(String id) async {
    final db = await _db();
    await db.delete(table, where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<List<PendingLocationChange>> getPending(String userId) async {
    final db = await _db();
    final rows = await db.query(
      table,
      where: 'user_id = ? AND synced = 0',
      whereArgs: [userId],
    );
    return rows
        .map(
          (r) => PendingLocationChange(
            SavedLocationModel.fromMap(r),
            deleted: (r['deleted'] as int) == 1,
          ),
        )
        .toList();
  }
}

/// In-memory implementation used on web and in tests.
class InMemorySavedLocationStore implements SavedLocationLocalStore {
  final Map<String, _Row> _rows = {};

  @override
  Future<List<SavedLocation>> getAll(String userId) async {
    final list = _rows.values
        .where((r) => r.location.userId == userId && !r.deleted)
        .map((r) => r.location)
        .toList();
    list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return list;
  }

  @override
  Future<void> upsert(SavedLocation location, {required bool synced}) async {
    _rows[location.id] = _Row(location, synced: synced);
  }

  @override
  Future<void> markSynced(String id) async => _rows[id]?.synced = true;

  @override
  Future<void> markDeleted(String id) async {
    final row = _rows[id];
    if (row == null) return;
    row.deleted = true;
    row.synced = false;
  }

  @override
  Future<void> purge(String id) async => _rows.remove(id);

  @override
  Future<List<PendingLocationChange>> getPending(String userId) async => [
    for (final r in _rows.values)
      if (r.location.userId == userId && !r.synced)
        PendingLocationChange(r.location, deleted: r.deleted),
  ];
}

class _Row {
  _Row(this.location, {required this.synced});
  final SavedLocation location;
  bool synced;
  bool deleted = false;
}

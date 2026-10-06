import 'package:sqflite/sqflite.dart';

import 'app_database.dart';

/// A day's local total and whether it still has to be pushed.
class DayTotal {
  const DayTotal(this.day, this.steps, {required this.dirty});
  final String day; // yyyy-MM-dd
  final int steps;
  final bool dirty;
}

/// Local persistence for step aggregates and small per-user prefs.
/// SQLite on mobile, in-memory on web/tests, behind one interface.
abstract class StepsLocalStore {
  /// Adds [steps] to the (day, hour) bucket and the day total, and marks
  /// the day as needing sync.
  Future<void> addSteps(String uid, String day, int hour, int steps);

  Future<List<DayTotal>> getDays(String uid, String fromDay, String toDay);
  Future<Map<int, int>> getHourly(String uid, String day);
  Future<List<DayTotal>> getDirtyDays(String uid);

  /// Clears the dirty flag only if the total still equals [pushedSteps]
  /// (a step recorded while the push was in flight keeps it dirty).
  Future<void> markSynced(String uid, String day, int pushedSteps);

  /// Applies a remote day: raises the local total when the remote is
  /// higher (and replaces hourly buckets then). Never marks dirty.
  /// Returns true if local data changed.
  Future<bool> mergeRemote(
    String uid,
    String day,
    int steps,
    Map<int, int> hourly,
  );

  Future<String?> getPref(String uid, String key);
  Future<void> setPref(String uid, String key, String? value);
}

class SqliteStepsStore implements StepsLocalStore {
  SqliteStepsStore({Future<Database> Function()? databaseProvider})
    : _databaseProvider =
          databaseProvider ?? (() => AppDatabase.instance.database);

  static const dailyTable = 'sensor_steps_daily';
  static const hourlyTable = 'sensor_steps_hourly';
  static const prefsTable = 'sensor_prefs';

  final Future<Database> Function() _databaseProvider;
  bool _schemaReady = false;

  /// Creates this module's tables; safe to call repeatedly. Done here (not
  /// in AppDatabase) so this module needs no schema-version bump.
  static Future<void> ensureSchema(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $dailyTable (
        user_id TEXT NOT NULL,
        day TEXT NOT NULL,
        steps INTEGER NOT NULL DEFAULT 0,
        dirty INTEGER NOT NULL DEFAULT 1,
        updated_at INTEGER NOT NULL,
        PRIMARY KEY (user_id, day)
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $hourlyTable (
        user_id TEXT NOT NULL,
        day TEXT NOT NULL,
        hour INTEGER NOT NULL,
        steps INTEGER NOT NULL DEFAULT 0,
        PRIMARY KEY (user_id, day, hour)
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $prefsTable (
        user_id TEXT NOT NULL,
        key TEXT NOT NULL,
        value TEXT,
        PRIMARY KEY (user_id, key)
      )
    ''');
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
  Future<void> addSteps(String uid, String day, int hour, int steps) async {
    if (steps <= 0) return;
    final db = await _db();
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.transaction((txn) async {
      // Read-modify-write instead of SQL UPSERT: older Android system
      // SQLite builds (before API 30) do not support ON CONFLICT DO UPDATE.
      final h = await txn.query(
        hourlyTable,
        where: 'user_id = ? AND day = ? AND hour = ?',
        whereArgs: [uid, day, hour],
        limit: 1,
      );
      final hourSteps = (h.isEmpty ? 0 : h.first['steps'] as int) + steps;
      await txn.insert(hourlyTable, {
        'user_id': uid,
        'day': day,
        'hour': hour,
        'steps': hourSteps,
      }, conflictAlgorithm: ConflictAlgorithm.replace);

      final d = await txn.query(
        dailyTable,
        where: 'user_id = ? AND day = ?',
        whereArgs: [uid, day],
        limit: 1,
      );
      final daySteps = (d.isEmpty ? 0 : d.first['steps'] as int) + steps;
      await txn.insert(dailyTable, {
        'user_id': uid,
        'day': day,
        'steps': daySteps,
        'dirty': 1,
        'updated_at': now,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    });
  }

  DayTotal _row(Map<String, Object?> r) => DayTotal(
    r['day'] as String,
    r['steps'] as int,
    dirty: (r['dirty'] as int) == 1,
  );

  @override
  Future<List<DayTotal>> getDays(
    String uid,
    String fromDay,
    String toDay,
  ) async {
    final db = await _db();
    final rows = await db.query(
      dailyTable,
      where: 'user_id = ? AND day >= ? AND day <= ?',
      whereArgs: [uid, fromDay, toDay],
      orderBy: 'day ASC',
    );
    return rows.map(_row).toList();
  }

  @override
  Future<Map<int, int>> getHourly(String uid, String day) async {
    final db = await _db();
    final rows = await db.query(
      hourlyTable,
      where: 'user_id = ? AND day = ?',
      whereArgs: [uid, day],
    );
    return {for (final r in rows) r['hour'] as int: r['steps'] as int};
  }

  @override
  Future<List<DayTotal>> getDirtyDays(String uid) async {
    final db = await _db();
    final rows = await db.query(
      dailyTable,
      where: 'user_id = ? AND dirty = 1',
      whereArgs: [uid],
      orderBy: 'day ASC',
    );
    return rows.map(_row).toList();
  }

  @override
  Future<void> markSynced(String uid, String day, int pushedSteps) async {
    final db = await _db();
    await db.update(
      dailyTable,
      {'dirty': 0},
      where: 'user_id = ? AND day = ? AND steps = ?',
      whereArgs: [uid, day, pushedSteps],
    );
  }

  @override
  Future<bool> mergeRemote(
    String uid,
    String day,
    int steps,
    Map<int, int> hourly,
  ) async {
    final db = await _db();
    return db.transaction((txn) async {
      final existing = await txn.query(
        dailyTable,
        where: 'user_id = ? AND day = ?',
        whereArgs: [uid, day],
        limit: 1,
      );
      if (existing.isNotEmpty && (existing.first['steps'] as int) >= steps) {
        return false;
      }
      await txn.insert(dailyTable, {
        'user_id': uid,
        'day': day,
        'steps': steps,
        'dirty': 0,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      await txn.delete(
        hourlyTable,
        where: 'user_id = ? AND day = ?',
        whereArgs: [uid, day],
      );
      for (final e in hourly.entries) {
        await txn.insert(hourlyTable, {
          'user_id': uid,
          'day': day,
          'hour': e.key,
          'steps': e.value,
        });
      }
      return true;
    });
  }

  @override
  Future<String?> getPref(String uid, String key) async {
    final db = await _db();
    final rows = await db.query(
      prefsTable,
      where: 'user_id = ? AND key = ?',
      whereArgs: [uid, key],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first['value'] as String?;
  }

  @override
  Future<void> setPref(String uid, String key, String? value) async {
    final db = await _db();
    if (value == null) {
      await db.delete(
        prefsTable,
        where: 'user_id = ? AND key = ?',
        whereArgs: [uid, key],
      );
      return;
    }
    await db.insert(prefsTable, {
      'user_id': uid,
      'key': key,
      'value': value,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }
}

class InMemoryStepsStore implements StepsLocalStore {
  final Map<String, Map<String, int>> _days = {}; // uid -> day -> steps
  final Map<String, Set<String>> _dirty = {};
  final Map<String, Map<String, Map<int, int>>> _hourly = {};
  final Map<String, String> _prefs = {};

  @override
  Future<void> addSteps(String uid, String day, int hour, int steps) async {
    if (steps <= 0) return;
    final d = _days.putIfAbsent(uid, () => {});
    d[day] = (d[day] ?? 0) + steps;
    _dirty.putIfAbsent(uid, () => {}).add(day);
    final h = _hourly.putIfAbsent(uid, () => {}).putIfAbsent(day, () => {});
    h[hour] = (h[hour] ?? 0) + steps;
  }

  @override
  Future<List<DayTotal>> getDays(
    String uid,
    String fromDay,
    String toDay,
  ) async {
    final d = _days[uid] ?? {};
    final keys =
        d.keys
            .where((k) => k.compareTo(fromDay) >= 0 && k.compareTo(toDay) <= 0)
            .toList()
          ..sort();
    return [
      for (final k in keys)
        DayTotal(k, d[k]!, dirty: _dirty[uid]?.contains(k) ?? false),
    ];
  }

  @override
  Future<Map<int, int>> getHourly(String uid, String day) async =>
      Map.of(_hourly[uid]?[day] ?? {});

  @override
  Future<List<DayTotal>> getDirtyDays(String uid) async {
    final dirty = (_dirty[uid] ?? {}).toList()..sort();
    return [for (final k in dirty) DayTotal(k, _days[uid]![k]!, dirty: true)];
  }

  @override
  Future<void> markSynced(String uid, String day, int pushedSteps) async {
    if (_days[uid]?[day] == pushedSteps) _dirty[uid]?.remove(day);
  }

  @override
  Future<bool> mergeRemote(
    String uid,
    String day,
    int steps,
    Map<int, int> hourly,
  ) async {
    final d = _days.putIfAbsent(uid, () => {});
    if ((d[day] ?? -1) >= steps) return false;
    d[day] = steps;
    _dirty[uid]?.remove(day);
    _hourly.putIfAbsent(uid, () => {})[day] = Map.of(hourly);
    return true;
  }

  @override
  Future<String?> getPref(String uid, String key) async => _prefs['$uid|$key'];

  @override
  Future<void> setPref(String uid, String key, String? value) async {
    if (value == null) {
      _prefs.remove('$uid|$key');
    } else {
      _prefs['$uid|$key'] = value;
    }
  }
}

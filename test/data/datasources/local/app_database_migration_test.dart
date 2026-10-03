import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:omnilife/data/datasources/local/app_database.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('Database upgrades from v1 to v2 without data loss', () async {
    final dbFile = File(p.join(
      Directory.systemTemp.path,
      'omnilife_migration_test_${DateTime.now().microsecondsSinceEpoch}.db',
    ));
    if (dbFile.existsSync()) {
      dbFile.deleteSync();
    }
    final dbPath = dbFile.path;

    // Step 1: Create a v1 schema database with an initial task
    final dbV1 = await databaseFactory.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE tasks (
              id TEXT PRIMARY KEY,
              user_id TEXT NOT NULL,
              title TEXT NOT NULL,
              description TEXT,
              completed INTEGER NOT NULL DEFAULT 0,
              priority TEXT NOT NULL,
              due_date INTEGER,
              created_at INTEGER NOT NULL,
              updated_at INTEGER NOT NULL
            )
          ''');
        },
      ),
    );

    await dbV1.insert('tasks', {
      'id': 'legacy_task_1',
      'user_id': 'u1',
      'title': 'Existing Important Task',
      'completed': 0,
      'priority': 'high',
      'created_at': 1000000,
      'updated_at': 1000000,
    });

    final countBefore =
        (await dbV1.rawQuery('SELECT COUNT(*) FROM tasks')).first.values.first as int;
    expect(countBefore, 1);
    await dbV1.close();

    // Step 2: Open with v2 schema triggering onUpgrade
    final dbV2 = await databaseFactory.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: 2,
        onUpgrade: (db, oldVersion, newVersion) async {
          if (oldVersion < 2) {
            await db.execute('''
              CREATE TABLE calendar_events (
                id TEXT PRIMARY KEY,
                user_id TEXT NOT NULL,
                title TEXT NOT NULL,
                description TEXT,
                start_at INTEGER NOT NULL,
                end_at INTEGER NOT NULL,
                is_all_day INTEGER NOT NULL DEFAULT 0,
                color_tag TEXT NOT NULL,
                type TEXT NOT NULL,
                linked_task_id TEXT,
                created_at INTEGER NOT NULL,
                updated_at INTEGER NOT NULL
              )
            ''');
            await db.execute('''
              CREATE INDEX IF NOT EXISTS idx_calendar_events_user_start
              ON calendar_events (user_id, start_at)
            ''');
          }
        },
      ),
    );

    // Verify task survived
    final countAfter =
        (await dbV2.rawQuery('SELECT COUNT(*) FROM tasks')).first.values.first as int;
    expect(countAfter, 1);

    final taskRows = await dbV2.query('tasks', where: 'id = ?', whereArgs: ['legacy_task_1']);
    expect(taskRows.first['title'], 'Existing Important Task');

    // Verify calendar_events exists and can accept writes
    await dbV2.insert(AppDatabase.eventsTable, {
      'id': 'ev_1',
      'user_id': 'u1',
      'title': 'Kickoff',
      'start_at': 2000000,
      'end_at': 3000000,
      'is_all_day': 0,
      'color_tag': 'blue',
      'type': 'event',
      'created_at': 2000000,
      'updated_at': 2000000,
    });

    final eventRows = await dbV2.query(AppDatabase.eventsTable);
    expect(eventRows, hasLength(1));
    expect(eventRows.first['id'], 'ev_1');

    await dbV2.close();
    if (dbFile.existsSync()) {
      dbFile.deleteSync();
    }
  });
}

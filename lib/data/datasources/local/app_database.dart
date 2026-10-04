import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// OmniLife's local SQLite database.
///
/// Only the `tasks` table exists so far — per docs/architecture.md §4,
/// other local tables (projects, events, notes, habits, expenses,
/// sync_queue) are added when those features are built, not ahead of time.
class AppDatabase {
  AppDatabase._();

  static final AppDatabase instance = AppDatabase._();

  static const schemaVersion = 3;
  static const tasksTable = 'tasks';
  static const eventsTable = 'calendar_events';
  static const notesTable = 'notes';

  static const _createTasksTableSql = '''
    CREATE TABLE $tasksTable (
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
  ''';

  static const _createEventsTableSql = '''
    CREATE TABLE $eventsTable (
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
  ''';

  static const _createEventsIndexSql = '''
    CREATE INDEX IF NOT EXISTS idx_calendar_events_user_start
    ON $eventsTable (user_id, start_at)
  ''';

  static const _createNotesTableSql = '''
    CREATE TABLE $notesTable (
      id TEXT PRIMARY KEY,
      user_id TEXT NOT NULL,
      title TEXT NOT NULL,
      content TEXT NOT NULL,
      category TEXT NOT NULL DEFAULT 'General',
      color_tag TEXT NOT NULL DEFAULT 'default',
      is_pinned INTEGER NOT NULL DEFAULT 0,
      is_archived INTEGER NOT NULL DEFAULT 0,
      tags TEXT,
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL
    )
  ''';

  Database? _database;

  Future<Database> get database async {
    return _database ??= await open();
  }

  /// Opens (creating if needed) the on-disk database. Exposed statically
  /// so tests can open an equivalent in-memory database with the same
  /// schema via [databaseFactory]/`sqflite_common_ffi` instead of this
  /// singleton.
  Future<Database> open() async {
    final databasesPath = await getDatabasesPath();
    final path = p.join(databasesPath, 'omnilife.db');
    return openDatabase(
      path,
      version: schemaVersion,
      onCreate: (db, version) async {
        await db.execute(_createTasksTableSql);
        await db.execute(_createEventsTableSql);
        await db.execute(_createEventsIndexSql);
        await db.execute(_createNotesTableSql);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute(_createEventsTableSql);
          await db.execute(_createEventsIndexSql);
        }
        if (oldVersion < 3) {
          await db.execute(_createNotesTableSql);
        }
      },
    );
  }

  static Future<void> createSchema(Database db) async {
    await db.execute(_createTasksTableSql);
    await db.execute(_createEventsTableSql);
    await db.execute(_createEventsIndexSql);
    await db.execute(_createNotesTableSql);
  }
}


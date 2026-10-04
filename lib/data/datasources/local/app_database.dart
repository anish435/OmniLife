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

  static const schemaVersion = 6;
  static const tasksTable = 'tasks';
  static const eventsTable = 'calendar_events';
  static const notesTable = 'notes';
  static const habitsTable = 'habits';
  static const habitLogsTable = 'habit_logs';
  static const financeTable = 'finance';

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

  static const _createHabitsTableSql = '''
    CREATE TABLE $habitsTable (
      id TEXT PRIMARY KEY,
      user_id TEXT NOT NULL,
      title TEXT NOT NULL,
      description TEXT NOT NULL,
      frequency TEXT NOT NULL,
      target_days_per_week INTEGER NOT NULL,
      specific_days TEXT NOT NULL,
      color_tag TEXT NOT NULL,
      current_streak INTEGER NOT NULL,
      longest_streak INTEGER NOT NULL,
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL
    )
  ''';

  static const _createHabitLogsTableSql = '''
    CREATE TABLE $habitLogsTable (
      id TEXT PRIMARY KEY,
      habit_id TEXT NOT NULL,
      date TEXT NOT NULL,
      is_completed INTEGER NOT NULL DEFAULT 1,
      UNIQUE(habit_id, date),
      FOREIGN KEY(habit_id) REFERENCES $habitsTable(id) ON DELETE CASCADE
    )
  ''';

  static const _createFinanceTableSql = '''
    CREATE TABLE $financeTable (
      id TEXT PRIMARY KEY,
      user_id TEXT NOT NULL,
      amount REAL NOT NULL,
      title TEXT NOT NULL,
      category TEXT NOT NULL,
      date INTEGER NOT NULL,
      is_income INTEGER NOT NULL DEFAULT 0,
      receipt_url TEXT,
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
        await db.execute(_createHabitsTableSql);
        await db.execute(_createHabitLogsTableSql);
        await db.execute(_createFinanceTableSql);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute(_createEventsTableSql);
          await db.execute(_createEventsIndexSql);
        }
        if (oldVersion < 3) {
          await db.execute(_createNotesTableSql);
        }
        if (oldVersion < 4) {
          await db.execute(_createHabitsTableSql);
          await db.execute(_createHabitLogsTableSql);
        }
        if (oldVersion < 5) {
          // In an actual production scenario we would execute the expenses table.
          // But since we immediately changed it to financeTable for v6, we'll just skip to it.
        }
        if (oldVersion < 6) {
          await db.execute(_createFinanceTableSql);
        }
      },
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
    );
  }

  static Future<void> createSchema(Database db) async {
    await db.execute(_createTasksTableSql);
    await db.execute(_createEventsTableSql);
    await db.execute(_createEventsIndexSql);
    await db.execute(_createNotesTableSql);
    await db.execute(_createHabitsTableSql);
    await db.execute(_createHabitLogsTableSql);
    await db.execute(_createFinanceTableSql);
  }
}

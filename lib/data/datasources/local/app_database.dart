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

  static const schemaVersion = 1;
  static const tasksTable = 'tasks';

  static const _createTasksTableSql =
      '''
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
      },
    );
  }

  static Future<void> createSchema(Database db) async {
    await db.execute(_createTasksTableSql);
  }
}

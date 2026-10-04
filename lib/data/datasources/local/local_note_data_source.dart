import 'package:sqflite/sqflite.dart';

import '../../models/note_model.dart';
import 'app_database.dart';

class LocalNoteDataSource {
  LocalNoteDataSource({Future<Database> Function()? databaseProvider})
      : _databaseProvider =
            databaseProvider ?? (() => AppDatabase.instance.database);

  final Future<Database> Function() _databaseProvider;

  Future<void> insertNote(NoteModel note) async {
    final db = await _databaseProvider();
    await db.insert(
      AppDatabase.notesTable,
      note.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<NoteModel>> getNotes(String userId, {bool archived = false}) async {
    final db = await _databaseProvider();
    final rows = await db.query(
      AppDatabase.notesTable,
      where: 'user_id = ? AND is_archived = ?',
      whereArgs: [userId, archived ? 1 : 0],
      orderBy: 'is_pinned DESC, updated_at DESC',
    );
    return rows.map(NoteModel.fromMap).toList();
  }

  Future<NoteModel?> getNoteById(String id) async {
    final db = await _databaseProvider();
    final rows = await db.query(
      AppDatabase.notesTable,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return NoteModel.fromMap(rows.first);
  }

  Future<bool> updateNote(NoteModel note) async {
    final db = await _databaseProvider();
    final count = await db.update(
      AppDatabase.notesTable,
      note.toMap(),
      where: 'id = ?',
      whereArgs: [note.id],
    );
    return count > 0;
  }

  Future<bool> deleteNote(String id) async {
    final db = await _databaseProvider();
    final count = await db.delete(
      AppDatabase.notesTable,
      where: 'id = ?',
      whereArgs: [id],
    );
    return count > 0;
  }
}

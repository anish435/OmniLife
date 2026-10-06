import 'package:omnilife/domain/entities/note.dart';
import 'package:omnilife/domain/repositories/note_repository.dart';

class FakeNoteRepository implements NoteRepository {
  final Map<String, Note> storage = {};
  bool failWrites = false;
  bool failReads = false;

  @override
  Future<List<Note>> getNotes(String userId) async {
    if (failReads) throw Exception('read failed');
    return storage.values
        .where((n) => n.userId == userId && !n.isArchived)
        .toList();
  }

  @override
  Future<List<Note>> getArchivedNotes(String userId) async {
    if (failReads) throw Exception('read failed');
    return storage.values
        .where((n) => n.userId == userId && n.isArchived)
        .toList();
  }

  @override
  Future<Note> createNote(Note note) async {
    if (failWrites) throw Exception('write failed');
    storage[note.id] = note;
    return note;
  }

  @override
  Future<Note> updateNote(Note note) async {
    if (failWrites) throw Exception('write failed');
    storage[note.id] = note;
    return note;
  }

  @override
  Future<void> deleteNote(String noteId) async {
    if (failWrites) throw Exception('write failed');
    storage.remove(noteId);
  }

  @override
  Future<List<Note>> searchNotes(String userId, String query) async => [];
}

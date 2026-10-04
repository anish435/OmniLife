import '../entities/note.dart';

abstract class NoteRepository {
  /// Fetches all non-archived notes for a user
  Future<List<Note>> getNotes(String userId);

  /// Fetches all archived notes for a user
  Future<List<Note>> getArchivedNotes(String userId);

  /// Creates a new note
  Future<Note> createNote(Note note);

  /// Updates an existing note
  Future<Note> updateNote(Note note);

  /// Permanently deletes a note
  Future<void> deleteNote(String noteId);
  
  /// Searches notes via local FTS or basic filtering
  Future<List<Note>> searchNotes(String userId, String query);
}

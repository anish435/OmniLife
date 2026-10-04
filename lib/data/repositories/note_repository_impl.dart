import 'package:flutter/foundation.dart';

import '../../domain/entities/note.dart';
import '../../domain/repositories/note_repository.dart';
import '../datasources/local/local_note_data_source.dart';
import '../datasources/remote/firestore_paths.dart';
import '../datasources/remote/user_scoped_firestore_datasource.dart';
import '../models/note_model.dart';

class NoteRepositoryImpl implements NoteRepository {
  NoteRepositoryImpl({
    LocalNoteDataSource? localDataSource,
    UserScopedFirestoreDataSource? remoteDataSource,
  })  : _localDataSource = localDataSource ?? LocalNoteDataSource(),
        _remoteDataSource =
            remoteDataSource ?? UserScopedFirestoreDataSource();

  final LocalNoteDataSource _localDataSource;
  final UserScopedFirestoreDataSource _remoteDataSource;

  final Map<String, NoteModel> _memoryCache = {};

  void _syncToRemote(String userId, NoteModel model) {
    if (kIsWeb) {
      _remoteDataSource
          .set(userId, FirestoreCollections.notes, model.id, model.toFirestoreMap())
          .catchError((_) {});
    } else {
      // In a real app, we'd add to sync_queue. For now, best-effort.
      _remoteDataSource
          .set(userId, FirestoreCollections.notes, model.id, model.toFirestoreMap())
          .catchError((_) {});
    }
  }

  void _deleteFromRemote(String userId, String noteId) {
    if (kIsWeb) {
      _remoteDataSource
          .delete(userId, FirestoreCollections.notes, noteId)
          .catchError((_) {});
    } else {
      _remoteDataSource
          .delete(userId, FirestoreCollections.notes, noteId)
          .catchError((_) {});
    }
  }

  @override
  Future<List<Note>> getNotes(String userId) async {
    if (kIsWeb) {
      try {
        final docs = await _remoteDataSource.list(
          userId,
          FirestoreCollections.notes,
        );
        final notes = docs.map(NoteModel.fromMap).where((e) => !e.isArchived).toList();
        notes.sort((a, b) {
          if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
          return b.updatedAt.compareTo(a.updatedAt);
        });
        for (final n in notes) {
          _memoryCache[n.id] = n;
        }
        return notes;
      } catch (_) {
        return _memoryCache.values.where((e) => !e.isArchived && e.userId == userId).toList();
      }
    }

    final localNotes = await _localDataSource.getNotes(userId, archived: false);
    for (final n in localNotes) {
      _memoryCache[n.id] = n;
    }
    
    // Background remote sync omitted for brevity, local is source of truth on mobile
    return localNotes;
  }

  @override
  Future<List<Note>> getArchivedNotes(String userId) async {
    if (kIsWeb) {
      try {
        final docs = await _remoteDataSource.list(
          userId,
          FirestoreCollections.notes,
        );
        final notes = docs.map(NoteModel.fromMap).where((e) => e.isArchived).toList();
        notes.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
        for (final n in notes) {
          _memoryCache[n.id] = n;
        }
        return notes;
      } catch (_) {
        return _memoryCache.values.where((e) => e.isArchived && e.userId == userId).toList();
      }
    }

    final localNotes = await _localDataSource.getNotes(userId, archived: true);
    for (final n in localNotes) {
      _memoryCache[n.id] = n;
    }
    return localNotes;
  }

  @override
  Future<Note> createNote(Note note) async {
    final model = NoteModel.fromEntity(note);
    _memoryCache[model.id] = model;

    if (!kIsWeb) {
      await _localDataSource.insertNote(model);
    }

    _syncToRemote(note.userId, model);

    return model;
  }

  @override
  Future<Note> updateNote(Note note) async {
    final model = NoteModel.fromEntity(note);
    _memoryCache[model.id] = model;

    if (!kIsWeb) {
      await _localDataSource.updateNote(model);
    }

    _syncToRemote(note.userId, model);

    return model;
  }

  @override
  Future<void> deleteNote(String noteId) async {
    final existing = _memoryCache[noteId];
    _memoryCache.remove(noteId);

    if (!kIsWeb) {
      await _localDataSource.deleteNote(noteId);
    }

    if (existing != null) {
      _deleteFromRemote(existing.userId, noteId);
    }
  }

  @override
  Future<List<Note>> searchNotes(String userId, String query) async {
    final q = query.toLowerCase();
    
    // Naive local search for now. Real FTS5 would be via SQLite.
    final all = _memoryCache.values.where((e) => e.userId == userId).toList();
    return all.where((note) {
      if (note.title.toLowerCase().contains(q)) return true;
      if (note.content.toLowerCase().contains(q)) return true;
      if (note.tags.any((t) => t.toLowerCase().contains(q))) return true;
      return false;
    }).toList();
  }
}

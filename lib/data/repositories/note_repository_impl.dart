// ignore_for_file: prefer_initializing_formals
import 'package:flutter/foundation.dart';

import '../../core/sync/repository_sync.dart';
import '../../core/sync/sync_engine.dart';
import '../../domain/entities/note.dart';
import '../../domain/repositories/note_repository.dart';
import '../../domain/usecases/notes/note_search_ranker.dart';
import '../datasources/local/local_note_data_source.dart';
import '../datasources/remote/firestore_paths.dart';
import '../datasources/remote/user_scoped_firestore_datasource.dart';
import '../models/note_model.dart';

class NoteRepositoryImpl implements NoteRepository {
  NoteRepositoryImpl({
    LocalNoteDataSource? localDataSource,
    UserScopedFirestoreDataSource? remoteDataSource,
    SyncEngine? syncEngine,
  }) : _localDataSource = localDataSource ?? LocalNoteDataSource(),
       _remoteDataSource = remoteDataSource ?? UserScopedFirestoreDataSource(),
       _syncEngine = syncEngine;

  final LocalNoteDataSource _localDataSource;
  final UserScopedFirestoreDataSource _remoteDataSource;
  final SyncEngine? _syncEngine;

  /// Durable, retried uploads through the shared [SyncEngine].
  late final RepositorySync _sync = RepositorySync(
    engine: _syncEngine,
    fallbackSet: (u, c, i, d) => _remoteDataSource.set(u, c, i, d),
    fallbackDelete: (u, c, i) => _remoteDataSource.delete(u, c, i),
  );

  final Map<String, NoteModel> _memoryCache = {};

  Future<void> _syncToRemote(String userId, NoteModel model) async {
    await _sync.set(
      userId,
      FirestoreCollections.notes,
      model.id,
      model.toFirestoreMap(),
      updatedAt: model.updatedAt,
    );
  }

  Future<void> _deleteFromRemote(String userId, String noteId) async {
    await _sync.delete(userId, FirestoreCollections.notes, noteId);
  }

  @override
  Future<List<Note>> getNotes(String userId) async {
    if (kIsWeb) {
      try {
        final docs = await _sync.overlay(
          userId,
          FirestoreCollections.notes,
          await _remoteDataSource.list(userId, FirestoreCollections.notes),
        );
        final remote = docs.map(NoteModel.fromMap).toList();
        // Remote wins, but notes created locally that have not synced yet
        // (offline / timeout) must not vanish from the list.
        final merged = <String, NoteModel>{
          for (final n in _memoryCache.values.where((e) => e.userId == userId))
            n.id: n,
          for (final n in remote)
            if ((_memoryCache[n.id]?.updatedAt ?? n.updatedAt).isAfter(
              n.updatedAt,
            ))
              n.id: _memoryCache[n.id]!
            else
              n.id: n,
        };
        _memoryCache
          ..removeWhere((_, v) => v.userId == userId)
          ..addAll(merged);
        final notes = merged.values.where((e) => !e.isArchived).toList();
        notes.sort((a, b) {
          if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
          return b.updatedAt.compareTo(a.updatedAt);
        });
        for (final n in notes) {
          _memoryCache[n.id] = n;
        }
        return notes;
      } catch (_) {
        return _memoryCache.values
            .where((e) => !e.isArchived && e.userId == userId)
            .toList();
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
        final docs = await _sync.overlay(
          userId,
          FirestoreCollections.notes,
          await _remoteDataSource.list(userId, FirestoreCollections.notes),
        );
        for (final n in docs.map(NoteModel.fromMap)) {
          _memoryCache[n.id] = n;
        }
        final notes = _memoryCache.values
            .where((e) => e.isArchived && e.userId == userId)
            .toList();
        notes.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
        return notes;
      } catch (_) {
        return _memoryCache.values
            .where((e) => e.isArchived && e.userId == userId)
            .toList();
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

    await _syncToRemote(note.userId, model);

    return model;
  }

  @override
  Future<Note> updateNote(Note note) async {
    final model = NoteModel.fromEntity(note);
    _memoryCache[model.id] = model;

    if (!kIsWeb) {
      await _localDataSource.updateNote(model);
    }

    await _syncToRemote(note.userId, model);

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
      await _deleteFromRemote(existing.userId, noteId);
    }
  }

  @override
  Future<List<Note>> searchNotes(String userId, String query) async {
    final active = await getNotes(userId);
    final archived = await getArchivedNotes(userId);
    return NoteSearchRanker.rank([
      ...active,
      ...archived,
    ], query).map((r) => r.note).toList();
  }
}

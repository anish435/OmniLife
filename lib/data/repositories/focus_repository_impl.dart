// ignore_for_file: prefer_initializing_formals
import 'package:flutter/foundation.dart';

import '../../core/errors/failures.dart';
import '../../core/sync/repository_sync.dart';
import '../../core/sync/sync_engine.dart';
import '../../domain/entities/focus_session.dart';
import '../../domain/repositories/focus_repository.dart';
import '../datasources/local/local_focus_data_source.dart';
import '../datasources/remote/firestore_paths.dart';
import '../datasources/remote/user_scoped_firestore_datasource.dart';
import '../models/focus_session_model.dart';

/// SQLite on mobile/desktop, in-memory plus Firestore on web, with
/// best-effort background sync to `users/{uid}/focus_sessions`.
class FocusRepositoryImpl implements FocusRepository {
  FocusRepositoryImpl({
    LocalFocusDataSource? dataSource,
    UserScopedFirestoreDataSource? remoteDataSource,
    bool? useLocalDatabase,
    SyncEngine? syncEngine,
  }) : _local = dataSource,
       _remote = remoteDataSource,
       _useLocal = useLocalDatabase ?? !kIsWeb,
       _syncEngine = syncEngine;

  final LocalFocusDataSource? _local;
  final UserScopedFirestoreDataSource? _remote;
  final bool _useLocal;
  final SyncEngine? _syncEngine;

  /// Durable, retried uploads through the shared [SyncEngine].
  late final RepositorySync _sync = RepositorySync(
    engine: _syncEngine,
    fallbackSet: (u, c, i, d) => _remoteDs.set(u, c, i, d),
    fallbackDelete: (u, c, i) => _remoteDs.delete(u, c, i),
  );

  final Map<String, FocusSession> _cache = {};

  LocalFocusDataSource get _localDs => _local ?? LocalFocusDataSource();
  UserScopedFirestoreDataSource get _remoteDs =>
      _remote ?? UserScopedFirestoreDataSource();

  @override
  Future<FocusSession> saveSession(FocusSession session) async {
    try {
      final model = FocusSessionModel.fromEntity(session);
      _cache[model.id] = model;
      if (_useLocal) await _localDs.insert(model);
      await _syncToRemote(model);
      return model;
    } catch (e) {
      throw DatabaseFailure('Failed to save focus session: $e');
    }
  }

  /// Queues the upload. The local copy is already saved; the engine keeps
  /// retrying until the server has the session.
  Future<void> _syncToRemote(FocusSessionModel model) async {
    await _sync.set(
      model.userId,
      FirestoreCollections.focusSessions,
      model.id,
      model.toFirestoreMap(),
      updatedAt: model.endedAt,
    );
  }

  @override
  Future<List<FocusSession>> getSessions(
    String userId, {
    DateTime? since,
  }) async {
    try {
      List<FocusSession> sessions;
      if (_useLocal) {
        sessions = await _localDs.getSessions(userId, since: since);
        _mergeRemote(userId);
      } else {
        final docs = await _sync.overlay(
          userId,
          FirestoreCollections.focusSessions,
          await _remoteDs.list(userId, FirestoreCollections.focusSessions),
        );
        for (final d in docs) {
          final m = FocusSessionModel.fromMap({...d, 'userId': userId});
          _cache[m.id] = m;
        }
        sessions =
            _cache.values
                .where(
                  (s) =>
                      s.userId == userId &&
                      (since == null || !s.startedAt.isBefore(since)),
                )
                .toList()
              ..sort((a, b) => b.startedAt.compareTo(a.startedAt));
      }
      return sessions;
    } catch (e) {
      throw DatabaseFailure('Failed to load focus sessions: $e');
    }
  }

  /// Pulls sessions recorded on other devices into local storage.
  void _mergeRemote(String userId) async {
    try {
      final docs = await _remoteDs.list(
        userId,
        FirestoreCollections.focusSessions,
      );
      for (final d in docs) {
        await _localDs.insert(
          FocusSessionModel.fromMap({...d, 'userId': userId}),
        );
      }
    } catch (_) {}
  }
}

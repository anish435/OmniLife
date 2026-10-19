// ignore_for_file: prefer_initializing_formals
import 'package:flutter/foundation.dart';

import '../../core/errors/failures.dart';
import '../../core/sync/repository_sync.dart';
import '../../core/sync/sync_engine.dart';
import '../../domain/entities/calendar_event.dart';
import '../../domain/repositories/calendar_repository.dart';
import '../datasources/local/local_calendar_data_source.dart';
import '../datasources/remote/firestore_paths.dart';
import '../datasources/remote/user_scoped_firestore_datasource.dart';
import '../models/calendar_event_model.dart';

/// Implementation of [CalendarRepository] backed by local SQLite storage and remote Firestore.
class CalendarRepositoryImpl implements CalendarRepository {
  CalendarRepositoryImpl({
    this.dataSource,
    this.remoteDataSource,
    SyncEngine? syncEngine,
  }) : _syncEngine = syncEngine;

  final LocalCalendarDataSource? dataSource;
  final UserScopedFirestoreDataSource? remoteDataSource;
  final SyncEngine? _syncEngine;

  /// Durable, retried uploads through the shared [SyncEngine].
  late final RepositorySync _sync = RepositorySync(
    engine: _syncEngine,
    fallbackSet: (u, c, i, d) => _resolvedRemoteDataSource.set(u, c, i, d),
    fallbackDelete: (u, c, i) => _resolvedRemoteDataSource.delete(u, c, i),
  );

  final Map<String, CalendarEvent> _memoryCache = {};

  LocalCalendarDataSource get _resolvedLocalDataSource =>
      dataSource ?? LocalCalendarDataSource();

  UserScopedFirestoreDataSource get _resolvedRemoteDataSource =>
      remoteDataSource ?? UserScopedFirestoreDataSource();

  @override
  Future<List<CalendarEvent>> getEventsForRange(
    String userId,
    DateTime start,
    DateTime end,
  ) async {
    try {
      if (kIsWeb) {
        try {
          // Layer writes that have not uploaded yet over the server copy.
          final docs = await _sync.overlay(
            userId,
            FirestoreCollections.events,
            await _resolvedRemoteDataSource.list(
              userId,
              FirestoreCollections.events,
            ),
          );
          final events = docs.map(CalendarEventModel.fromMap).toList();
          for (final e in events) {
            _memoryCache[e.id] = e;
          }
          return _filterCacheForRange(userId, start, end);
        } catch (_) {
          return _filterCacheForRange(userId, start, end);
        }
      }

      final startMillis = start.millisecondsSinceEpoch;
      final endMillis = end.millisecondsSinceEpoch;
      final localEvents = await _resolvedLocalDataSource.getEventsForRange(
        userId,
        startMillis,
        endMillis,
      );

      for (final e in localEvents) {
        _memoryCache[e.id] = e;
      }

      // Background sync from remote
      _syncFromRemote(userId);

      return localEvents;
    } catch (e) {
      if (_memoryCache.isNotEmpty) {
        return _filterCacheForRange(userId, start, end);
      }
      throw DatabaseFailure('Failed to load events: $e');
    }
  }

  List<CalendarEvent> _filterCacheForRange(
    String userId,
    DateTime start,
    DateTime end,
  ) {
    return _memoryCache.values.where((e) {
      if (e.userId != userId) return false;
      return e.startAt.isBefore(end) && e.endAt.isAfter(start);
    }).toList()
      ..sort((a, b) => a.startAt.compareTo(b.startAt));
  }

  void _syncFromRemote(String userId) async {
    try {
      final remoteDocs = await _resolvedRemoteDataSource.list(
        userId,
        FirestoreCollections.events,
      );
      // A queued local change (or delete) is newer than what the server has.
      final pending = await _sync.pendingIds(
        userId,
        FirestoreCollections.events,
      );
      for (final doc in remoteDocs) {
        final model = CalendarEventModel.fromMap(doc);
        if (pending.contains(model.id)) continue;
        _memoryCache[model.id] = model;
        await _resolvedLocalDataSource.insertEvent(model);
      }
    } catch (_) {}
  }

  @override
  Future<CalendarEvent?> getEvent(String id) async {
    if (_memoryCache.containsKey(id)) {
      return _memoryCache[id];
    }
    try {
      if (!kIsWeb) {
        final local = await _resolvedLocalDataSource.getEventById(id);
        if (local != null) {
          _memoryCache[id] = local;
          return local;
        }
      }
      return null;
    } catch (e) {
      throw DatabaseFailure('Failed to load event: $e');
    }
  }

  @override
  Future<CalendarEvent> createEvent(CalendarEvent event) async {
    try {
      final model = CalendarEventModel.fromEntity(event);
      _memoryCache[model.id] = model;

      if (!kIsWeb) {
        await _resolvedLocalDataSource.insertEvent(model);
      }

      await _syncEventToRemote(event.userId, model);

      return model;
    } catch (e) {
      throw DatabaseFailure('Failed to create event: $e');
    }
  }

  /// Queues the write; the local copy is already saved, and the engine
  /// retries until the server accepts it.
  Future<void> _syncEventToRemote(
    String userId,
    CalendarEventModel model,
  ) async {
    await _sync.set(
      userId,
      FirestoreCollections.events,
      model.id,
      model.toFirestoreMap(),
      updatedAt: model.updatedAt,
    );
  }

  @override
  Future<CalendarEvent> updateEvent(CalendarEvent event) async {
    try {
      final updated = CalendarEventModel.fromEntity(
        event.copyWith(updatedAt: DateTime.now()),
      );

      if (!kIsWeb) {
        final ok = await _resolvedLocalDataSource.updateEvent(updated);
        if (!ok) {
          throw DatabaseFailure('Event ${event.id} does not exist.');
        }
      } else {
        if (!_memoryCache.containsKey(event.id)) {
          throw DatabaseFailure('Event ${event.id} does not exist.');
        }
      }

      _memoryCache[updated.id] = updated;

      await _syncEventToRemote(event.userId, updated);

      return updated;
    } on Failure {
      rethrow;
    } catch (e) {
      throw DatabaseFailure('Failed to update event: $e');
    }
  }

  @override
  Future<void> deleteEvent(String id) async {
    try {
      if (!kIsWeb) {
        final ok = await _resolvedLocalDataSource.deleteEvent(id);
        if (!ok) {
          throw DatabaseFailure('Event $id does not exist.');
        }
      } else {
        if (!_memoryCache.containsKey(id)) {
          throw DatabaseFailure('Event $id does not exist.');
        }
      }

      final event = _memoryCache.remove(id);
      final userId = event?.userId;

      if (userId != null) {
        await _syncDeleteToRemote(userId, id);
      }
    } on Failure {
      rethrow;
    } catch (e) {
      throw DatabaseFailure('Failed to delete event: $e');
    }
  }

  Future<void> _syncDeleteToRemote(String userId, String id) async {
    await _sync.delete(userId, FirestoreCollections.events, id);
  }
}

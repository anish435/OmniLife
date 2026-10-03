import 'package:flutter/foundation.dart';

import '../../core/errors/failures.dart';
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
  });

  final LocalCalendarDataSource? dataSource;
  final UserScopedFirestoreDataSource? remoteDataSource;

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
          final docs = await _resolvedRemoteDataSource.list(
            userId,
            FirestoreCollections.events,
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
      for (final doc in remoteDocs) {
        final model = CalendarEventModel.fromMap(doc);
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

      // Sync to Firestore
      try {
        await _resolvedRemoteDataSource.update(
          event.userId,
          FirestoreCollections.events,
          event.id,
          model.toFirestoreMap(),
        );
      } catch (_) {}

      return model;
    } catch (e) {
      throw DatabaseFailure('Failed to create event: $e');
    }
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

      try {
        await _resolvedRemoteDataSource.update(
          event.userId,
          FirestoreCollections.events,
          event.id,
          updated.toFirestoreMap(),
        );
      } catch (_) {}

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
        try {
          await _resolvedRemoteDataSource.delete(
            userId,
            FirestoreCollections.events,
            id,
          );
        } catch (_) {}
      }
    } on Failure {
      rethrow;
    } catch (e) {
      throw DatabaseFailure('Failed to delete event: $e');
    }
  }
}

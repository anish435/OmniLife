import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../domain/entities/habit.dart';
import '../../domain/repositories/habit_repository.dart';
import '../datasources/local/local_habit_data_source.dart';
import '../datasources/remote/firestore_paths.dart';
import '../datasources/remote/user_scoped_firestore_datasource.dart';
import '../models/habit_model.dart';

/// Firestore sub-collection for completion logs: `users/{uid}/habit_logs`.
/// Doc id is `{habitId}_{yyyy-MM-dd}` so a day can only exist once.
const habitLogsCollection = 'habit_logs';

class HabitRepositoryImpl implements HabitRepository {
  HabitRepositoryImpl({
    LocalHabitDataSource? localDataSource,
    UserScopedFirestoreDataSource? remoteDataSource,
    bool? useLocalStorage,
  }) : _localDataSource = localDataSource ?? LocalHabitDataSource(),
       _remoteDataSource = remoteDataSource ?? UserScopedFirestoreDataSource(),
       _useLocal = useLocalStorage ?? !kIsWeb;

  final LocalHabitDataSource _localDataSource;
  final UserScopedFirestoreDataSource _remoteDataSource;

  /// SQLite on mobile; on web the in-memory cache plus Firestore.
  final bool _useLocal;

  final Map<String, HabitModel> _memoryCache = {};

  /// habitId -> (date -> log). Authoritative on web, a mirror on mobile.
  final Map<String, Map<String, HabitLogModel>> _logCache = {};

  String _logDocId(String habitId, String date) => '${habitId}_$date';

  void _syncToRemote(String userId, HabitModel model) {
    _remoteDataSource
        .set(
          userId,
          FirestoreCollections.habits,
          model.id,
          model.toFirestoreMap(),
        )
        .catchError((_) {});
  }

  void _deleteFromRemote(String userId, String habitId) {
    _remoteDataSource
        .delete(userId, FirestoreCollections.habits, habitId)
        .catchError((_) {});
  }

  @override
  Future<List<Habit>> getHabits(String userId) async {
    if (!_useLocal) {
      final docs = await _remoteDataSource.list(
        userId,
        FirestoreCollections.habits,
      );
      for (final h in docs.map(HabitModel.fromMap)) {
        final cached = _memoryCache[h.id];
        if (cached == null || !cached.updatedAt.isAfter(h.updatedAt)) {
          _memoryCache[h.id] = h;
        }
      }
      await _loadRemoteLogs(userId);
      return _memoryCache.values.where((e) => e.userId == userId).toList()
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    }

    final localHabits = await _localDataSource.getHabits(userId);
    for (final h in localHabits) {
      _memoryCache[h.id] = h;
    }
    return localHabits;
  }

  Future<void> _loadRemoteLogs(String userId) async {
    final docs = await _remoteDataSource.list(userId, habitLogsCollection);
    for (final doc in docs) {
      final log = HabitLogModel.fromMap({
        'id': doc['id'],
        'habitId': doc['habitId'],
        'date': doc['date'],
        'isCompleted': doc['isCompleted'] ?? true,
      });
      if (log.habitId.isEmpty || log.date.isEmpty || !log.isCompleted) continue;
      (_logCache[log.habitId] ??= {})[log.date] = log;
    }
  }

  @override
  Future<List<HabitLog>> getHabitLogs(String habitId) async {
    if (!_useLocal) {
      return (_logCache[habitId]?.values.toList() ?? <HabitLogModel>[])
        ..sort((a, b) => b.date.compareTo(a.date));
    }
    return _localDataSource.getHabitLogs(habitId);
  }

  @override
  Future<Habit> createHabit(Habit habit) async {
    final model = HabitModel.fromEntity(habit);
    _memoryCache[model.id] = model;

    if (_useLocal) {
      await _localDataSource.insertHabit(model);
    }

    _syncToRemote(habit.userId, model);
    return model;
  }

  @override
  Future<Habit> updateHabit(Habit habit) async {
    final model = HabitModel.fromEntity(habit);
    _memoryCache[model.id] = model;

    if (_useLocal) {
      await _localDataSource.updateHabit(model);
    }

    _syncToRemote(habit.userId, model);
    return model;
  }

  @override
  Future<void> deleteHabit(String habitId) async {
    final existing = _memoryCache[habitId];
    _memoryCache.remove(habitId);
    final logs = _logCache.remove(habitId);

    if (_useLocal) {
      await _localDataSource.deleteHabit(habitId);
    }

    if (existing != null) {
      _deleteFromRemote(existing.userId, habitId);
      for (final date in logs?.keys ?? const <String>[]) {
        _remoteDataSource
            .delete(
              existing.userId,
              habitLogsCollection,
              _logDocId(habitId, date),
            )
            .catchError((_) {});
      }
    }
  }

  @override
  Future<HabitLog?> toggleHabitLog(String habitId, String date) async {
    final bool exists;
    if (_useLocal) {
      final logs = await _localDataSource.getHabitLogs(habitId);
      exists = logs.any((e) => e.date == date);
    } else {
      exists = _logCache[habitId]?.containsKey(date) ?? false;
    }

    final userId = _memoryCache[habitId]?.userId;
    final docId = _logDocId(habitId, date);

    if (exists) {
      if (_useLocal) await _localDataSource.deleteHabitLog(habitId, date);
      _logCache[habitId]?.remove(date);
      if (userId != null) {
        _remoteDataSource
            .delete(userId, habitLogsCollection, docId)
            .catchError((_) {});
      }
      return null;
    }

    final log = HabitLogModel(
      id: const Uuid().v4(),
      habitId: habitId,
      date: date,
      isCompleted: true,
    );
    if (_useLocal) await _localDataSource.insertHabitLog(log);
    (_logCache[habitId] ??= {})[date] = log;
    if (userId != null) {
      _remoteDataSource
          .set(userId, habitLogsCollection, docId, log.toFirestoreMap())
          .catchError((_) {});
    }
    return log;
  }
}

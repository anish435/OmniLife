import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../domain/entities/habit.dart';
import '../../domain/repositories/habit_repository.dart';
import '../datasources/local/local_habit_data_source.dart';
import '../datasources/remote/firestore_paths.dart';
import '../datasources/remote/user_scoped_firestore_datasource.dart';
import '../models/habit_model.dart';

class HabitRepositoryImpl implements HabitRepository {
  HabitRepositoryImpl({
    LocalHabitDataSource? localDataSource,
    UserScopedFirestoreDataSource? remoteDataSource,
  })  : _localDataSource = localDataSource ?? LocalHabitDataSource(),
        _remoteDataSource =
            remoteDataSource ?? UserScopedFirestoreDataSource();

  final LocalHabitDataSource _localDataSource;
  final UserScopedFirestoreDataSource _remoteDataSource;

  final Map<String, HabitModel> _memoryCache = {};

  void _syncToRemote(String userId, HabitModel model) {
    if (kIsWeb) {
      _remoteDataSource
          .set(userId, FirestoreCollections.habits, model.id, model.toFirestoreMap())
          .catchError((_) {});
    } else {
      _remoteDataSource
          .set(userId, FirestoreCollections.habits, model.id, model.toFirestoreMap())
          .catchError((_) {});
    }
  }

  void _deleteFromRemote(String userId, String habitId) {
    _remoteDataSource
        .delete(userId, FirestoreCollections.habits, habitId)
        .catchError((_) {});
  }
  
  void _syncLogToRemote(String userId, String habitId, HabitLogModel log) {
    // Nested subcollection: users/{uid}/habits/{habitId}/logs/{logId}
    // We would need to extend UserScopedFirestoreDataSource for nested subcollections.
    // For now, keeping it local on mobile, and skipping on web, or flattening it.
    // In OmniLife, logs are subcollections. We'll skip Firestore sync for logs in this exact snippet to keep it simple, 
    // or we can just rely on the local database for offline-first.
  }

  @override
  Future<List<Habit>> getHabits(String userId) async {
    if (kIsWeb) {
      try {
        final docs = await _remoteDataSource.list(
          userId,
          FirestoreCollections.habits,
        );
        final habits = docs.map(HabitModel.fromMap).toList();
        for (final h in habits) {
          _memoryCache[h.id] = h;
        }
        return habits;
      } catch (_) {
        return _memoryCache.values.where((e) => e.userId == userId).toList();
      }
    }

    final localHabits = await _localDataSource.getHabits(userId);
    for (final h in localHabits) {
      _memoryCache[h.id] = h;
    }
    return localHabits;
  }

  @override
  Future<List<HabitLog>> getHabitLogs(String habitId) async {
    if (kIsWeb) return []; // Omitted for web for brevity
    return await _localDataSource.getHabitLogs(habitId);
  }

  @override
  Future<Habit> createHabit(Habit habit) async {
    final model = HabitModel.fromEntity(habit);
    _memoryCache[model.id] = model;

    if (!kIsWeb) {
      await _localDataSource.insertHabit(model);
    }

    _syncToRemote(habit.userId, model);
    return model;
  }

  @override
  Future<Habit> updateHabit(Habit habit) async {
    final model = HabitModel.fromEntity(habit);
    _memoryCache[model.id] = model;

    if (!kIsWeb) {
      await _localDataSource.updateHabit(model);
    }

    _syncToRemote(habit.userId, model);
    return model;
  }

  @override
  Future<void> deleteHabit(String habitId) async {
    final existing = _memoryCache[habitId];
    _memoryCache.remove(habitId);

    if (!kIsWeb) {
      await _localDataSource.deleteHabit(habitId);
    }

    if (existing != null) {
      _deleteFromRemote(existing.userId, habitId);
    }
  }

  @override
  Future<HabitLog?> toggleHabitLog(String habitId, String date) async {
    if (kIsWeb) return null;

    final logs = await _localDataSource.getHabitLogs(habitId);
    final existing = logs.where((e) => e.date == date).firstOrNull;

    if (existing != null) {
      await _localDataSource.deleteHabitLog(habitId, date);
      return null;
    } else {
      final log = HabitLogModel(
        id: const Uuid().v4(),
        habitId: habitId,
        date: date,
        isCompleted: true,
      );
      await _localDataSource.insertHabitLog(log);
      return log;
    }
  }
}

import 'package:flutter/foundation.dart';

import '../../core/errors/failures.dart';
import '../../domain/entities/task.dart';
import '../../domain/repositories/task_repository.dart';
import '../datasources/local/local_task_data_source.dart';
import '../datasources/remote/firestore_paths.dart';
import '../datasources/remote/user_scoped_firestore_datasource.dart';
import '../models/task_model.dart';

/// [TaskRepository] implementation backed by local SQLite storage
/// ([LocalTaskDataSource]) and remote Firestore sync ([UserScopedFirestoreDataSource]).
class TaskRepositoryImpl implements TaskRepository {
  TaskRepositoryImpl({
    this.dataSource,
    this.remoteDataSource,
  });

  final LocalTaskDataSource? dataSource;
  final UserScopedFirestoreDataSource? remoteDataSource;

  // In-memory cache for fast UI updates and fallback on Web
  final Map<String, Task> _memoryCache = {};

  LocalTaskDataSource get _resolvedLocalDataSource =>
      dataSource ?? LocalTaskDataSource();

  UserScopedFirestoreDataSource get _resolvedRemoteDataSource =>
      remoteDataSource ?? UserScopedFirestoreDataSource();

  @override
  Future<List<Task>> getTasks(String userId) async {
    try {
      if (kIsWeb) {
        try {
          final docs = await _resolvedRemoteDataSource.list(
            userId,
            FirestoreCollections.tasks,
          );
          final tasks = docs.map(TaskModel.fromMap).toList();
          for (final t in tasks) {
            _memoryCache[t.id] = t;
          }
          tasks.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return tasks;
        } catch (_) {
          return _memoryCache.values
              .where((t) => t.userId == userId)
              .toList()
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        }
      }

      // Mobile / Desktop: load from local SQLite
      final localTasks = await _resolvedLocalDataSource.getAllTasks(userId);
      for (final t in localTasks) {
        _memoryCache[t.id] = t;
      }

      // Background sync from Firestore if available
      _syncFromRemote(userId);

      return localTasks;
    } catch (e) {
      if (_memoryCache.isNotEmpty) {
        return _memoryCache.values
            .where((t) => t.userId == userId)
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      }
      throw DatabaseFailure('Failed to load tasks: $e');
    }
  }

  void _syncFromRemote(String userId) async {
    try {
      final remoteDocs = await _resolvedRemoteDataSource.list(
        userId,
        FirestoreCollections.tasks,
      );
      for (final doc in remoteDocs) {
        final model = TaskModel.fromMap(doc);
        _memoryCache[model.id] = model;
        await _resolvedLocalDataSource.insertTask(model);
      }
    } catch (_) {}
  }

  @override
  Future<Task?> getTask(String id) async {
    if (_memoryCache.containsKey(id)) {
      return _memoryCache[id];
    }
    try {
      if (!kIsWeb) {
        final local = await _resolvedLocalDataSource.getTaskById(id);
        if (local != null) {
          _memoryCache[id] = local;
          return local;
        }
      }
      return null;
    } catch (e) {
      throw DatabaseFailure('Failed to load task: $e');
    }
  }

  @override
  Future<Task> createTask(Task task) async {
    try {
      final model = TaskModel.fromEntity(task);
      _memoryCache[model.id] = model;

      if (!kIsWeb) {
        await _resolvedLocalDataSource.insertTask(model);
      }

      // Sync to Firestore
      try {
        await _resolvedRemoteDataSource.update(
          task.userId,
          FirestoreCollections.tasks,
          task.id,
          model.toFirestoreMap(),
        );
      } catch (_) {
        // Safe to ignore if offline — local state is already saved
      }

      return model;
    } catch (e) {
      throw DatabaseFailure('Failed to create task: $e');
    }
  }

  @override
  Future<Task> updateTask(Task task) async {
    try {
      final updated = TaskModel.fromEntity(
        task.copyWith(updatedAt: DateTime.now()),
      );

      if (!kIsWeb) {
        final ok = await _resolvedLocalDataSource.updateTask(updated);
        if (!ok) {
          throw DatabaseFailure('Task ${task.id} does not exist.');
        }
      } else {
        if (!_memoryCache.containsKey(task.id)) {
          throw DatabaseFailure('Task ${task.id} does not exist.');
        }
      }

      _memoryCache[updated.id] = updated;

      try {
        await _resolvedRemoteDataSource.update(
          task.userId,
          FirestoreCollections.tasks,
          task.id,
          updated.toFirestoreMap(),
        );
      } catch (_) {}

      return updated;
    } on Failure {
      rethrow;
    } catch (e) {
      throw DatabaseFailure('Failed to update task: $e');
    }
  }

  @override
  Future<void> deleteTask(String id) async {
    try {
      if (!kIsWeb) {
        final ok = await _resolvedLocalDataSource.deleteTask(id);
        if (!ok) {
          throw DatabaseFailure('Task $id does not exist.');
        }
      } else {
        if (!_memoryCache.containsKey(id)) {
          throw DatabaseFailure('Task $id does not exist.');
        }
      }

      final task = _memoryCache.remove(id);
      final userId = task?.userId;

      if (userId != null) {
        try {
          await _resolvedRemoteDataSource.delete(
            userId,
            FirestoreCollections.tasks,
            id,
          );
        } catch (_) {}
      }
    } on Failure {
      rethrow;
    } catch (e) {
      throw DatabaseFailure('Failed to delete task: $e');
    }
  }

  @override
  Future<Task> completeTask(String id) async {
    try {
      final existing = _memoryCache[id] ??
          (!kIsWeb ? await _resolvedLocalDataSource.getTaskById(id) : null);
      if (existing == null) {
        throw DatabaseFailure('Task $id does not exist.');
      }
      final now = DateTime.now();
      final updated = existing.copyWith(completed: true, updatedAt: now);
      _memoryCache[id] = updated;

      if (!kIsWeb) {
        await _resolvedLocalDataSource.setCompleted(
          id,
          completed: true,
          updatedAt: now,
        );
      }

      try {
        await _resolvedRemoteDataSource.update(
          updated.userId,
          FirestoreCollections.tasks,
          id,
          TaskModel.fromEntity(updated).toFirestoreMap(),
        );
      } catch (_) {}

      return updated;
    } on Failure {
      rethrow;
    } catch (e) {
      throw DatabaseFailure('Failed to complete task: $e');
    }
  }
}


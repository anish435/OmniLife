import 'package:flutter/foundation.dart';

import '../../domain/entities/goal.dart';
import '../../domain/repositories/goal_repository.dart';
import '../datasources/local/local_goal_data_source.dart';
import '../datasources/remote/firestore_paths.dart';
import '../datasources/remote/user_scoped_firestore_datasource.dart';
import '../models/goal_model.dart';

/// Goals live in SQLite on mobile and in Firestore on web, mirrored to
/// `users/{uid}/goals/{goalId}` as best-effort background sync (same pattern
/// as the note and habit repositories).
class GoalRepositoryImpl implements GoalRepository {
  GoalRepositoryImpl({
    LocalGoalDataSource? localDataSource,
    UserScopedFirestoreDataSource? remoteDataSource,
    bool? useLocalStorage,
  }) : _local = localDataSource ?? LocalGoalDataSource(),
       _remote = remoteDataSource ?? UserScopedFirestoreDataSource(),
       _useLocal = useLocalStorage ?? !kIsWeb;

  final LocalGoalDataSource _local;
  final UserScopedFirestoreDataSource _remote;
  final bool _useLocal;

  final Map<String, GoalModel> _memoryCache = {};

  void _syncToRemote(GoalModel model) {
    _remote
        .set(
          model.userId,
          FirestoreCollections.goals,
          model.id,
          model.toFirestoreMap(),
        )
        .catchError((_) {});
  }

  @override
  Future<List<Goal>> getGoals(String userId) async {
    if (!_useLocal) {
      final docs = await _remote.list(userId, FirestoreCollections.goals);
      // Keep goals created locally that have not reached Firestore yet.
      for (final doc in docs) {
        final g = GoalModel.fromMap(doc);
        final cached = _memoryCache[g.id];
        if (cached == null || !cached.updatedAt.isAfter(g.updatedAt)) {
          _memoryCache[g.id] = g;
        }
      }
      return _memoryCache.values.where((g) => g.userId == userId).toList()
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    }
    final goals = await _local.getGoals(userId);
    for (final g in goals) {
      _memoryCache[g.id] = g;
    }
    return goals;
  }

  @override
  Future<Goal> createGoal(Goal goal) async {
    final model = GoalModel.fromEntity(goal);
    _memoryCache[model.id] = model;
    if (_useLocal) await _local.insertGoal(model);
    _syncToRemote(model);
    return model;
  }

  @override
  Future<Goal> updateGoal(Goal goal) async {
    final model = GoalModel.fromEntity(goal);
    _memoryCache[model.id] = model;
    if (_useLocal) await _local.updateGoal(model);
    _syncToRemote(model);
    return model;
  }

  @override
  Future<void> deleteGoal(String goalId) async {
    final existing = _memoryCache.remove(goalId);
    if (_useLocal) await _local.deleteGoal(goalId);
    if (existing != null) {
      _remote
          .delete(existing.userId, FirestoreCollections.goals, goalId)
          .catchError((_) {});
    }
  }
}

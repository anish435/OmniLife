// ignore_for_file: prefer_initializing_formals
import 'package:flutter/foundation.dart';
import '../../core/sync/repository_sync.dart';
import '../../core/sync/sync_engine.dart';
import '../../domain/entities/wellness_log.dart';
import '../../domain/repositories/wellness_repository.dart';
import '../datasources/local/local_wellness_data_source.dart';
import '../datasources/remote/user_scoped_firestore_datasource.dart';
import '../datasources/remote/firestore_paths.dart';
import '../models/wellness_log_model.dart';
import 'package:uuid/uuid.dart';

class WellnessRepositoryImpl implements WellnessRepository {
  final LocalWellnessDataSource _localDataSource;
  final UserScopedFirestoreDataSource _remoteDataSource;
  final SyncEngine? _syncEngine;
  final DateTime Function() _now;

  WellnessRepositoryImpl(
    this._localDataSource,
    this._remoteDataSource, {
    SyncEngine? syncEngine,
    DateTime Function()? now,
  }) : _syncEngine = syncEngine,
       _now = now ?? DateTime.now;

  /// Durable, retried uploads through the shared [SyncEngine].
  late final RepositorySync _sync = RepositorySync(
    engine: _syncEngine,
    fallbackSet: (u, c, i, d) => _remoteDataSource.set(u, c, i, d),
    fallbackDelete: (u, c, i) => _remoteDataSource.delete(u, c, i),
  );

  @override
  Future<void> saveLog(String userId, WellnessLog log) async {
    // Generate predictable ID if not present
    final dateStr = log.date.toIso8601String().split('T').first;
    final id = log.id.isEmpty ? '${userId}_$dateStr' : log.id;

    final model = WellnessLogModel.fromEntity(
      log.copyWith(
        id: id,
        synced: kIsWeb, // Web is always synced immediately
      ),
    );

    if (!kIsWeb) {
      await _localDataSource.insertOrUpdateLog(model);
    }

    await _syncToRemote(userId, model);
  }

  Future<void> _syncToRemote(String userId, WellnessLogModel model) async {
    final queued = await _sync.set(
      userId,
      FirestoreCollections.wellness,
      model.id,
      model.toFirestoreMap(),
      updatedAt: _now(),
    );
    // Once the write sits in the durable outbox the engine owns retrying
    // it, so the local row no longer needs its own "unsynced" flag.
    if (queued && !kIsWeb) {
      try {
        await _localDataSource.markAsSynced(model.id);
      } catch (_) {}
    }
  }

  @override
  Future<WellnessLog?> getLogForDate(String userId, DateTime date) async {
    final dateStr = date.toIso8601String().split('T').first;
    final id = '${userId}_$dateStr';

    if (kIsWeb) {
      final doc = await _remoteDataSource.get(
        userId,
        FirestoreCollections.wellness,
        id,
      );
      final merged = await _sync.overlay(
        userId,
        FirestoreCollections.wellness,
        doc == null ? const [] : [doc],
      );
      final match = merged.where((d) => d['id'] == id).firstOrNull;
      if (match != null) {
        return WellnessLogModel.fromFirestoreMap(match, id);
      }
      return null;
    }

    // Try local
    final localLog = await _localDataSource.getLogForDate(userId, date);
    if (localLog != null) return localLog;

    // Fallback remote
    try {
      final doc = await _remoteDataSource.get(
        userId,
        FirestoreCollections.wellness,
        id,
      );
      if (doc != null) {
        final remoteModel = WellnessLogModel.fromFirestoreMap(doc, id);
        await _localDataSource.insertOrUpdateLog(remoteModel);
        return remoteModel;
      }
    } catch (_) {}

    return null;
  }

  @override
  Future<List<WellnessLog>> getLogsForMonth(
    String userId,
    int year,
    int month,
  ) async {
    if (kIsWeb) {
      final docs = await _sync.overlay(
        userId,
        FirestoreCollections.wellness,
        await _remoteDataSource.list(userId, FirestoreCollections.wellness),
      );
      var logs = docs
          .map(
            (doc) => WellnessLogModel.fromFirestoreMap(
              doc,
              doc['id'] ?? const Uuid().v4(),
            ),
          )
          .toList();
      logs = logs
          .where((l) => l.date.year == year && l.date.month == month)
          .toList();
      return logs;
    }

    return await _localDataSource.getLogsForMonth(userId, year, month);
  }

  @override
  Future<void> syncUnsyncedLogs(String userId) async {
    if (kIsWeb) return;

    final unsynced = await _localDataSource.getUnsyncedLogs(userId);
    for (final log in unsynced) {
      await _syncToRemote(userId, log);
    }
  }
}

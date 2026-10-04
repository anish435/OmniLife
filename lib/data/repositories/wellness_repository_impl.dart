import 'package:flutter/foundation.dart';
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

  WellnessRepositoryImpl(this._localDataSource, this._remoteDataSource);

  @override
  Future<void> saveLog(String userId, WellnessLog log) async {
    // Generate predictable ID if not present
    final dateStr = log.date.toIso8601String().split('T').first;
    final id = log.id.isEmpty ? "\${userId}_\$dateStr" : log.id;
    
    final model = WellnessLogModel.fromEntity(log.copyWith(
      id: id,
      synced: kIsWeb, // Web is always synced immediately
    ));

    if (!kIsWeb) {
      await _localDataSource.insertOrUpdateLog(model);
    }
    
    _syncToRemote(userId, model);
  }

  void _syncToRemote(String userId, WellnessLogModel model) {
    _remoteDataSource
        .set(userId, FirestoreCollections.wellness, model.id, model.toFirestoreMap())
        .then((_) {
      if (!kIsWeb) {
        _localDataSource.markAsSynced(model.id).catchError((_) {});
      }
    }).catchError((_) {});
  }

  @override
  Future<WellnessLog?> getLogForDate(String userId, DateTime date) async {
    final dateStr = date.toIso8601String().split('T').first;
    final id = "\${userId}_\$dateStr";

    if (kIsWeb) {
      final doc = await _remoteDataSource.get(userId, FirestoreCollections.wellness, id);
      if (doc != null) {
        return WellnessLogModel.fromFirestoreMap(doc, id);
      }
      return null;
    }

    // Try local
    final localLog = await _localDataSource.getLogForDate(userId, date);
    if (localLog != null) return localLog;

    // Fallback remote
    try {
      final doc = await _remoteDataSource.get(userId, FirestoreCollections.wellness, id);
      if (doc != null) {
        final remoteModel = WellnessLogModel.fromFirestoreMap(doc, id);
        await _localDataSource.insertOrUpdateLog(remoteModel);
        return remoteModel;
      }
    } catch (_) {}

    return null;
  }

  @override
  Future<List<WellnessLog>> getLogsForMonth(String userId, int year, int month) async {
    if (kIsWeb) {
      final docs = await _remoteDataSource.list(userId, FirestoreCollections.wellness);
      var logs = docs.map((doc) => WellnessLogModel.fromFirestoreMap(doc, doc['id'] ?? const Uuid().v4())).toList();
      logs = logs.where((l) => l.date.year == year && l.date.month == month).toList();
      return logs;
    }

    return await _localDataSource.getLogsForMonth(userId, year, month);
  }

  @override
  Future<void> syncUnsyncedLogs(String userId) async {
    if (kIsWeb) return;
    
    final unsynced = await _localDataSource.getUnsyncedLogs(userId);
    for (final log in unsynced) {
      _syncToRemote(userId, log);
    }
  }
}

// The remote source is built lazily, hence the private-named copy.
// ignore_for_file: prefer_initializing_formals

import 'package:flutter/foundation.dart';

import '../../core/errors/failures.dart';
import '../../core/sync/sync_engine.dart';
import '../../core/sync/sync_operation.dart';
import '../../domain/entities/reminder.dart';
import '../../domain/repositories/reminder_repository.dart';
import '../datasources/local/local_reminder_data_source.dart';
import '../datasources/remote/reminder_remote_data_source.dart';
import '../models/reminder_model.dart';

/// Local-first [ReminderRepository].
///
/// Mobile: SQLite is the source of truth and every write is queued to
/// Firestore (`users/{uid}/reminders/{id}`) through the durable [SyncEngine],
/// so a reminder made offline is uploaded once the device is online. Web:
/// no SQLite, so reads merge Firestore, the engine's not-yet-uploaded writes
/// and this session's writes.
class ReminderRepositoryImpl implements ReminderRepository {
  ReminderRepositoryImpl({
    required this.sync,
    this.local,
    ReminderRemoteDataSource? remote,
    bool? useLocalDb,
    DateTime Function()? now,
  }) : _remote = remote,
       _useLocalDb = useLocalDb ?? !kIsWeb,
       _now = now ?? DateTime.now;

  final SyncEngine sync;
  final LocalReminderDataSource? local;
  final ReminderRemoteDataSource? _remote;
  final bool _useLocalDb;
  final DateTime Function() _now;

  /// This session's writes; `null` marks a deletion.
  final Map<String, Reminder?> _session = {};

  LocalReminderDataSource get _db => local ?? LocalReminderDataSource();
  ReminderRemoteDataSource get _remoteSource =>
      _remote ?? FirestoreReminderRemoteDataSource();

  @override
  Future<Reminder> create(Reminder reminder) => _save(reminder);

  @override
  Future<Reminder> update(Reminder reminder) =>
      _save(reminder.copyWith(updatedAt: _now()));

  Future<Reminder> _save(Reminder reminder) async {
    try {
      final model = ReminderModel(reminder);
      _session[reminder.id] = reminder;
      if (_useLocalDb) await _db.upsert(model);
      await sync.enqueueSet(
        reminder.userId,
        remindersCollection,
        reminder.id,
        model.toFirestoreMap(),
        updatedAt: reminder.updatedAt,
      );
      return reminder;
    } catch (e) {
      throw DatabaseFailure('Could not save the reminder: $e');
    }
  }

  @override
  Future<void> delete(Reminder reminder) async {
    try {
      _session[reminder.id] = null;
      if (_useLocalDb) await _db.delete(reminder.id);
      await sync.enqueueDelete(
        reminder.userId,
        remindersCollection,
        reminder.id,
        at: _now(),
      );
    } catch (e) {
      throw DatabaseFailure('Could not delete the reminder: $e');
    }
  }

  @override
  Future<List<Reminder>> list(String userId) async {
    try {
      final items = _useLocalDb
          ? (await _db.list(userId)).map((m) => m.reminder).toList()
          : await _webList(userId);
      return items..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
    } catch (e) {
      throw DatabaseFailure('Could not load reminders: $e');
    }
  }

  Future<List<Reminder>> _webList(String userId) async {
    final merged = <String, Reminder>{};
    void offer(Reminder r) {
      final current = merged[r.id];
      if (current == null || !r.updatedAt.isBefore(current.updatedAt)) {
        merged[r.id] = r;
      }
    }

    try {
      (await _remoteSource.list(userId)).map((m) => m.reminder).forEach(offer);
    } catch (_) {
      // Offline: fall through to pending and session data.
    }
    for (final op in await sync.pendingFor(userId, remindersCollection)) {
      if (op.type == SyncOpType.set && op.data != null) {
        offer(ReminderModel.fromFirestoreMap(op.docId, op.data!).reminder);
      } else if (op.type == SyncOpType.delete) {
        merged.remove(op.docId);
      }
    }
    _session.forEach((id, r) {
      if (r == null) {
        merged.remove(id);
      } else if (r.userId == userId) {
        offer(r);
      }
    });
    return merged.values.toList();
  }

  /// Merges reminders saved from other devices into the local table. Skips
  /// anything with a queued local change so it is never overwritten.
  /// Returns true when something new arrived.
  Future<bool> refreshFromRemote(String userId) async {
    if (!_useLocalDb) return false;
    try {
      final remote = await _remoteSource.list(userId);
      final pending = {
        for (final op in await sync.pendingFor(userId, remindersCollection))
          op.docId,
      };
      var changed = false;
      for (final m in remote) {
        if (pending.contains(m.reminder.id)) continue;
        final existing = await _db.getById(m.reminder.id);
        if (existing == null ||
            m.reminder.updatedAt.isAfter(existing.reminder.updatedAt)) {
          await _db.upsert(m);
          changed = true;
        }
      }
      return changed;
    } catch (_) {
      return false; // Offline: local data stays authoritative.
    }
  }
}

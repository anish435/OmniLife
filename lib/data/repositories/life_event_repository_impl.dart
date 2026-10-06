import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../core/errors/failures.dart';
import '../../core/sync/sync_engine.dart';
import '../../core/sync/sync_operation.dart';
import '../../domain/entities/life_event.dart';
import '../../domain/repositories/life_event_repository.dart';
import '../datasources/local/local_life_event_data_source.dart';
import '../datasources/remote/life_event_remote_data_source.dart';
import '../models/life_event_model.dart';

/// Local-first [LifeEventRepository].
///
/// Mobile: SQLite is the source of truth; writes land locally in one step
/// and are queued to Firestore through the [SyncEngine] (durable, retried,
/// idempotent, last-writer-wins). Web: no SQLite, so reads merge Firestore,
/// the engine's not-yet-uploaded writes and this session's writes, again
/// resolving each event by `updatedAt`.
class LifeEventRepositoryImpl implements LifeEventRepository {
  LifeEventRepositoryImpl({
    required this.sync,
    this.local,
    LifeEventRemoteDataSource? remote,
    bool? useLocalDb,
    DateTime Function()? now,
    String Function()? newId,
  }) : _remote = remote ?? FirestoreLifeEventRemoteDataSource(),
       _useLocalDb = useLocalDb ?? !kIsWeb,
       _now = now ?? DateTime.now,
       _newId = newId ?? (() => const Uuid().v4());

  final SyncEngine sync;
  final LocalLifeEventDataSource? local;
  final LifeEventRemoteDataSource _remote;
  final bool _useLocalDb;
  final DateTime Function() _now;
  final String Function() _newId;

  final _changes = StreamController<void>.broadcast();
  final Map<String, LifeEventModel> _session = {};

  LocalLifeEventDataSource get _db => local ?? LocalLifeEventDataSource();

  @override
  Stream<void> get changes => _changes.stream;

  @override
  Future<LifeEvent> record(
    String uid,
    LifeEventType type, {
    DateTime? at,
    Map<String, dynamic> metadata = const {},
  }) async {
    final now = _now();
    final event = LifeEvent(
      id: _newId(),
      uid: uid,
      type: type,
      timestamp: at ?? now,
      createdAt: now,
      updatedAt: now,
      metadata: metadata,
    );
    await _write(LifeEventModel(event));
    return event;
  }

  @override
  Future<LifeEvent> update(LifeEvent event) async {
    final updated = event.copyWith(updatedAt: _now());
    await _write(LifeEventModel(updated));
    return updated;
  }

  @override
  Future<void> delete(LifeEvent event) async {
    final tombstone = event.copyWith(updatedAt: _now());
    await _write(LifeEventModel(tombstone, deleted: true));
  }

  Future<void> _write(LifeEventModel model) async {
    try {
      _session[model.event.id] = model;
      if (_useLocalDb) await _db.upsert(model);
      await sync.enqueueSet(
        model.event.uid,
        lifeEventsCollection,
        model.event.id,
        model.toFirestoreMap(),
        updatedAt: model.event.updatedAt,
      );
      if (!_changes.isClosed) _changes.add(null);
    } catch (e) {
      throw DatabaseFailure('Failed to save moment: $e');
    }
  }

  @override
  Future<List<LifeEvent>> range(String uid, DateTime from, DateTime to) async {
    try {
      if (_useLocalDb) {
        return (await _db.range(uid, from, to)).map((m) => m.event).toList();
      }
      return await _webRange(uid, from, to);
    } catch (e) {
      throw DatabaseFailure('Failed to load moments: $e');
    }
  }

  Future<List<LifeEvent>> _webRange(
    String uid,
    DateTime from,
    DateTime to,
  ) async {
    final merged = <String, LifeEventModel>{};
    void offer(LifeEventModel m) {
      final current = merged[m.event.id];
      if (current == null ||
          m.event.updatedAt.isAfter(current.event.updatedAt) ||
          m.event.updatedAt == current.event.updatedAt) {
        merged[m.event.id] = m;
      }
    }

    try {
      (await _remote.range(uid, from, to)).forEach(offer);
    } catch (_) {
      // Offline: fall through to pending + session data.
    }
    for (final op in await sync.pendingFor(uid, lifeEventsCollection)) {
      if (op.type == SyncOpType.set && op.data != null) {
        offer(LifeEventModel.fromFirestoreMap(op.docId, op.data!));
      }
    }
    _session.values.where((m) => m.event.uid == uid).forEach(offer);

    return merged.values
        .where(
          (m) =>
              !m.deleted &&
              !m.event.timestamp.isBefore(from) &&
              m.event.timestamp.isBefore(to),
        )
        .map((m) => m.event)
        .toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
  }

  @override
  Future<void> refreshFromRemote(String uid, {int days = 90}) async {
    if (!_useLocalDb) return;
    try {
      final now = _now();
      final remote = await _remote.range(
        uid,
        now.subtract(Duration(days: days)),
        now.add(const Duration(days: 2)),
      );
      var changed = false;
      for (final m in remote) {
        final local = await _db.getById(m.event.id);
        if (local == null || m.event.updatedAt.isAfter(local.event.updatedAt)) {
          await _db.upsert(m);
          changed = true;
        }
      }
      if (changed && !_changes.isClosed) _changes.add(null);
    } catch (_) {
      // Offline or permission problem: local data stays authoritative.
    }
  }
}

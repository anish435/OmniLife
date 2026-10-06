import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'connectivity_monitor.dart';
import 'remote_writer.dart';
import 'sync_operation.dart';
import 'sync_outbox.dart';

enum SyncStatus { synced, syncing, offline, pending, failed }

class SyncSnapshot {
  const SyncSnapshot({
    required this.status,
    this.pendingCount = 0,
    this.failedCount = 0,
  });

  final SyncStatus status;
  final int pendingCount;
  final int failedCount;

  @override
  bool operator ==(Object other) =>
      other is SyncSnapshot &&
      other.status == status &&
      other.pendingCount == pendingCount &&
      other.failedCount == failedCount;

  @override
  int get hashCode => Object.hash(status, pendingCount, failedCount);
}

/// Emitted when the server held a newer copy than a queued local change
/// and the local change was dropped (last-writer-wins).
class SyncConflict {
  const SyncConflict(this.collection, this.docId);
  final String collection;
  final String docId;
}

/// Durable outbox + retrying uploader for Firestore writes.
///
/// Repositories write to local storage first and then call
/// [enqueueSet]/[enqueueDelete]. The engine persists the intent, uploads
/// when online, retries with exponential backoff, coalesces repeated
/// writes to the same document, and resolves conflicts per document by
/// last-writer-wins on `updatedAt`. All writes are idempotent (fixed
/// document ids), so replays after a crash or retry are safe.
class SyncEngine {
  SyncEngine({
    required this.outbox,
    required this.remote,
    required this.connectivity,
    DateTime Function()? now,
    Random? random,
    this.maxAttempts = 8,
    this.baseBackoff = const Duration(seconds: 2),
    this.maxBackoff = const Duration(minutes: 5),
    this.pollInterval = const Duration(seconds: 30),
  }) : _now = now ?? DateTime.now,
       _random = random ?? Random();

  final SyncOutbox outbox;
  final RemoteWriter remote;
  final ConnectivityMonitor connectivity;
  final DateTime Function() _now;
  final Random _random;
  final int maxAttempts;
  final Duration baseBackoff;
  final Duration maxBackoff;
  final Duration pollInterval;

  final _snapshots = StreamController<SyncSnapshot>.broadcast();
  final _conflicts = StreamController<SyncConflict>.broadcast();
  StreamSubscription<bool>? _connectivitySub;
  Timer? _timer;
  Future<void>? _inFlight;
  bool _flushAgain = false;
  bool _online = true;
  SyncSnapshot _current = const SyncSnapshot(status: SyncStatus.synced);

  SyncSnapshot get current => _current;
  Stream<SyncSnapshot> get snapshots => _snapshots.stream;
  Stream<SyncConflict> get conflicts => _conflicts.stream;

  /// Begin listening for connectivity changes and poll for due retries.
  Future<void> start() async {
    _online = await connectivity.isOnline;
    _connectivitySub ??= connectivity.onChanged.listen((online) {
      _online = online;
      if (online) {
        unawaited(flush());
      } else {
        unawaited(_publish());
      }
    });
    _timer ??= Timer.periodic(pollInterval, (_) => unawaited(flush()));
    await _publish();
    unawaited(flush());
  }

  void dispose() {
    _timer?.cancel();
    _connectivitySub?.cancel();
    _snapshots.close();
    _conflicts.close();
  }

  Future<void> enqueueSet(
    String uid,
    String collection,
    String docId,
    Map<String, dynamic> data, {
    DateTime? updatedAt,
  }) async {
    final now = _now();
    await outbox.upsert(
      SyncOperation(
        uid: uid,
        collection: collection,
        docId: docId,
        type: SyncOpType.set,
        data: data,
        updatedAtMs: (updatedAt ?? now).millisecondsSinceEpoch,
        createdAtMs: now.millisecondsSinceEpoch,
      ),
    );
    await _publish();
    unawaited(flush());
  }

  Future<void> enqueueDelete(
    String uid,
    String collection,
    String docId, {
    DateTime? at,
  }) async {
    final now = _now();
    await outbox.upsert(
      SyncOperation(
        uid: uid,
        collection: collection,
        docId: docId,
        type: SyncOpType.delete,
        updatedAtMs: (at ?? now).millisecondsSinceEpoch,
        createdAtMs: now.millisecondsSinceEpoch,
      ),
    );
    await _publish();
    unawaited(flush());
  }

  /// Manually retry operations that exhausted their attempts.
  Future<void> retryFailed() async {
    for (final op in await outbox.all()) {
      if (op.state == SyncOpState.failed) {
        await outbox.upsert(
          op.copyWith(
            state: SyncOpState.pending,
            attempts: 0,
            nextAttemptAtMs: 0,
            clearError: true,
          ),
        );
      }
    }
    await flush();
  }

  /// Pending operations for one collection. Used on web, where reads come
  /// from Firestore, to overlay writes that have not uploaded yet.
  Future<List<SyncOperation>> pendingFor(String uid, String collection) async {
    return (await outbox.all())
        .where((o) => o.uid == uid && o.collection == collection)
        .toList();
  }

  /// Applies queued writes on top of [remote] documents so a reader sees
  /// its own not-yet-uploaded changes. Documents are maps containing `id`.
  Future<List<Map<String, dynamic>>> overlay(
    String uid,
    String collection,
    List<Map<String, dynamic>> remote,
  ) async {
    final byId = {for (final d in remote) d['id'] as String: d};
    for (final op in await pendingFor(uid, collection)) {
      if (op.type == SyncOpType.delete) {
        byId.remove(op.docId);
      } else {
        byId[op.docId] = {...?byId[op.docId], ...?op.data, 'id': op.docId};
      }
    }
    return byId.values.toList();
  }

  /// Exponential backoff with +/-20% jitter.
  Duration backoffFor(int attempts) {
    final exp = baseBackoff.inMilliseconds * pow(2, max(0, attempts - 1));
    final capped = min(exp.toDouble(), maxBackoff.inMilliseconds.toDouble());
    final jitter = 0.8 + _random.nextDouble() * 0.4;
    return Duration(milliseconds: (capped * jitter).round());
  }

  /// Uploads every due operation. Single-flight: concurrent callers share
  /// the running pass (plus one extra pass if new work arrived), and the
  /// returned future completes only when the queue has been processed.
  Future<void> flush() {
    final running = _inFlight;
    if (running != null) {
      _flushAgain = true;
      return running;
    }
    return _inFlight = _runFlush();
  }

  Future<void> _runFlush() async {
    try {
      do {
        _flushAgain = false;
        await _flushOnce();
      } while (_flushAgain);
    } finally {
      // Cleared in the same synchronous turn as the loop's final check, so
      // a flush() call can never slip in between and be lost.
      _inFlight = null;
    }
    await _publish();
  }

  Future<void> _flushOnce() async {
    _online = await connectivity.isOnline;
    if (!_online) return;
    final nowMs = _now().millisecondsSinceEpoch;
    final due = (await outbox.all())
        .where(
          (o) => o.state == SyncOpState.pending && o.nextAttemptAtMs <= nowMs,
        )
        .toList();
    if (due.isEmpty) return;
    await _publish(syncing: true);
    for (final op in due) {
      try {
        final result = await remote.apply(op);
        // Only drop the queued op if it was not replaced while uploading.
        final latest = await outbox.get(op.id);
        if (latest != null && _sameIntent(latest, op)) {
          await outbox.remove(op.id);
        }
        if (result == RemoteWriteResult.skippedRemoteNewer &&
            !_conflicts.isClosed) {
          _conflicts.add(SyncConflict(op.collection, op.docId));
        }
      } catch (e) {
        final attempts = op.attempts + 1;
        final failed = attempts >= maxAttempts;
        await outbox.upsert(
          op.copyWith(
            attempts: attempts,
            lastError: _describe(e),
            state: failed ? SyncOpState.failed : SyncOpState.pending,
            nextAttemptAtMs: _now()
                .add(backoffFor(attempts))
                .millisecondsSinceEpoch,
          ),
        );
        _online = await connectivity.isOnline;
        if (!_online) break;
      }
    }
  }

  /// True when [a] and [b] describe the same write (so [a] is safe to
  /// drop after [b] uploaded), even if both were enqueued in the same
  /// millisecond.
  bool _sameIntent(SyncOperation a, SyncOperation b) =>
      a.type == b.type &&
      a.updatedAtMs == b.updatedAtMs &&
      jsonEncode(a.data) == jsonEncode(b.data);

  String _describe(Object e) {
    final text = e.toString();
    return text.length > 200 ? text.substring(0, 200) : text;
  }

  Future<void> _publish({bool syncing = false}) async {
    final ops = await outbox.all();
    final failed = ops.where((o) => o.state == SyncOpState.failed).length;
    final pending = ops.length - failed;
    final SyncStatus status;
    if (syncing) {
      status = SyncStatus.syncing;
    } else if (ops.isEmpty) {
      status = SyncStatus.synced;
    } else if (failed > 0) {
      status = SyncStatus.failed;
    } else if (!_online) {
      status = SyncStatus.offline;
    } else {
      status = SyncStatus.pending;
    }
    final next = SyncSnapshot(
      status: status,
      pendingCount: pending,
      failedCount: failed,
    );
    if (next != _current) {
      _current = next;
      if (!_snapshots.isClosed) _snapshots.add(next);
    }
  }
}

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/services/sensors/step_aggregator.dart';
import '../../domain/entities/daily_steps.dart';
import '../../domain/repositories/steps_repository.dart';
import '../datasources/local/steps_local_store.dart';
import '../datasources/remote/user_doc_remote.dart';

/// Local-first [StepsRepository].
///
/// * [recordCounter] runs the reading through a [StepAggregator] whose
///   baseline is persisted, so reboot resets and app restarts are handled.
/// * Day/hour totals are stored locally and flagged dirty; [syncPending]
///   pushes each dirty day as a full snapshot with merge semantics to
///   `users/{uid}/sensor_daily/{yyyy-MM-dd}`, so retries are idempotent.
/// * Pushes are throttled ([syncInterval]) during live tracking to save
///   battery/network; failures simply leave the day dirty (offline buffer).
class StepsRepositoryImpl implements StepsRepository {
  StepsRepositoryImpl({
    StepsLocalStore? store,
    UserDocRemote? remote,
    String? Function()? userIdProvider,
    DateTime Function()? clock,
    this.syncInterval = const Duration(minutes: 2),
  }) : _store = store ?? (kIsWeb ? InMemoryStepsStore() : SqliteStepsStore()),
       _remote = remote ?? FirestoreUserDocRemote(),
       _userId = userIdProvider ?? (() => null),
       _now = clock ?? DateTime.now;

  static const collection = 'sensor_daily';
  static const _kCounter = 'last_counter';
  static const _kCounterAt = 'last_counter_at';
  static const _kGoal = 'daily_goal';
  static const _kTracking = 'tracking_enabled';

  final StepsLocalStore _store;
  final UserDocRemote _remote;
  final String? Function() _userId;
  final DateTime Function() _now;
  final Duration syncInterval;

  final _changes = StreamController<void>.broadcast();
  StepAggregator? _aggregator;
  String? _aggregatorUid;
  Future<void> _queue = Future.value();
  DateTime? _lastSyncAttempt;
  Future<int>? _syncFuture;

  Future<void> dispose() => _changes.close();

  // --- Reads -----------------------------------------------------------

  @override
  Future<int> todaySteps() async {
    final uid = _userId();
    if (uid == null) return 0;
    final key = DailySteps.dayKey(_now());
    final days = await _store.getDays(uid, key, key);
    return days.isEmpty ? 0 : days.first.steps;
  }

  @override
  Future<List<DailySteps>> last7Days() async {
    final today = _startOfDay(_now());
    final days = [
      for (var i = 6; i >= 0; i--)
        DateTime(today.year, today.month, today.day - i),
    ];
    final uid = _userId();
    final totals = <String, int>{};
    if (uid != null) {
      final rows = await _store.getDays(
        uid,
        DailySteps.dayKey(days.first),
        DailySteps.dayKey(days.last),
      );
      for (final r in rows) {
        totals[r.day] = r.steps;
      }
    }
    return [
      for (final d in days)
        DailySteps(date: d, steps: totals[DailySteps.dayKey(d)] ?? 0),
    ];
  }

  @override
  Stream<int> watchTodaySteps() => _watch(todaySteps);

  @override
  Stream<List<DailySteps>> watchLast7Days() => _watch(last7Days);

  /// Emits `read()` on listen and after every change. Built on a controller
  /// (not `async*`) so cancelling never waits on a pending event.
  Stream<T> _watch<T>(Future<T> Function() read) {
    StreamSubscription<void>? sub;
    late final StreamController<T> out;
    Future<void> emit() async {
      try {
        final v = await read();
        if (!out.isClosed && out.hasListener) out.add(v);
      } catch (e, st) {
        if (!out.isClosed) out.addError(e, st);
      }
    }

    out = StreamController<T>(
      onListen: () {
        unawaited(emit());
        sub = _changes.stream.listen((_) => unawaited(emit()));
      },
      onCancel: () async {
        await sub?.cancel();
        sub = null;
      },
    );
    return out.stream;
  }

  @override
  Future<Map<int, int>> hourlySteps(DateTime day) async {
    final uid = _userId();
    if (uid == null) return {};
    return _store.getHourly(uid, DailySteps.dayKey(day));
  }

  // --- Writes ----------------------------------------------------------

  @override
  Future<int> recordCounter(int counter, DateTime at) {
    // Serialize: readings must be applied in order against the baseline.
    final result = _queue.then((_) => _record(counter, at));
    _queue = result.then((_) {}, onError: (Object _) {});
    return result;
  }

  Future<int> _record(int counter, DateTime at) async {
    final uid = _userId();
    if (uid == null) return 0;

    if (_aggregator == null || _aggregatorUid != uid) {
      final c = await _store.getPref(uid, _kCounter);
      final t = await _store.getPref(uid, _kCounterAt);
      _aggregator = StepAggregator(
        lastCounter: c == null ? null : int.tryParse(c),
        lastReadingAt: t == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(int.tryParse(t) ?? 0),
      );
      _aggregatorUid = uid;
    }
    final agg = _aggregator!;
    final delta = agg.ingest(counter, at);

    // Persist baseline first-class: even a 0-step reading moves it.
    await _store.setPref(uid, _kCounter, '${agg.lastCounter}');
    await _store.setPref(
      uid,
      _kCounterAt,
      '${agg.lastReadingAt!.millisecondsSinceEpoch}',
    );

    if (delta == null || delta.steps <= 0) return 0;
    await _store.addSteps(
      uid,
      DailySteps.dayKey(delta.at),
      delta.at.hour,
      delta.steps,
    );
    if (!_changes.isClosed) _changes.add(null);
    _maybeSync();
    return delta.steps;
  }

  // --- Preferences -----------------------------------------------------

  @override
  Future<int?> dailyGoal() async {
    final uid = _userId();
    if (uid == null) return null;
    final v = await _store.getPref(uid, _kGoal);
    final n = v == null ? null : int.tryParse(v);
    return (n == null || n <= 0) ? null : n;
  }

  @override
  Future<void> setDailyGoal(int? goal) async {
    final uid = _userId();
    if (uid == null) return;
    await _store.setPref(
      uid,
      _kGoal,
      (goal == null || goal <= 0) ? null : '$goal',
    );
  }

  @override
  Future<bool> isTrackingEnabled() async {
    final uid = _userId();
    if (uid == null) return false;
    return (await _store.getPref(uid, _kTracking)) == '1';
  }

  @override
  Future<void> setTrackingEnabled(bool enabled) async {
    final uid = _userId();
    if (uid == null) return;
    await _store.setPref(uid, _kTracking, enabled ? '1' : '0');
  }

  // --- Sync ------------------------------------------------------------

  void _maybeSync() {
    final last = _lastSyncAttempt;
    if (last != null && _now().difference(last) < syncInterval) return;
    unawaited(syncPending());
  }

  @override
  Future<int> syncPending() async {
    // One push pass at a time; callers arriving meanwhile wait their turn
    // so "await syncPending()" always means "everything dirty is attempted".
    while (_syncFuture != null) {
      await _syncFuture;
    }
    final pass = _pushDirtyDays();
    _syncFuture = pass;
    try {
      return await pass;
    } finally {
      _syncFuture = null;
    }
  }

  Future<int> _pushDirtyDays() async {
    final uid = _userId();
    if (uid == null) return 0;
    _lastSyncAttempt = _now();
    var pushed = 0;
    for (final day in await _store.getDirtyDays(uid)) {
      try {
        final hourly = await _store.getHourly(uid, day.day);
        await _remote.set(uid, collection, day.day, {
          'date': day.day,
          'steps': day.steps,
          'hourly': {
            for (final e in hourly.entries)
              e.key.toString().padLeft(2, '0'): e.value,
          },
          'updatedAt': _now().millisecondsSinceEpoch,
        });
        await _store.markSynced(uid, day.day, day.steps);
        pushed++;
      } catch (_) {
        // Offline or rejected: stays dirty, retried on the next sync.
      }
    }
    return pushed;
  }

  @override
  Future<int> pullRemote() async {
    final uid = _userId();
    if (uid == null) return 0;
    var updated = 0;
    try {
      for (final doc in await _remote.list(uid, collection)) {
        try {
          final day = (doc['date'] ?? doc['id']) as String;
          DailySteps.parseKey(day); // validates the format
          final steps = (doc['steps'] as num).toInt();
          final hourlyRaw = (doc['hourly'] as Map?) ?? const {};
          final hourly = <int, int>{
            for (final e in hourlyRaw.entries)
              int.parse(e.key.toString()): (e.value as num).toInt(),
          };
          if (await _store.mergeRemote(uid, day, steps, hourly)) updated++;
        } catch (_) {
          // Skip malformed documents.
        }
      }
    } catch (_) {}
    if (updated > 0 && !_changes.isClosed) _changes.add(null);
    return updated;
  }

  static DateTime _startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);
}

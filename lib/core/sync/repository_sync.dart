// ignore_for_file: prefer_initializing_formals
import 'dart:async';

import 'package:get/get.dart';

import 'sync_engine.dart';

/// Direct (non-durable) write used only when no [SyncEngine] exists, for
/// example in tests or a build where sync was never registered.
typedef DirectSet = Future<void> Function(
  String uid,
  String collection,
  String docId,
  Map<String, dynamic> data,
);
typedef DirectDelete = Future<void> Function(
  String uid,
  String collection,
  String docId,
);

/// What a repository uses to push its writes to Firestore.
///
/// Normal path: the write is stored in the [SyncEngine] outbox, which is
/// durable, retried with backoff, idempotent (fixed document ids) and
/// visible in the sync indicator. When no engine is registered (or the
/// outbox itself fails) the write falls back to one best-effort direct
/// attempt so behaviour never gets worse than before.
///
/// The engine is looked up lazily, so repositories can be constructed
/// before the sync stack is registered.
class RepositorySync {
  RepositorySync({SyncEngine? engine, this.fallbackSet, this.fallbackDelete})
    : _engine = engine;

  final SyncEngine? _engine;
  final DirectSet? fallbackSet;
  final DirectDelete? fallbackDelete;

  /// The injected engine, else the registered one, else null.
  SyncEngine? get engine {
    final injected = _engine;
    if (injected != null) return injected;
    try {
      return Get.isRegistered<SyncEngine>() ? Get.find<SyncEngine>() : null;
    } catch (_) {
      return null;
    }
  }

  bool get isDurable => engine != null;

  /// Users who are not really signed in (empty id or the offline guest
  /// placeholder) have no Firestore folder to write to.
  static bool isSyncableUid(String uid) =>
      uid.isNotEmpty && uid != 'guest-user';

  /// Queues a set. Returns true when the write is now safely in the
  /// outbox; false when only the direct fallback was attempted.
  Future<bool> set(
    String uid,
    String collection,
    String docId,
    Map<String, dynamic> data, {
    DateTime? updatedAt,
  }) async {
    if (!isSyncableUid(uid)) return false;
    final e = engine;
    if (e != null) {
      try {
        await e.enqueueSet(uid, collection, docId, data, updatedAt: updatedAt);
        return true;
      } catch (_) {
        // fall through to the direct attempt
      }
    }
    final direct = fallbackSet;
    if (direct != null) {
      try {
        unawaited(
          direct(uid, collection, docId, data).catchError((Object _) {}),
        );
      } catch (_) {}
    }
    return false;
  }

  /// Queues a delete. Same return meaning as [set].
  Future<bool> delete(
    String uid,
    String collection,
    String docId, {
    DateTime? at,
  }) async {
    if (!isSyncableUid(uid)) return false;
    final e = engine;
    if (e != null) {
      try {
        await e.enqueueDelete(uid, collection, docId, at: at);
        return true;
      } catch (_) {}
    }
    final direct = fallbackDelete;
    if (direct != null) {
      try {
        unawaited(direct(uid, collection, docId).catchError((Object _) {}));
      } catch (_) {}
    }
    return false;
  }

  /// Web reads: layers queued, not-yet-uploaded writes over [remote]
  /// documents (maps containing `id`) so a person sees their own changes
  /// straight away and after a refresh.
  Future<List<Map<String, dynamic>>> overlay(
    String uid,
    String collection,
    List<Map<String, dynamic>> remote,
  ) async {
    final e = engine;
    if (e == null || !isSyncableUid(uid)) return remote;
    try {
      return await e.overlay(uid, collection, remote);
    } catch (_) {
      return remote;
    }
  }

  /// Document ids with a queued write, so a background pull from the
  /// server never overwrites a local change that has not uploaded yet.
  Future<Set<String>> pendingIds(String uid, String collection) async {
    final e = engine;
    if (e == null || !isSyncableUid(uid)) return const {};
    try {
      return {for (final op in await e.pendingFor(uid, collection)) op.docId};
    } catch (_) {
      return const {};
    }
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../data/datasources/remote/firestore_paths.dart';
import 'remote_writer.dart';
import 'sync_operation.dart';

/// Writes queued operations to `users/{uid}/{collection}/{docId}` inside a
/// transaction that implements last-writer-wins on the document's
/// `updatedAt` field. Transactions only succeed while online, which is
/// exactly what the engine wants: offline attempts fail fast and retry.
///
/// [applyBatch] puts many documents into one transaction (reads first, then
/// writes), so a burst of changes costs a few round trips instead of one
/// per document.
class FirestoreRemoteWriter extends RemoteWriter {
  FirestoreRemoteWriter({this.firestore});

  final FirebaseFirestore? firestore;

  FirebaseFirestore get _db => firestore ?? FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> _refFor(SyncOperation op) =>
      _db.doc('${userScopedCollectionPath(op.uid, op.collection)}/${op.docId}');

  /// Decides what to do with [op] given the current server copy and queues
  /// the write on [tx]. Must only run after all reads of the transaction.
  RemoteWriteResult _stage(
    Transaction tx,
    DocumentReference<Map<String, dynamic>> ref,
    DocumentSnapshot<Map<String, dynamic>> snap,
    SyncOperation op,
  ) {
    final remoteMs = snap.exists ? parseUpdatedAtMs(snap.data()) : null;
    if (remoteMs != null && remoteMs > op.updatedAtMs) {
      return RemoteWriteResult.skippedRemoteNewer;
    }
    if (op.type == SyncOpType.delete) {
      if (snap.exists) tx.delete(ref);
    } else {
      tx.set(ref, op.data ?? const {}, SetOptions(merge: true));
    }
    return RemoteWriteResult.applied;
  }

  @override
  Future<RemoteWriteResult> apply(SyncOperation op) {
    final ref = _refFor(op);
    return _db
        .runTransaction<RemoteWriteResult>((tx) async {
          final snap = await tx.get(ref);
          return _stage(tx, ref, snap, op);
        })
        .timeout(const Duration(seconds: 15));
  }

  @override
  Future<List<RemoteOpOutcome>> applyBatch(List<SyncOperation> ops) async {
    if (ops.length == 1) {
      return [RemoteOpOutcome.done(await apply(ops.single))];
    }
    final refs = ops.map(_refFor).toList();
    final results = await _db
        .runTransaction<List<RemoteWriteResult>>((tx) async {
          final snaps = await Future.wait(refs.map(tx.get));
          return [
            for (var i = 0; i < ops.length; i++)
              _stage(tx, refs[i], snaps[i], ops[i]),
          ];
        })
        .timeout(const Duration(seconds: 30));
    return [for (final r in results) RemoteOpOutcome.done(r)];
  }

  /// Accepts the formats the app writes: ISO-8601 strings, epoch millis
  /// and Firestore [Timestamp]s. Returns null when absent/unparseable.
  static int? parseUpdatedAtMs(Map<String, dynamic>? data) {
    final value = data?['updatedAt'];
    if (value is Timestamp) return value.millisecondsSinceEpoch;
    if (value is int) return value;
    if (value is String) {
      return DateTime.tryParse(value)?.millisecondsSinceEpoch;
    }
    return null;
  }
}

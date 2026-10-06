import 'package:cloud_firestore/cloud_firestore.dart';

import '../../data/datasources/remote/firestore_paths.dart';
import 'remote_writer.dart';
import 'sync_operation.dart';

/// Writes queued operations to `users/{uid}/{collection}/{docId}` inside a
/// transaction that implements last-writer-wins on the document's
/// `updatedAt` field. Transactions only succeed while online, which is
/// exactly what the engine wants: offline attempts fail fast and retry.
class FirestoreRemoteWriter implements RemoteWriter {
  FirestoreRemoteWriter({this.firestore});

  final FirebaseFirestore? firestore;

  FirebaseFirestore get _db => firestore ?? FirebaseFirestore.instance;

  @override
  Future<RemoteWriteResult> apply(SyncOperation op) {
    final ref = _db.doc(
      '${userScopedCollectionPath(op.uid, op.collection)}/${op.docId}',
    );
    return _db
        .runTransaction<RemoteWriteResult>((tx) async {
          final snap = await tx.get(ref);
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
        })
        .timeout(const Duration(seconds: 15));
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

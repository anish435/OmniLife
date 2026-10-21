import 'sync_operation.dart';

enum RemoteWriteResult {
  /// The server now reflects this operation.
  applied,

  /// The server copy was changed more recently than this local change, so
  /// the local change was dropped (last-writer-wins). Callers should
  /// refresh local state from the server.
  skippedRemoteNewer,
}

/// Outcome of one operation inside [RemoteWriter.applyBatch]: either a
/// [result] or the [error] that stopped it.
class RemoteOpOutcome {
  const RemoteOpOutcome.done(RemoteWriteResult this.result) : error = null;
  const RemoteOpOutcome.failed(Object this.error) : result = null;

  final RemoteWriteResult? result;
  final Object? error;

  bool get isFailure => error != null;
}

/// Applies queued operations to the remote store. Throws on any
/// transient failure (offline, permission, timeout) so the engine retries.
abstract class RemoteWriter {
  Future<RemoteWriteResult> apply(SyncOperation op);

  /// Applies several operations on different documents together. Returns
  /// one outcome per operation, in the same order. A writer that can group
  /// the work (one round trip for many documents) overrides this; if it
  /// throws, the engine falls back to [apply] one operation at a time so a
  /// single bad document cannot hold back the rest.
  Future<List<RemoteOpOutcome>> applyBatch(List<SyncOperation> ops) async {
    final out = <RemoteOpOutcome>[];
    for (final op in ops) {
      try {
        out.add(RemoteOpOutcome.done(await apply(op)));
      } catch (e) {
        out.add(RemoteOpOutcome.failed(e));
      }
    }
    return out;
  }
}

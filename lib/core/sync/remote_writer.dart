import 'sync_operation.dart';

enum RemoteWriteResult {
  /// The server now reflects this operation.
  applied,

  /// The server copy was changed more recently than this local change, so
  /// the local change was dropped (last-writer-wins). Callers should
  /// refresh local state from the server.
  skippedRemoteNewer,
}

/// Applies one queued operation to the remote store. Throws on any
/// transient failure (offline, permission, timeout) so the engine retries.
abstract class RemoteWriter {
  Future<RemoteWriteResult> apply(SyncOperation op);
}

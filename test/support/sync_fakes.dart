import 'package:omnilife/core/sync/connectivity_monitor.dart';
import 'package:omnilife/core/sync/remote_writer.dart';
import 'package:omnilife/core/sync/sync_engine.dart';
import 'package:omnilife/core/sync/sync_operation.dart';
import 'package:omnilife/core/sync/sync_outbox.dart';

/// Remote writer that records what the engine uploads.
class RecordingRemoteWriter implements RemoteWriter {
  final applied = <SyncOperation>[];

  @override
  Future<RemoteWriteResult> apply(SyncOperation op) async {
    applied.add(op);
    return RemoteWriteResult.applied;
  }
}

/// A real [SyncEngine] on an in-memory outbox. Offline by default, so
/// queued operations stay visible in [outbox] for assertions; set
/// [online] to true to let them upload to [remote].
class TestSync {
  TestSync({bool online = false})
    : connectivity = FakeConnectivityMonitor(online: online),
      outbox = MemorySyncOutbox(),
      remote = RecordingRemoteWriter() {
    engine = SyncEngine(
      outbox: outbox,
      remote: remote,
      connectivity: connectivity,
    );
  }

  final FakeConnectivityMonitor connectivity;
  final MemorySyncOutbox outbox;
  final RecordingRemoteWriter remote;
  late final SyncEngine engine;

  Future<List<SyncOperation>> ops(String collection) async =>
      (await outbox.all()).where((o) => o.collection == collection).toList();

  Future<SyncOperation?> op(String collection, String docId) =>
      outbox.get('$collection/$docId');

  void dispose() => engine.dispose();
}

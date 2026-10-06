import 'package:flutter/foundation.dart' show kIsWeb;

import '../../data/datasources/local/app_database.dart';
import 'connectivity_monitor.dart';
import 'firestore_remote_writer.dart';
import 'key_value_store.dart';
import 'key_value_sync_outbox.dart';
import 'sqlite_sync_outbox.dart';
import 'sync_engine.dart';
import 'sync_outbox.dart';

/// Builds the production [SyncEngine]: a durable outbox appropriate to the
/// platform (SQLite on mobile, localStorage on web), Firestore uploads with
/// last-writer-wins, and real connectivity detection.
SyncEngine createSyncEngine({String? Function()? currentUid}) {
  final SyncOutbox outbox = kIsWeb
      ? KeyValueSyncOutbox(createPlatformKeyValueStore())
      : SqliteSyncOutbox(() => AppDatabase.instance.database);
  return SyncEngine(
    outbox: outbox,
    remote: FirestoreRemoteWriter(),
    connectivity: ConnectivityPlusMonitor(),
    currentUid: currentUid,
  );
}

import 'dart:async';

import 'package:get/get.dart';

import '../../core/sync/sync_engine.dart';

/// Exposes the sync engine's state to the UI. Holds no logic of its own.
class SyncController extends GetxController {
  SyncController(this.engine);

  final SyncEngine engine;
  final snapshot = const SyncSnapshot(status: SyncStatus.synced).obs;
  StreamSubscription<SyncSnapshot>? _sub;

  @override
  void onInit() {
    super.onInit();
    snapshot.value = engine.current;
    _sub = engine.snapshots.listen((s) => snapshot.value = s);
  }

  Future<void> retry() => engine.retryFailed();

  @override
  void onClose() {
    _sub?.cancel();
    super.onClose();
  }
}

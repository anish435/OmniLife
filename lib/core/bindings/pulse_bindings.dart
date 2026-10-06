import 'dart:async';

import 'package:get/get.dart';

import '../../data/repositories/life_event_repository_impl.dart';
import '../../domain/repositories/habit_repository.dart';
import '../../domain/repositories/life_event_repository.dart';
import '../../domain/repositories/task_repository.dart';
import '../../domain/usecases/pulse/pulse_insights_service.dart';
import '../../domain/usecases/pulse/pulse_service.dart';
import '../../presentation/controllers/auth_controller.dart';
import '../../presentation/controllers/pulse_controller.dart';
import '../../presentation/controllers/sync_controller.dart';
import '../sync/sync_engine.dart';
import '../sync/sync_providers.dart';

/// Registers the offline sync engine and the OmniPulse stack. Idempotent,
/// and creates nothing that touches Firebase until first use.
void registerSyncAndPulse() {
  if (!Get.isRegistered<SyncEngine>()) {
    final engine = createSyncEngine(
      currentUid: () => Get.isRegistered<AuthController>()
          ? Get.find<AuthController>().currentUser.value?.uid
          : null,
    );
    Get.put<SyncEngine>(engine, permanent: true);
    Get.put<SyncController>(SyncController(engine), permanent: true);
  }

  if (!Get.isRegistered<LifeEventRepository>()) {
    Get.lazyPut<LifeEventRepository>(
      () => LifeEventRepositoryImpl(sync: Get.find<SyncEngine>()),
      fenix: true,
    );
  }
  if (!Get.isRegistered<PulseService>()) {
    Get.lazyPut<PulseService>(
      () => PulseService(events: Get.find<LifeEventRepository>()),
      fenix: true,
    );
  }
  if (!Get.isRegistered<PulseInsightsService>()) {
    Get.lazyPut<PulseInsightsService>(
      () => PulseInsightsService(
        events: Get.find<LifeEventRepository>(),
        tasks: Get.find<TaskRepository>(),
        habits: Get.find<HabitRepository>(),
      ),
      fenix: true,
    );
  }
  if (!Get.isRegistered<PulseController>()) {
    Get.put<PulseController>(PulseController(), permanent: true);
  }
}

/// Starts background upload/retry. Called once from `main()`; widget tests
/// never call it, so they stay free of timers and platform plugins.
void startSyncEngine() {
  if (Get.isRegistered<SyncEngine>()) {
    unawaited(Get.find<SyncEngine>().start());
  }
}

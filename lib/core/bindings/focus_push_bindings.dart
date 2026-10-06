import 'dart:async';

import 'package:get/get.dart';

import '../../core/services/ambient_audio_player.dart';
import '../../core/services/focus_video_player.dart';
import '../../core/services/notification_routing.dart';
import '../../core/services/notification_service.dart';
import '../../core/services/push_messaging_service.dart';
import '../../core/services/push_registration_manager.dart';
import '../../core/services/user_session_coordinator.dart';
import '../../data/focus/shared_prefs_focus_state_store.dart';
import '../../data/repositories/focus_repository_impl.dart';
import '../../domain/repositories/focus_repository.dart';
import '../../presentation/controllers/focus_controller.dart';
import '../../presentation/controllers/push_controller.dart';

/// Registers focus mode and push messaging. Called once from
/// [InitialBinding]; safe to call again (existing registrations are kept).
void registerFocusAndPushDependencies() {
  registerFocusDependencies();
  registerPushDependencies();
}

void registerFocusDependencies() {
  if (!Get.isRegistered<FocusRepository>()) {
    Get.lazyPut<FocusRepository>(() => FocusRepositoryImpl(), fenix: true);
  }
  if (!Get.isRegistered<FocusController>()) {
    Get.put(
      FocusController(
        repository: Get.find<FocusRepository>(),
        stateStore: SharedPrefsFocusStateStore(),
        audio: JustAudioAmbientPlayer(),
        video: VideoPlayerFocusVideo(),
      ),
      permanent: true,
    );
  }
}

void registerPushDependencies() {
  if (Get.isRegistered<PushController>()) return;

  final notifications = Get.isRegistered<NotificationService>()
      ? Get.find<NotificationService>()
      : null;

  final manager = PushRegistrationManager(
    messaging: FirebasePushMessagingService(),
    store: FirestoreDeviceTokenStore(),
    preferences: SharedPushPreferences(),
    onForeground: (message) {
      final target = NotificationRouting.fromData(message.data);
      notifications?.showRemoteMessage(
        title: message.title ?? 'OmniLife',
        body: message.body ?? '',
        payload: target == null
            ? null
            : NotificationRouting.encode(target.kind ?? '', target.id),
      );
    },
    onOpened: (message) => NotificationNavigator.instance.handle(
      NotificationRouting.fromData(message.data),
    ),
  );

  UserSessionCoordinator.instance.push = manager;
  Get.put(
    PushController(manager: manager, notifications: notifications),
    permanent: true,
  );
  unawaited(manager.start().catchError((Object _) {}));
}

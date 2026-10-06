import 'package:get/get.dart';

import '../../core/services/notification_service.dart';
import '../../core/services/push_messaging_service.dart';
import '../../core/services/push_registration_manager.dart';
import 'auth_controller.dart';

/// State for the push notification settings (opt-in switch and topics).
///
/// Action methods return the confirmation text for the UI to show, so the
/// controller stays free of widget context.
class PushController extends GetxController {
  PushController({required this._manager, this._auth, this._notifications});

  final PushRegistrationManager _manager;
  final AuthController? _auth;
  final NotificationService? _notifications;

  final supported = false.obs;
  final enabled = false.obs;
  final busy = false.obs;
  final permission = PushPermission.notDetermined.obs;
  final topics = <String>{}.obs;

  String? get _uid {
    try {
      return (_auth ?? Get.find<AuthController>()).currentUser.value?.uid;
    } catch (_) {
      return null;
    }
  }

  @override
  void onInit() {
    super.onInit();
    refreshState();
  }

  Future<void> refreshState() async {
    supported.value = await _manager.isSupportedHere();
    enabled.value = await _manager.isEnabled();
    topics.assignAll(await _manager.subscribedTopics());
  }

  /// Turns push notifications on or off. This is the only entry point that
  /// can show the OS permission prompt.
  Future<String> setEnabled(bool value) async {
    final uid = _uid;
    if (uid == null) return 'Sign in to manage notifications.';
    busy.value = true;
    try {
      if (!value) {
        await _manager.disable(uid);
        enabled.value = false;
        return 'Push notifications turned off.';
      }
      // Local reminders need the OS permission too (iOS, Android 13+).
      await _notifications?.requestLocalPermission();
      final result = await _manager.enable(uid);
      permission.value = result;
      enabled.value = result == PushPermission.granted;
      switch (result) {
        case PushPermission.granted:
          return 'Push notifications turned on.';
        case PushPermission.permanentlyDenied:
          return 'Notifications are blocked. Enable them for OmniLife in '
              'your device settings.';
        case PushPermission.denied:
          return 'Permission was not granted. You can try again any time.';
        case PushPermission.notDetermined:
          return 'Push notifications are not available on this device.';
      }
    } finally {
      busy.value = false;
    }
  }

  Future<String> setTopic(String topic, bool subscribed) async {
    await _manager.setTopic(topic, subscribed: subscribed);
    if (subscribed) {
      topics.add(topic);
    } else {
      topics.remove(topic);
    }
    return subscribed ? 'Subscribed to $topic.' : 'Unsubscribed from $topic.';
  }
}

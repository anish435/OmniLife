import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../firebase_options.dart';
import 'notification_routing.dart';
import 'notification_service.dart';

/// Top-level FCM background handler (runs in its own isolate).
///
/// Messages that carry a `notification` block are displayed by the OS. Only
/// data-only messages are turned into a local notification here, with a
/// `kind:id` payload so a tap routes like any other notification.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
    if (message.notification != null) return;

    final title = message.data['title']?.toString();
    final body = message.data['body']?.toString();
    if (title == null && body == null) return;

    final plugin = FlutterLocalNotificationsPlugin();
    await plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );
    final target = NotificationRouting.fromData(message.data);
    await plugin.show(
      id: message.hashCode & 0x7FFFFFFF,
      title: title,
      body: body,
      notificationDetails: buildReminderDetails(withActions: false),
      payload: target == null
          ? null
          : NotificationRouting.encode(target.kind ?? '', target.id),
    );
  } catch (_) {
    // A failing background handler must never crash the process.
  }
}

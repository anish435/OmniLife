import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../config/telemetry_config.dart';

/// OS-level notification permission as the push layer understands it.
enum PushPermission {
  /// Not asked yet, or the platform cannot tell.
  notDetermined,
  granted,

  /// Denied, but the user may still be prompted again.
  denied,

  /// Denied and the OS will not show the prompt again; the user has to
  /// enable notifications in system settings.
  permanentlyDenied,
}

/// A push message reduced to what the app needs, independent of the SDK.
@immutable
class PushMessage {
  const PushMessage({this.title, this.body, this.data = const {}});

  final String? title;
  final String? body;
  final Map<String, dynamic> data;
}

/// Everything the app needs from Firebase Cloud Messaging, behind an
/// interface so tests use a fake and an unsupported platform never throws.
abstract class PushMessagingService {
  /// False when messaging cannot work here (web without a VAPID key,
  /// unsupported browser, Firebase not initialized, desktop).
  Future<bool> get isSupported;

  /// `android`, `ios` or `web`; stored with the device token.
  String get platform;

  Future<PushPermission> permissionStatus();

  /// Shows the OS permission prompt. Call only from a user action.
  Future<PushPermission> requestPermission();

  Future<String?> getToken();
  Stream<String> get onTokenRefresh;
  Future<void> deleteToken();

  Stream<PushMessage> get onForegroundMessage;
  Stream<PushMessage> get onMessageOpenedApp;

  /// The message that launched the app from a terminated state, if any.
  Future<PushMessage?> getInitialMessage();

  Future<void> subscribeToTopic(String topic);
  Future<void> unsubscribeFromTopic(String topic);
}

abstract final class PushTopics {
  static const announcements = 'announcements';
  static const tips = 'tips';
  static const all = [announcements, tips];
}

/// [PushMessagingService] backed by `firebase_messaging`.
///
/// On web it stays inert unless `--dart-define=FCM_VAPID_KEY=...` is given.
class FirebasePushMessagingService implements PushMessagingService {
  FirebasePushMessagingService({this._vapidKey = kFcmVapidKey});

  final String _vapidKey;
  bool? _supported;

  FirebaseMessaging? get _messaging {
    try {
      if (Firebase.apps.isEmpty) return null;
      return FirebaseMessaging.instance;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<bool> get isSupported async {
    final cached = _supported;
    if (cached != null) return cached;
    var ok = false;
    try {
      final messaging = _messaging;
      if (messaging != null) {
        if (kIsWeb) {
          ok = _vapidKey.isNotEmpty && await messaging.isSupported();
        } else {
          ok =
              defaultTargetPlatform == TargetPlatform.android ||
              defaultTargetPlatform == TargetPlatform.iOS;
        }
      }
    } catch (_) {
      ok = false;
    }
    return _supported = ok;
  }

  @override
  String get platform => kIsWeb ? 'web' : defaultTargetPlatform.name;

  PushPermission _map(AuthorizationStatus status) {
    switch (status) {
      case AuthorizationStatus.authorized:
      case AuthorizationStatus.provisional:
        return PushPermission.granted;
      case AuthorizationStatus.deniedPermanently:
        return PushPermission.permanentlyDenied;
      case AuthorizationStatus.denied:
        return PushPermission.denied;
      case AuthorizationStatus.notDetermined:
        return PushPermission.notDetermined;
    }
  }

  @override
  Future<PushPermission> permissionStatus() async {
    try {
      if (!await isSupported) return PushPermission.notDetermined;
      final settings = await _messaging!.getNotificationSettings();
      return _map(settings.authorizationStatus);
    } catch (_) {
      return PushPermission.notDetermined;
    }
  }

  @override
  Future<PushPermission> requestPermission() async {
    try {
      if (!await isSupported) return PushPermission.notDetermined;
      final settings = await _messaging!.requestPermission();
      return _map(settings.authorizationStatus);
    } catch (_) {
      return PushPermission.denied;
    }
  }

  @override
  Future<String?> getToken() async {
    try {
      if (!await isSupported) return null;
      return await _messaging!.getToken(vapidKey: kIsWeb ? _vapidKey : null);
    } catch (_) {
      return null;
    }
  }

  @override
  Stream<String> get onTokenRefresh {
    final messaging = _messaging;
    if (messaging == null) return const Stream.empty();
    return messaging.onTokenRefresh.handleError((_) {});
  }

  @override
  Future<void> deleteToken() async {
    try {
      if (await isSupported) await _messaging!.deleteToken();
    } catch (_) {}
  }

  static PushMessage _convert(RemoteMessage m) => PushMessage(
    title: m.notification?.title ?? m.data['title']?.toString(),
    body: m.notification?.body ?? m.data['body']?.toString(),
    data: Map<String, dynamic>.from(m.data),
  );

  @override
  Stream<PushMessage> get onForegroundMessage =>
      FirebaseMessagingStreams.onMessage(_messaging).map(_convert);

  @override
  Stream<PushMessage> get onMessageOpenedApp =>
      FirebaseMessagingStreams.onOpened(_messaging).map(_convert);

  @override
  Future<PushMessage?> getInitialMessage() async {
    try {
      if (!await isSupported) return null;
      final message = await _messaging!.getInitialMessage();
      return message == null ? null : _convert(message);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> subscribeToTopic(String topic) async {
    // Topic APIs are not available in the browser SDK.
    if (kIsWeb) return;
    try {
      if (await isSupported) await _messaging!.subscribeToTopic(topic);
    } catch (_) {}
  }

  @override
  Future<void> unsubscribeFromTopic(String topic) async {
    if (kIsWeb) return;
    try {
      if (await isSupported) await _messaging!.unsubscribeFromTopic(topic);
    } catch (_) {}
  }
}

/// Static streams of the SDK are only touched when Firebase is initialized.
abstract final class FirebaseMessagingStreams {
  static Stream<RemoteMessage> onMessage(FirebaseMessaging? messaging) {
    if (messaging == null) return const Stream.empty();
    return FirebaseMessaging.onMessage;
  }

  static Stream<RemoteMessage> onOpened(FirebaseMessaging? messaging) {
    if (messaging == null) return const Stream.empty();
    return FirebaseMessaging.onMessageOpenedApp;
  }
}

/// Used when messaging is not wired up at all (tests, unsupported setups).
class UnsupportedPushMessagingService implements PushMessagingService {
  const UnsupportedPushMessagingService();

  @override
  Future<bool> get isSupported async => false;
  @override
  String get platform => 'unsupported';
  @override
  Future<PushPermission> permissionStatus() async =>
      PushPermission.notDetermined;
  @override
  Future<PushPermission> requestPermission() async =>
      PushPermission.notDetermined;
  @override
  Future<String?> getToken() async => null;
  @override
  Stream<String> get onTokenRefresh => const Stream.empty();
  @override
  Future<void> deleteToken() async {}
  @override
  Stream<PushMessage> get onForegroundMessage => const Stream.empty();
  @override
  Stream<PushMessage> get onMessageOpenedApp => const Stream.empty();
  @override
  Future<PushMessage?> getInitialMessage() async => null;
  @override
  Future<void> subscribeToTopic(String topic) async {}
  @override
  Future<void> unsubscribeFromTopic(String topic) async {}
}

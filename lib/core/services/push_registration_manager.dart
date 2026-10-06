import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/datasources/remote/firestore_paths.dart';
import '../../data/datasources/remote/user_scoped_firestore_datasource.dart';
import 'push_messaging_service.dart';

/// Where device tokens are stored: `users/{uid}/devices/{tokenHash}`.
abstract class DeviceTokenStore {
  Future<void> save(String uid, String docId, Map<String, Object?> data);
  Future<void> remove(String uid, String docId);
}

class FirestoreDeviceTokenStore implements DeviceTokenStore {
  FirestoreDeviceTokenStore({UserScopedFirestoreDataSource? dataSource})
    : _dataSource = dataSource ?? UserScopedFirestoreDataSource();

  final UserScopedFirestoreDataSource _dataSource;

  @override
  Future<void> save(String uid, String docId, Map<String, Object?> data) =>
      _dataSource.set(
        uid,
        FirestoreCollections.devices,
        docId,
        Map<String, dynamic>.from(data),
      );

  @override
  Future<void> remove(String uid, String docId) =>
      _dataSource.delete(uid, FirestoreCollections.devices, docId);
}

/// Small persisted settings for push notifications.
abstract class PushPreferences {
  Future<bool> getEnabled();
  Future<void> setEnabled(bool value);
  Future<int> getDeniedCount();
  Future<void> setDeniedCount(int value);
  Future<Set<String>> getTopics();
  Future<void> setTopics(Set<String> topics);
}

class SharedPushPreferences implements PushPreferences {
  static const _enabledKey = 'push_enabled';
  static const _deniedKey = 'push_denied_count';
  static const _topicsKey = 'push_topics';

  @override
  Future<bool> getEnabled() async =>
      (await SharedPreferences.getInstance()).getBool(_enabledKey) ?? false;

  @override
  Future<void> setEnabled(bool value) async =>
      (await SharedPreferences.getInstance()).setBool(_enabledKey, value);

  @override
  Future<int> getDeniedCount() async =>
      (await SharedPreferences.getInstance()).getInt(_deniedKey) ?? 0;

  @override
  Future<void> setDeniedCount(int value) async =>
      (await SharedPreferences.getInstance()).setInt(_deniedKey, value);

  @override
  Future<Set<String>> getTopics() async =>
      ((await SharedPreferences.getInstance()).getStringList(_topicsKey) ??
              const <String>[])
          .toSet();

  @override
  Future<void> setTopics(Set<String> topics) async =>
      (await SharedPreferences.getInstance()).setStringList(
        _topicsKey,
        topics.toList(),
      );
}

class InMemoryPushPreferences implements PushPreferences {
  bool enabled = false;
  int denied = 0;
  Set<String> topics = {};

  @override
  Future<bool> getEnabled() async => enabled;
  @override
  Future<void> setEnabled(bool value) async => enabled = value;
  @override
  Future<int> getDeniedCount() async => denied;
  @override
  Future<void> setDeniedCount(int value) async => denied = value;
  @override
  Future<Set<String>> getTopics() async => {...topics};
  @override
  Future<void> setTopics(Set<String> value) async => topics = {...value};
}

/// Owns the device-token lifecycle: permission, registration after login,
/// refresh, removal on logout, and topic subscriptions. Pure Dart over
/// interfaces, so it is tested with fakes.
class PushRegistrationManager {
  PushRegistrationManager({
    required this._messaging,
    required this._store,
    required PushPreferences preferences,
    this.onForeground,
    this.onOpened,
    DateTime Function()? clock,
  }) : _prefs = preferences,
       _clock = clock ?? DateTime.now;

  final PushMessagingService _messaging;
  final DeviceTokenStore _store;
  final PushPreferences _prefs;
  final DateTime Function() _clock;

  /// A push arrived while the app is open.
  final void Function(PushMessage message)? onForeground;

  /// The user tapped a push (from background or a cold start).
  final void Function(PushMessage message)? onOpened;

  String? _uid;
  String? _token;
  final _subs = <StreamSubscription<PushMessage>>[];
  StreamSubscription<String>? _refreshSub;
  bool _started = false;

  String? get currentToken => _token;

  /// Stable document id for a token: its SHA-256 hex digest.
  static String docIdForToken(String token) =>
      sha256.convert(utf8.encode(token)).toString();

  /// Hooks message streams. Never prompts for permission.
  Future<void> start() async {
    if (_started) return;
    _started = true;
    if (!await _messaging.isSupported) return;
    _subs.add(
      _messaging.onForegroundMessage.listen((m) => onForeground?.call(m)),
    );
    _subs.add(_messaging.onMessageOpenedApp.listen((m) => onOpened?.call(m)));
    final initial = await _messaging.getInitialMessage();
    if (initial != null) onOpened?.call(initial);
  }

  Future<void> dispose() async {
    for (final s in _subs) {
      await s.cancel();
    }
    _subs.clear();
    await _refreshSub?.cancel();
    _refreshSub = null;
    _started = false;
  }

  Future<bool> isSupportedHere() => _messaging.isSupported;

  Future<bool> isEnabled() async =>
      await _prefs.getEnabled() &&
      await _messaging.permissionStatus() == PushPermission.granted;

  /// The user turned notifications on. This is the only place the OS prompt
  /// is shown.
  Future<PushPermission> enable(String uid) async {
    if (!await _messaging.isSupported) return PushPermission.notDetermined;

    var status = await _messaging.permissionStatus();
    if (status != PushPermission.granted) {
      status = await _messaging.requestPermission();
    }
    if (status == PushPermission.permanentlyDenied) return status;
    if (status != PushPermission.granted) {
      final denied = (await _prefs.getDeniedCount()) + 1;
      await _prefs.setDeniedCount(denied);
      await _prefs.setEnabled(false);
      // iOS never re-prompts after one denial; Android 13+ stops after two.
      final limit = _messaging.platform == 'ios' ? 1 : 2;
      return denied >= limit
          ? PushPermission.permanentlyDenied
          : PushPermission.denied;
    }

    await _prefs.setDeniedCount(0);
    await _prefs.setEnabled(true);
    await _register(uid);
    for (final topic in await _prefs.getTopics()) {
      await _messaging.subscribeToTopic(topic);
    }
    return PushPermission.granted;
  }

  /// The user turned notifications off.
  Future<void> disable(String uid) async {
    await _prefs.setEnabled(false);
    await _unregister(uid);
    for (final topic in await _prefs.getTopics()) {
      await _messaging.unsubscribeFromTopic(topic);
    }
    await _messaging.deleteToken();
    _token = null;
  }

  /// After login: register silently if the user already opted in.
  Future<void> onSignedIn(String uid) async {
    _uid = uid;
    if (!await _messaging.isSupported) return;
    if (!await isEnabled()) return;
    await _register(uid);
  }

  /// Before sign-out, while the user can still write their own documents.
  Future<void> onBeforeSignOut(String uid) async {
    await _unregister(uid);
    for (final topic in await _prefs.getTopics()) {
      await _messaging.unsubscribeFromTopic(topic);
    }
    if (_token != null) await _messaging.deleteToken();
    _token = null;
    _uid = null;
    await _refreshSub?.cancel();
    _refreshSub = null;
  }

  Future<void> setTopic(String topic, {required bool subscribed}) async {
    final topics = await _prefs.getTopics();
    if (subscribed) {
      topics.add(topic);
      await _messaging.subscribeToTopic(topic);
    } else {
      topics.remove(topic);
      await _messaging.unsubscribeFromTopic(topic);
    }
    await _prefs.setTopics(topics);
  }

  Future<Set<String>> subscribedTopics() => _prefs.getTopics();

  Future<void> _register(String uid) async {
    _uid = uid;
    final token = await _messaging.getToken();
    if (token == null) return;
    await _save(uid, token);
    _refreshSub ??= _messaging.onTokenRefresh.listen(_onTokenRefreshed);
  }

  Future<void> _onTokenRefreshed(String fresh) async {
    final owner = _uid;
    if (owner == null) return;
    final old = _token;
    if (old != null && old != fresh) {
      await _safe(() => _store.remove(owner, docIdForToken(old)));
    }
    await _save(owner, fresh);
  }

  Future<void> _save(String uid, String token) async {
    _token = token;
    await _safe(
      () => _store.save(uid, docIdForToken(token), {
        'token': token,
        'platform': _messaging.platform,
        'updatedAt': _clock().toUtc(),
      }),
    );
  }

  Future<void> _unregister(String uid) async {
    final token = _token ?? await _messaging.getToken();
    if (token == null) return;
    await _safe(() => _store.remove(uid, docIdForToken(token)));
  }

  Future<void> _safe(Future<void> Function() action) async {
    try {
      await action();
    } catch (_) {
      // Offline or rules failure: registration is retried on next login.
    }
  }
}

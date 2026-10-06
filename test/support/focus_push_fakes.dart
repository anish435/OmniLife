import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:omnilife/core/services/ambient_audio_player.dart';
import 'package:omnilife/core/services/focus_video_player.dart';
import 'package:omnilife/core/services/push_messaging_service.dart';
import 'package:omnilife/core/services/push_registration_manager.dart';
import 'package:omnilife/domain/entities/focus_session.dart';
import 'package:omnilife/domain/focus/focus_event_sink.dart';
import 'package:omnilife/domain/repositories/focus_repository.dart';

/// Mutable clock for deterministic timer tests.
class FakeClock {
  FakeClock(this.now);
  DateTime now;

  DateTime call() => now;
  void advance(Duration d) => now = now.add(d);
}

class FakeAmbientAudio implements AmbientAudioPlayer {
  final _state = ValueNotifier(const AmbientAudioState());
  int chimes = 0;

  @override
  ValueListenable<AmbientAudioState> get state => _state;

  @override
  Future<void> select(AmbientSound sound) async {
    _state.value = _state.value.copyWith(
      sound: sound,
      isPlaying: sound != AmbientSound.off,
    );
  }

  @override
  Future<void> play() async =>
      _state.value = _state.value.copyWith(isPlaying: true);

  @override
  Future<void> pause() async =>
      _state.value = _state.value.copyWith(isPlaying: false);

  @override
  Future<void> setVolume(double volume) async =>
      _state.value = _state.value.copyWith(volume: volume);

  @override
  Future<void> playChime() async => chimes++;

  @override
  Future<void> dispose() async {}
}

class FakeVideo implements FocusVideoPlayer {
  final _state = ValueNotifier(const FocusVideoState());
  String? loadedUrl;
  String? loadedFile;

  @override
  ValueListenable<FocusVideoState> get state => _state;

  @override
  Future<void> loadNetwork(String url) async {
    if (!isValidVideoUrl(url)) {
      _state.value = const FocusVideoState(
        status: FocusVideoStatus.error,
        errorMessage: 'Enter a valid http or https video address.',
      );
      return;
    }
    loadedUrl = url;
    _state.value = const FocusVideoState(status: FocusVideoStatus.ready);
  }

  @override
  Future<void> loadFile(String path) async {
    loadedFile = path;
    _state.value = const FocusVideoState(status: FocusVideoStatus.ready);
  }

  @override
  Future<void> play() async {}
  @override
  Future<void> pause() async {}
  @override
  Future<void> seekTo(Duration position) async {}
  @override
  Widget buildView() => const SizedBox(height: 40, key: Key('fake_video'));
  @override
  Future<void> dispose() async {}
}

class InMemoryFocusRepository implements FocusRepository {
  final sessions = <String, FocusSession>{};

  @override
  Future<FocusSession> saveSession(FocusSession session) async {
    sessions[session.id] = session;
    return session;
  }

  @override
  Future<List<FocusSession>> getSessions(
    String userId, {
    DateTime? since,
  }) async {
    return sessions.values
        .where(
          (s) =>
              s.userId == userId &&
              (since == null || !s.startedAt.isBefore(since)),
        )
        .toList()
      ..sort((a, b) => b.startedAt.compareTo(a.startedAt));
  }
}

class RecordingFocusSink implements FocusEventSink {
  final completed = <FocusSession>[];

  @override
  Future<void> onFocusCompleted(FocusSession session) async =>
      completed.add(session);
}

class FakePushMessaging implements PushMessagingService {
  FakePushMessaging({
    this.supported = true,
    this.permission = PushPermission.notDetermined,
    this.requestResult = PushPermission.granted,
    this.token = 'token-1',
    this.platformName = 'android',
  });

  bool supported;
  PushPermission permission;
  PushPermission requestResult;
  String? token;
  String platformName;

  int permissionRequests = 0;
  int tokenDeletions = 0;
  final subscribed = <String>{};

  final refresh = StreamController<String>.broadcast();
  final foreground = StreamController<PushMessage>.broadcast();
  final opened = StreamController<PushMessage>.broadcast();
  PushMessage? initial;

  @override
  Future<bool> get isSupported async => supported;

  @override
  String get platform => platformName;

  @override
  Future<PushPermission> permissionStatus() async => permission;

  @override
  Future<PushPermission> requestPermission() async {
    permissionRequests++;
    permission = requestResult;
    return requestResult;
  }

  @override
  Future<String?> getToken() async => token;

  @override
  Stream<String> get onTokenRefresh => refresh.stream;

  @override
  Future<void> deleteToken() async {
    tokenDeletions++;
    token = null;
  }

  @override
  Stream<PushMessage> get onForegroundMessage => foreground.stream;

  @override
  Stream<PushMessage> get onMessageOpenedApp => opened.stream;

  @override
  Future<PushMessage?> getInitialMessage() async => initial;

  @override
  Future<void> subscribeToTopic(String topic) async => subscribed.add(topic);

  @override
  Future<void> unsubscribeFromTopic(String topic) async =>
      subscribed.remove(topic);
}

class FakeDeviceTokenStore implements DeviceTokenStore {
  /// docId -> data, scoped by uid.
  final docs = <String, Map<String, Map<String, Object?>>>{};

  Map<String, Map<String, Object?>> forUser(String uid) => docs[uid] ?? {};

  @override
  Future<void> save(String uid, String docId, Map<String, Object?> data) async {
    (docs[uid] ??= {})[docId] = data;
  }

  @override
  Future<void> remove(String uid, String docId) async {
    docs[uid]?.remove(docId);
  }
}

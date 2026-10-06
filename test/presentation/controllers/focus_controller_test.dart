import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:omnilife/core/services/ambient_audio_player.dart';
import 'package:omnilife/core/services/analytics_service.dart';
import 'package:omnilife/domain/entities/focus_session.dart';
import 'package:omnilife/domain/focus/focus_state_store.dart';
import 'package:omnilife/domain/focus/focus_timer.dart';
import 'package:omnilife/presentation/controllers/focus_controller.dart';

import '../../support/focus_push_fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeClock clock;
  late InMemoryFocusRepository repository;
  late InMemoryFocusStateStore store;
  late FakeAmbientAudio audio;
  late FakeVideo video;
  late RecordingFocusSink sink;
  late RecordingAnalyticsService analytics;
  String? uid;

  FocusController build({bool restore = true}) {
    final c = FocusController(
      repository: repository,
      stateStore: store,
      audio: audio,
      video: video,
      eventSink: sink,
      notifications: null,
      userIdProvider: () => uid,
      clock: clock.call,
      ticker: null,
    );
    Get.put(c);
    return c;
  }

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  setUp(() {
    Get.testMode = true;
    Get.reset();
    clock = FakeClock(DateTime(2026, 10, 7, 9)); // a Wednesday
    repository = InMemoryFocusRepository();
    store = InMemoryFocusStateStore();
    audio = FakeAmbientAudio();
    video = FakeVideo();
    sink = RecordingFocusSink();
    analytics = RecordingAnalyticsService();
    AnalyticsService.instance = analytics;
    uid = 'u1';
  });

  tearDown(() {
    AnalyticsService.instance = const NoopAnalyticsService();
    Get.reset();
  });

  test('start requires a signed-in user', () async {
    uid = null;
    final c = build();
    expect(c.start(), isFalse);
    expect(c.timer.phase, FocusPhase.idle);
    expect(c.message.value, isNotNull);
  });

  test('start persists the in-progress session and stop clears it', () async {
    final c = build();
    await settle();

    expect(c.start(), isTrue);
    await settle();
    final saved = await store.load('u1');
    expect(saved?.phase, FocusPhase.running);
    expect(saved?.sessionStartedAt, clock.now);

    c.pause();
    await settle();
    expect((await store.load('u1'))?.phase, FocusPhase.paused);

    c.stop();
    await settle();
    expect(await store.load('u1'), isNull);
  });

  test(
    'finishing a session saves it, notifies, chimes and logs an event',
    () async {
      final c = build();
      await settle();
      c.start();
      final started = clock.now;

      clock.advance(const Duration(minutes: 25));
      c.timer.tick();
      await settle();

      expect(c.timer.phase, FocusPhase.completed);
      expect(repository.sessions, hasLength(1));
      final session = repository.sessions.values.single;
      expect(session.userId, 'u1');
      expect(session.startedAt, started);
      expect(session.focusedMinutes, 25);
      expect(c.todayMinutes, 25);
      expect(c.weekMinutes, 25);
      expect(c.todaySessions, hasLength(1));

      expect(sink.completed, [session]);
      expect(audio.chimes, 1);
      expect(c.message.value, contains('25'));

      expect(analytics.events, hasLength(1));
      expect(analytics.events.single.name, 'focus_session_completed');
      expect(analytics.events.single.params, {
        'planned_minutes': 25,
        'focused_minutes': 25,
      });
    },
  );

  test('analytics for a focus session contains no identifiers', () async {
    final c = build();
    await settle();
    c.start();
    clock.advance(const Duration(minutes: 25));
    c.timer.tick();
    await settle();

    final params = analytics.events.single.params;
    for (final v in params.values) {
      expect(v, isA<num>());
    }
    expect(params.keys, isNot(contains('uid')));
  });

  test('weekly total sums sessions since Monday; today only today', () async {
    // Monday and Tuesday of the same week, plus a session last week.
    Future<void> add(String id, DateTime at, int minutes) =>
        repository.saveSession(_focus(id, at, minutes));
    await add('mon', DateTime(2026, 10, 5, 10), 25);
    await add('tue', DateTime(2026, 10, 6, 10), 50);
    await add('last', DateTime(2026, 10, 2, 10), 90);
    await add('wed', DateTime(2026, 10, 7, 8), 15);

    final c = build();
    await settle();
    await c.loadSessions();

    expect(c.weekMinutes, 25 + 50 + 15);
    expect(c.todayMinutes, 15);
    expect(c.todaySessions.map((s) => s.id), ['wed']);
  });

  test('restart mid-session resumes with the right remaining time', () async {
    var c = build();
    await settle();
    c.start();
    clock.advance(const Duration(minutes: 10));
    await settle();

    // App killed; a new controller starts 5 minutes later.
    Get.reset();
    clock.advance(const Duration(minutes: 5));
    c = build();
    await settle();

    expect(c.timer.phase, FocusPhase.running);
    expect(c.timer.remaining, const Duration(minutes: 10));
    expect(repository.sessions, isEmpty);
  });

  test(
    'restart after the end records the session once, without a late chime',
    () async {
      var c = build();
      await settle();
      c.start();
      final started = clock.now;
      await settle();

      Get.reset();
      clock.advance(const Duration(hours: 3));
      c = build();
      await settle();

      expect(c.timer.phase, FocusPhase.completed);
      expect(repository.sessions, hasLength(1));
      expect(
        repository.sessions.values.single.endedAt,
        started.add(const Duration(minutes: 25)),
      );
      expect(sink.completed, hasLength(1));
      expect(audio.chimes, 0);

      // Another restart must not record it again.
      Get.reset();
      c = build();
      await settle();
      expect(repository.sessions, hasLength(1));
      expect(sink.completed, hasLength(1));
    },
  );

  test('break flow after completion', () async {
    final c = build();
    await settle();
    c.start();
    clock.advance(const Duration(minutes: 25));
    c.timer.tick();
    await settle();

    c.startBreak();
    expect(c.timer.phase, FocusPhase.onBreak);
    c.skipBreak();
    expect(c.timer.phase, FocusPhase.idle);
    await settle();
    expect(await store.load('u1'), isNull);
  });

  test('length settings only apply while idle', () async {
    final c = build();
    await settle();
    c.setFocusMinutes(50);
    c.setBreakMinutes(10);
    expect(c.timer.state.focusDuration, const Duration(minutes: 50));
    expect(c.timer.state.breakDuration, const Duration(minutes: 10));
    expect(c.remaining.value, const Duration(minutes: 50));

    c.start();
    c.setFocusMinutes(15);
    expect(c.timer.state.focusDuration, const Duration(minutes: 50));
  });

  group('media', () {
    test('selecting a sound plays it; volume and toggle work', () async {
      final c = build();
      await c.selectSound(AmbientSound.brown);
      expect(audio.state.value.sound, AmbientSound.brown);
      expect(audio.state.value.isPlaying, isTrue);

      await c.toggleSound();
      expect(audio.state.value.isPlaying, isFalse);
      await c.toggleSound();
      expect(audio.state.value.isPlaying, isTrue);

      await c.setVolume(0.2);
      expect(audio.state.value.volume, 0.2);

      await c.selectSound(AmbientSound.off);
      await c.toggleSound();
      expect(audio.state.value.isPlaying, isFalse);
    });

    test(
      'video url is validated; failures surface as an error state',
      () async {
        final c = build();
        await c.loadVideoUrl('not a url');
        expect(video.state.value.status.name, 'error');
        expect(video.state.value.errorMessage, isNotNull);

        await c.loadVideoUrl('https://example.com/a.mp4');
        expect(video.state.value.status.name, 'ready');
        expect(video.loadedUrl, 'https://example.com/a.mp4');
      },
    );

    test('local video comes from the injected picker', () async {
      final c = FocusController(
        repository: repository,
        stateStore: store,
        audio: audio,
        video: video,
        userIdProvider: () => uid,
        clock: clock.call,
        ticker: null,
        pickVideoFile: () async => '/videos/loop.mp4',
      );
      Get.put(c);
      await c.pickLocalVideo();
      expect(video.loadedFile, '/videos/loop.mp4');
    });
  });
}

FocusSession _focus(String id, DateTime at, int minutes) => FocusSession(
  id: id,
  userId: 'u1',
  startedAt: at,
  endedAt: at.add(Duration(minutes: minutes)),
  plannedSeconds: minutes * 60,
  focusedSeconds: minutes * 60,
);

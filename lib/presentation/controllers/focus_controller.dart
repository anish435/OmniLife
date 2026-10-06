import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/errors/failures.dart';
import '../../core/services/ambient_audio_player.dart';
import '../../core/services/analytics_service.dart';
import '../../core/services/focus_video_player.dart';
import '../../core/services/notification_service.dart';
import '../../domain/entities/focus_session.dart';
import '../../domain/focus/focus_event_sink.dart';
import '../../domain/focus/focus_state_store.dart';
import '../../domain/focus/focus_timer.dart';
import '../../domain/repositories/focus_repository.dart';
import 'auth_controller.dart';

/// Presentation state for focus mode: the timer, today's/this week's
/// sessions, ambient audio and the looping background video.
class FocusController extends GetxController with WidgetsBindingObserver {
  FocusController({
    required this._repository,
    required FocusStateStore stateStore,
    required this.audio,
    required this.video,
    this._eventSink,
    this._notifications,
    this._userIdProvider,
    DateTime Function()? clock,
    this._ticker = periodicFocusTicker,
    this._pickVideoFile,
  }) : _store = stateStore,
       _clock = clock ?? DateTime.now;

  /// Notification id reserved for the focus completion alert.
  static const notificationId = 424242;

  final FocusRepository _repository;
  final FocusStateStore _store;
  final AmbientAudioPlayer audio;
  final FocusVideoPlayer video;
  final FocusEventSink? _eventSink;
  final NotificationService? _notifications;
  final String? Function()? _userIdProvider;
  final DateTime Function() _clock;
  final FocusTickerFactory? _ticker;
  final Future<String?> Function()? _pickVideoFile;

  late final FocusTimer timer;
  StreamSubscription<FocusTimerState>? _stateSub;
  Worker? _authWorker;

  final timerState = const FocusTimerState().obs;
  final remaining = const Duration(minutes: 25).obs;
  final sessions = <FocusSession>[].obs;
  final isLoading = false.obs;
  final errorMessage = RxnString();

  /// One-shot confirmation text for the UI (shown as a snackbar).
  final message = RxnString();

  String? get _uid {
    final provided = _userIdProvider;
    if (provided != null) return provided();
    try {
      return Get.find<AuthController>().currentUser.value?.uid;
    } catch (_) {
      return null;
    }
  }

  NotificationService? get _notifier {
    if (_notifications != null) return _notifications;
    return Get.isRegistered<NotificationService>()
        ? Get.find<NotificationService>()
        : null;
  }

  FocusEventSink get _sink {
    if (_eventSink != null) return _eventSink;
    return Get.isRegistered<FocusEventSink>()
        ? Get.find<FocusEventSink>()
        : const NoopFocusEventSink();
  }

  @override
  void onInit() {
    super.onInit();
    timer = FocusTimer(
      clock: _clock,
      ticker: _ticker,
      onSessionCompleted: _handleCompletion,
    );
    _stateSub = timer.stream.listen(_onTimerState);
    WidgetsBinding.instance.addObserver(this);

    try {
      _authWorker = ever(Get.find<AuthController>().currentUser, (_) {
        _restore();
        loadSessions();
      });
    } catch (_) {}
    _restore();
    loadSessions();
  }

  // --- Timer -------------------------------------------------------------

  void _onTimerState(FocusTimerState s) {
    final previous = timerState.value;
    timerState.value = s;
    remaining.value = s.remainingAt(_clock());
    if (identical(previous, s)) return; // plain tick
    _persist(s);
    _syncAlert(previous, s);
  }

  Future<void> _restore() async {
    final uid = _uid;
    if (uid == null) return;
    final saved = await _store.load(uid);
    if (saved != null && timer.state.phase == FocusPhase.idle) {
      timer.restore(saved);
    }
  }

  void _persist(FocusTimerState s) {
    final uid = _uid;
    if (uid == null) return;
    if (s.phase == FocusPhase.idle) {
      _store.clear(uid);
    } else {
      _store.save(uid, s);
    }
  }

  /// Keeps the OS completion alert in step with the timer, so it still fires
  /// when the app is backgrounded or closed.
  void _syncAlert(FocusTimerState previous, FocusTimerState s) {
    final notifier = _notifier;
    if (notifier == null) return;
    final counting =
        s.phase == FocusPhase.running || s.phase == FocusPhase.onBreak;
    if (!counting) {
      notifier.cancelReminder(notificationId);
      return;
    }
    final isFocus = s.segment == FocusSegment.focus;
    notifier.scheduleReminder(
      id: notificationId,
      title: isFocus ? 'Focus session complete' : 'Break is over',
      body: isFocus
          ? '${s.focusDuration.inMinutes} minutes done. Time for a break.'
          : 'Ready for the next focus session?',
      scheduledDate: _clock().add(s.remainingAt(_clock())),
      payload: 'focus',
      alarmClock: true,
      withActions: false,
    );
  }

  bool start() {
    if (_uid == null) {
      message.value = 'Sign in to start a focus session.';
      return false;
    }
    final ok = timer.start();
    if (ok) message.value = 'Focus session started.';
    return ok;
  }

  void pause() => timer.pause();
  void resume() => timer.resume();

  void stop() {
    timer.stop();
    message.value = 'Session stopped. Nothing was recorded.';
  }

  void startBreak() => timer.startBreak();

  void skipBreak() => timer.skipBreak();

  void setFocusMinutes(int minutes) {
    if (timer.configure(focus: Duration(minutes: minutes))) {
      remaining.value = timer.state.remainingAt(_clock());
    }
  }

  void setBreakMinutes(int minutes) =>
      timer.configure(rest: Duration(minutes: minutes));

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) timer.tick();
  }

  // --- Completion & history ---------------------------------------------

  Future<void> _handleCompletion(FocusCompletion c) async {
    final uid = _uid;
    if (uid == null) return;
    final session = FocusSession(
      id: 'focus_${c.startedAt.millisecondsSinceEpoch}',
      userId: uid,
      startedAt: c.startedAt,
      endedAt: c.endedAt,
      plannedSeconds: c.plannedDuration.inSeconds,
      focusedSeconds: c.focusedDuration.inSeconds,
    );
    try {
      await _repository.saveSession(session);
      await loadSessions();
    } on Failure catch (e) {
      errorMessage.value = e.message;
    } catch (_) {
      errorMessage.value = 'Could not save the focus session.';
    }

    // Completed in the foreground: ring the bell and cancel the OS alert.
    final fresh = _clock().difference(c.endedAt) < const Duration(seconds: 10);
    if (fresh) {
      _notifier?.cancelReminder(notificationId);
      audio.playChime();
    }
    message.value = 'Focus session complete: ${session.focusedMinutes} min.';

    AnalyticsService.instance.logEvent(AnalyticsEvents.focusSessionCompleted, {
      'planned_minutes': (session.plannedSeconds / 60).round(),
      'focused_minutes': session.focusedMinutes,
    });
    try {
      await _sink.onFocusCompleted(session);
    } catch (_) {}
  }

  Future<void> loadSessions() async {
    final uid = _uid;
    if (uid == null) {
      sessions.clear();
      return;
    }
    isLoading.value = true;
    errorMessage.value = null;
    try {
      final weekStart = startOfWeek(_clock());
      sessions.assignAll(await _repository.getSessions(uid, since: weekStart));
    } on Failure catch (e) {
      errorMessage.value = e.message;
    } catch (e) {
      errorMessage.value = 'Failed to load focus sessions.';
    } finally {
      isLoading.value = false;
    }
  }

  static DateTime startOfWeek(DateTime now) {
    final day = DateTime(now.year, now.month, now.day);
    return day.subtract(Duration(days: day.weekday - DateTime.monday));
  }

  List<FocusSession> get todaySessions {
    final now = _clock();
    return sessions
        .where(
          (s) =>
              s.startedAt.year == now.year &&
              s.startedAt.month == now.month &&
              s.startedAt.day == now.day,
        )
        .toList();
  }

  int get todayMinutes =>
      todaySessions.fold<int>(0, (sum, s) => sum + s.focusedSeconds) ~/ 60;

  int get weekMinutes =>
      sessions.fold<int>(0, (sum, s) => sum + s.focusedSeconds) ~/ 60;

  // --- Audio & video -----------------------------------------------------

  Future<void> selectSound(AmbientSound sound) => audio.select(sound);
  Future<void> setVolume(double v) => audio.setVolume(v);

  Future<void> toggleSound() async {
    final s = audio.state.value;
    if (s.sound == AmbientSound.off) return;
    if (s.isPlaying) {
      await audio.pause();
    } else {
      await audio.play();
    }
  }

  Future<void> loadVideoUrl(String url) => video.loadNetwork(url);

  /// Lets the user choose a local video (mobile only).
  Future<void> pickLocalVideo() async {
    final picker = _pickVideoFile ?? _defaultPick;
    final path = await picker();
    if (path != null) await video.loadFile(path);
  }

  static Future<String?> _defaultPick() async {
    final file = await ImagePicker().pickVideo(source: ImageSource.gallery);
    return file?.path;
  }

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this);
    _authWorker?.dispose();
    _stateSub?.cancel();
    timer.dispose();
    audio.dispose();
    video.dispose();
    super.onClose();
  }
}

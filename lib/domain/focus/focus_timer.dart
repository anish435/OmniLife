import 'dart:async';

/// Lifecycle of a focus session.
enum FocusPhase { idle, running, paused, onBreak, completed }

/// Which part of the cycle a running or paused timer is counting.
enum FocusSegment { focus, rest }

/// Produces a stream that fires once per tick. Injected so tests drive the
/// timer by hand and production uses a one-second periodic stream.
typedef FocusTickerFactory = Stream<void> Function();

Stream<void> periodicFocusTicker() =>
    Stream<void>.periodic(const Duration(seconds: 1));

/// Result of a finished focus segment.
class FocusCompletion {
  const FocusCompletion({
    required this.startedAt,
    required this.endedAt,
    required this.plannedDuration,
    required this.focusedDuration,
  });

  final DateTime startedAt;
  final DateTime endedAt;
  final Duration plannedDuration;
  final Duration focusedDuration;
}

/// Immutable snapshot of the timer. Contains only timestamps and durations
/// (never tick counts), so it can be persisted and the remaining time
/// recomputed after a restart or after the app was backgrounded.
class FocusTimerState {
  const FocusTimerState({
    this.phase = FocusPhase.idle,
    this.segment = FocusSegment.focus,
    this.focusDuration = const Duration(minutes: 25),
    this.breakDuration = const Duration(minutes: 5),
    this.sessionStartedAt,
    this.segmentStartedAt,
    this.accumulatedPause = Duration.zero,
    this.pausedAt,
    this.completedAt,
  });

  final FocusPhase phase;
  final FocusSegment segment;
  final Duration focusDuration;
  final Duration breakDuration;

  /// When the focus segment of this session first started.
  final DateTime? sessionStartedAt;

  /// Start of the current segment (focus or break).
  final DateTime? segmentStartedAt;

  /// Total time spent paused within the current segment.
  final Duration accumulatedPause;
  final DateTime? pausedAt;

  /// When the focus segment finished (set while [phase] is completed).
  final DateTime? completedAt;

  bool get isActive =>
      phase == FocusPhase.running ||
      phase == FocusPhase.paused ||
      phase == FocusPhase.onBreak;

  Duration get segmentDuration =>
      segment == FocusSegment.focus ? focusDuration : breakDuration;

  /// Time spent counting in the current segment as of [now].
  Duration elapsedAt(DateTime now) {
    final start = segmentStartedAt;
    if (start == null) return Duration.zero;
    final reference = phase == FocusPhase.paused ? (pausedAt ?? now) : now;
    final elapsed = reference.difference(start) - accumulatedPause;
    return elapsed.isNegative ? Duration.zero : elapsed;
  }

  Duration remainingAt(DateTime now) {
    if (phase == FocusPhase.idle) return focusDuration;
    if (phase == FocusPhase.completed) return Duration.zero;
    final left = segmentDuration - elapsedAt(now);
    return left.isNegative ? Duration.zero : left;
  }

  /// 0..1 progress through the current segment.
  double progressAt(DateTime now) {
    if (phase == FocusPhase.idle) return 0;
    if (phase == FocusPhase.completed) return 1;
    final total = segmentDuration.inMilliseconds;
    if (total <= 0) return 1;
    return (elapsedAt(now).inMilliseconds / total).clamp(0.0, 1.0);
  }

  FocusTimerState copyWith({
    FocusPhase? phase,
    FocusSegment? segment,
    Duration? focusDuration,
    Duration? breakDuration,
    DateTime? sessionStartedAt,
    DateTime? segmentStartedAt,
    Duration? accumulatedPause,
    DateTime? pausedAt,
    DateTime? completedAt,
    bool clearPausedAt = false,
    bool clearCompletedAt = false,
  }) {
    return FocusTimerState(
      phase: phase ?? this.phase,
      segment: segment ?? this.segment,
      focusDuration: focusDuration ?? this.focusDuration,
      breakDuration: breakDuration ?? this.breakDuration,
      sessionStartedAt: sessionStartedAt ?? this.sessionStartedAt,
      segmentStartedAt: segmentStartedAt ?? this.segmentStartedAt,
      accumulatedPause: accumulatedPause ?? this.accumulatedPause,
      pausedAt: clearPausedAt ? null : (pausedAt ?? this.pausedAt),
      completedAt: clearCompletedAt ? null : (completedAt ?? this.completedAt),
    );
  }

  Map<String, Object?> toJson() => {
    'phase': phase.name,
    'segment': segment.name,
    'focusMs': focusDuration.inMilliseconds,
    'breakMs': breakDuration.inMilliseconds,
    'sessionStart': sessionStartedAt?.millisecondsSinceEpoch,
    'segmentStart': segmentStartedAt?.millisecondsSinceEpoch,
    'pauseMs': accumulatedPause.inMilliseconds,
    'pausedAt': pausedAt?.millisecondsSinceEpoch,
    'completedAt': completedAt?.millisecondsSinceEpoch,
  };

  factory FocusTimerState.fromJson(Map<String, Object?> json) {
    DateTime? date(Object? v) =>
        v is int ? DateTime.fromMillisecondsSinceEpoch(v) : null;
    T enumByName<T extends Enum>(List<T> values, Object? name, T fallback) {
      for (final v in values) {
        if (v.name == name) return v;
      }
      return fallback;
    }

    return FocusTimerState(
      phase: enumByName(FocusPhase.values, json['phase'], FocusPhase.idle),
      segment: enumByName(
        FocusSegment.values,
        json['segment'],
        FocusSegment.focus,
      ),
      focusDuration: Duration(
        milliseconds: (json['focusMs'] as int?) ?? 25 * 60 * 1000,
      ),
      breakDuration: Duration(
        milliseconds: (json['breakMs'] as int?) ?? 5 * 60 * 1000,
      ),
      sessionStartedAt: date(json['sessionStart']),
      segmentStartedAt: date(json['segmentStart']),
      accumulatedPause: Duration(milliseconds: (json['pauseMs'] as int?) ?? 0),
      pausedAt: date(json['pausedAt']),
      completedAt: date(json['completedAt']),
    );
  }
}

/// Pomodoro state machine: idle -> running -> completed -> onBreak -> idle,
/// with pause/resume while running or on break.
///
/// Time is never counted in ticks. Every query recomputes from the stored
/// timestamps and the injected [clock], so the timer is exact after the app
/// is backgrounded or restarted ([restore]). Ticks only exist to nudge
/// listeners and to notice that a segment has ended.
class FocusTimer {
  FocusTimer({
    DateTime Function()? clock,
    this.ticker,
    Duration focusDuration = const Duration(minutes: 25),
    Duration breakDuration = const Duration(minutes: 5),
    this.onSessionCompleted,
  }) : _clock = clock ?? DateTime.now,
       _state = FocusTimerState(
         focusDuration: focusDuration,
         breakDuration: breakDuration,
       );

  final DateTime Function() _clock;

  /// Null means "no automatic ticking": call [tick] manually.
  final FocusTickerFactory? ticker;

  /// Fired exactly once when a focus segment reaches its end.
  final void Function(FocusCompletion completion)? onSessionCompleted;

  FocusTimerState _state;
  StreamSubscription<void>? _tickSub;
  final _controller = StreamController<FocusTimerState>.broadcast(sync: true);

  FocusTimerState get state => _state;
  Stream<FocusTimerState> get stream => _controller.stream;
  FocusPhase get phase => _state.phase;
  Duration get remaining => _state.remainingAt(_clock());
  double get progress => _state.progressAt(_clock());

  /// Changes the lengths. Only allowed while idle or completed.
  bool configure({Duration? focus, Duration? rest}) {
    if (_state.isActive) return false;
    if ((focus != null && focus <= Duration.zero) ||
        (rest != null && rest <= Duration.zero)) {
      return false;
    }
    _emit(_state.copyWith(focusDuration: focus, breakDuration: rest));
    return true;
  }

  /// Starts a focus segment from idle or completed.
  bool start() {
    if (_state.isActive) return false;
    final now = _clock();
    _emit(
      FocusTimerState(
        phase: FocusPhase.running,
        segment: FocusSegment.focus,
        focusDuration: _state.focusDuration,
        breakDuration: _state.breakDuration,
        sessionStartedAt: now,
        segmentStartedAt: now,
      ),
    );
    return true;
  }

  bool pause() {
    if (_state.phase != FocusPhase.running &&
        _state.phase != FocusPhase.onBreak) {
      return false;
    }
    _emit(_state.copyWith(phase: FocusPhase.paused, pausedAt: _clock()));
    return true;
  }

  bool resume() {
    if (_state.phase != FocusPhase.paused) return false;
    final now = _clock();
    final pausedFor = now.difference(_state.pausedAt ?? now);
    _emit(
      _state.copyWith(
        phase: _state.segment == FocusSegment.focus
            ? FocusPhase.running
            : FocusPhase.onBreak,
        accumulatedPause: _state.accumulatedPause + pausedFor,
        clearPausedAt: true,
      ),
    );
    return true;
  }

  /// Starts the break after a completed focus segment.
  bool startBreak() {
    if (_state.phase != FocusPhase.completed) return false;
    _emit(
      FocusTimerState(
        phase: FocusPhase.onBreak,
        segment: FocusSegment.rest,
        focusDuration: _state.focusDuration,
        breakDuration: _state.breakDuration,
        sessionStartedAt: _state.sessionStartedAt,
        segmentStartedAt: _clock(),
      ),
    );
    return true;
  }

  /// Ends the break (or declines it after completion) and returns to idle.
  bool skipBreak() {
    final onRest = _state.segment == FocusSegment.rest && _state.isActive;
    if (_state.phase != FocusPhase.completed && !onRest) return false;
    _reset();
    return true;
  }

  /// Abandons the current segment without recording anything.
  void stop() {
    if (_state.phase == FocusPhase.idle) return;
    _reset();
  }

  /// Re-evaluates the timer against the clock. Call on every tick and when
  /// the app returns to the foreground.
  void tick() {
    final s = _state;
    if (s.phase != FocusPhase.running && s.phase != FocusPhase.onBreak) {
      _emit(s, notifyOnly: true);
      return;
    }
    if (s.remainingAt(_clock()) > Duration.zero) {
      _emit(s, notifyOnly: true);
      return;
    }
    final start = s.segmentStartedAt!;
    final end = start.add(s.accumulatedPause + s.segmentDuration);
    if (s.segment == FocusSegment.rest) {
      _reset();
      return;
    }
    final completion = FocusCompletion(
      startedAt: s.sessionStartedAt ?? start,
      endedAt: end,
      plannedDuration: s.focusDuration,
      focusedDuration: s.focusDuration,
    );
    _emit(
      s.copyWith(
        phase: FocusPhase.completed,
        completedAt: end,
        clearPausedAt: true,
      ),
    );
    onSessionCompleted?.call(completion);
  }

  /// Adopts a persisted snapshot, then catches up with the clock. A segment
  /// that ended while the app was closed completes immediately, with its
  /// true end time.
  void restore(FocusTimerState snapshot) {
    _emit(snapshot);
    tick();
  }

  void dispose() {
    _tickSub?.cancel();
    _tickSub = null;
    _controller.close();
  }

  void _reset() {
    _emit(
      FocusTimerState(
        focusDuration: _state.focusDuration,
        breakDuration: _state.breakDuration,
      ),
    );
  }

  void _emit(FocusTimerState next, {bool notifyOnly = false}) {
    _state = next;
    _syncTicker();
    if (!_controller.isClosed) _controller.add(next);
  }

  void _syncTicker() {
    final factory = ticker;
    if (factory == null) return;
    final needsTicks =
        _state.phase == FocusPhase.running ||
        _state.phase == FocusPhase.onBreak;
    if (needsTicks && _tickSub == null) {
      _tickSub = factory().listen((_) => tick());
    } else if (!needsTicks && _tickSub != null) {
      _tickSub!.cancel();
      _tickSub = null;
    }
  }
}

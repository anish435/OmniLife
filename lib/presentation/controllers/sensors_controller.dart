// ignore_for_file: prefer_initializing_formals
import 'dart:async';

import 'package:get/get.dart';

import '../../core/services/sensors/flip_detector.dart';
import '../../core/services/sensors/sensor_service.dart';
import '../../domain/entities/daily_steps.dart';
import '../../domain/repositories/steps_repository.dart';

/// State for the Sensors screen: step tracking (opt-in, permission asked
/// only when the user turns it on), the daily goal, the 7-day history and
/// the optional face-down detector.
///
/// Battery: no sensor is registered until the user enables it, and both the
/// step listener and the flip detector are released in [onClose].
class SensorsController extends GetxController {
  SensorsController({
    required SensorService sensors,
    required StepsRepository repository,
    FlipDetector? flipDetector,
    DateTime Function()? clock,
  }) : _sensors = sensors,
       _repository = repository,
       _flip = flipDetector ?? FlipDetector(sensors: sensors),
       _now = clock ?? DateTime.now;

  final SensorService _sensors;
  final StepsRepository _repository;
  final FlipDetector _flip;
  final DateTime Function() _now;

  bool get isSupported => _sensors.isSupported;

  final isLoading = true.obs;

  /// null until the first non-prompting check completes.
  final stepAccess = Rxn<SensorAccess>();
  final trackingEnabled = false.obs;
  final isRequesting = false.obs;

  /// True once at least one counter reading arrived this session.
  final hasReading = false.obs;
  final todaySteps = 0.obs;
  final week = <DailySteps>[].obs;
  final goal = Rxn<int>();

  final flipActive = false.obs;

  /// null until the detector produced a debounced state.
  final faceDown = Rxn<bool>();

  /// One-shot message for the page (snackbar).
  final notice = RxnString();

  StreamSubscription<int>? _stepSub;
  StreamSubscription<int>? _todaySub;
  StreamSubscription<List<DailySteps>>? _weekSub;
  StreamSubscription<bool>? _flipSub;

  bool get stepsGranted => stepAccess.value == SensorAccess.granted;

  /// Fraction of the goal reached today, 0..1; null without a goal.
  double? get goalProgress {
    final g = goal.value;
    if (g == null || g <= 0) return null;
    return (todaySteps.value / g).clamp(0.0, 1.0);
  }

  @override
  void onInit() {
    super.onInit();
    unawaited(load());
  }

  @override
  void onClose() {
    _stepSub?.cancel();
    _todaySub?.cancel();
    _weekSub?.cancel();
    _flipSub?.cancel();
    super.onClose();
  }

  Future<void> load() async {
    isLoading.value = true;
    goal.value = await _repository.dailyGoal();
    todaySteps.value = await _repository.todaySteps();
    week.assignAll(await _repository.last7Days());
    _todaySub = _repository.watchTodaySteps().listen(
      (v) => todaySteps.value = v,
    );
    _weekSub = _repository.watchLast7Days().listen(week.assignAll);

    if (!isSupported) {
      stepAccess.value = SensorAccess.unsupported;
      isLoading.value = false;
      return;
    }
    stepAccess.value = await _sensors.checkStepAccess(); // never prompts
    trackingEnabled.value = await _repository.isTrackingEnabled();
    isLoading.value = false;

    // Resume only if the user already opted in AND permission is intact.
    if (trackingEnabled.value && stepsGranted) _startStepListener();
    unawaited(_syncInBackground());
  }

  Future<void> _syncInBackground() async {
    try {
      await _repository.pullRemote();
      await _repository.syncPending();
    } catch (_) {}
  }

  /// User turned step tracking on. Requests the runtime permission.
  Future<void> enableTracking() async {
    if (!isSupported) return;
    isRequesting.value = true;
    try {
      final access = await _sensors.requestStepAccess();
      stepAccess.value = access;
      if (access == SensorAccess.granted) {
        await _repository.setTrackingEnabled(true);
        trackingEnabled.value = true;
        _startStepListener();
        notice.value = 'Step tracking is on';
      } else if (access == SensorAccess.deniedForever) {
        notice.value = 'Step permission is blocked. Open settings to allow it.';
      } else if (access == SensorAccess.denied) {
        notice.value = 'Step tracking needs the activity permission.';
      }
    } finally {
      isRequesting.value = false;
    }
  }

  Future<void> disableTracking() async {
    await _stepSub?.cancel();
    _stepSub = null;
    hasReading.value = false;
    await _repository.setTrackingEnabled(false);
    trackingEnabled.value = false;
    notice.value = 'Step tracking is off';
  }

  void _startStepListener() {
    if (_stepSub != null) return;
    _stepSub = _sensors.stepCounts().listen(
      (counter) {
        hasReading.value = true;
        unawaited(_repository.recordCounter(counter, _now()));
      },
      onError: (_) {
        notice.value = 'This device has no step counter.';
        _stepSub?.cancel();
        _stepSub = null;
      },
    );
  }

  Future<void> openSettings() async {
    final ok = await _sensors.openSettings();
    if (!ok) notice.value = 'Could not open settings.';
  }

  /// After returning from settings.
  Future<void> recheckAccess() async {
    stepAccess.value = await _sensors.checkStepAccess();
    if (stepsGranted && trackingEnabled.value) _startStepListener();
  }

  Future<void> setGoal(int? steps) async {
    await _repository.setDailyGoal(steps);
    goal.value = await _repository.dailyGoal();
    notice.value = goal.value == null
        ? 'Daily goal cleared'
        : 'Daily goal set to ${goal.value} steps';
  }

  // --- Flip detector ----------------------------------------------------

  /// Samples the accelerometer only while on.
  void setFlipDetection(bool on) {
    if (on == flipActive.value) return;
    if (!on) {
      _flipSub?.cancel();
      _flipSub = null;
      flipActive.value = false;
      faceDown.value = null;
      return;
    }
    if (!isSupported) return;
    flipActive.value = true;
    _flipSub = _flip.watch().listen(
      (down) => faceDown.value = down,
      onError: (_) {
        notice.value = 'Motion sensor unavailable.';
        setFlipDetection(false);
      },
    );
  }
}

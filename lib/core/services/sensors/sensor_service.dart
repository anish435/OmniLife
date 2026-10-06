/// State of what a sensor feature may do on this device.
enum SensorAccess {
  /// Allowed and available.
  granted,

  /// Not granted yet; asking again is allowed.
  denied,

  /// Denied permanently; only system settings can change it.
  deniedForever,

  /// No such sensor / platform support (web, desktop, no step counter).
  unsupported,
}

/// One accelerometer reading in m/s^2 (device axes, gravity included).
class AccelSample {
  const AccelSample({
    required this.x,
    required this.y,
    required this.z,
    required this.timestamp,
  });

  final double x;
  final double y;
  final double z;
  final DateTime timestamp;
}

/// Motion sensors behind an interface.
///
/// * Steps: the hardware cumulative counter (steps since last boot). Reading
///   it needs the Android ACTIVITY_RECOGNITION runtime permission, requested
///   only from [requestStepAccess] (called when the user enables tracking).
/// * Accelerometer: high-rate, so it is subscribed only while a consumer
///   (e.g. `FlipDetector`) is listening.
/// * Web and desktop report [SensorAccess.unsupported] and emit nothing.
abstract class SensorService {
  /// Whether this platform has the sensors at all (no permission involved).
  bool get isSupported;

  /// Current step permission state; never prompts.
  Future<SensorAccess> checkStepAccess();

  /// Prompts if allowed, then returns the new state.
  Future<SensorAccess> requestStepAccess();

  /// Cumulative step counter readings (steps since last device boot).
  /// The counter can go backwards after a reboot; see `StepAggregator`.
  Stream<int> stepCounts();

  /// Accelerometer samples at roughly [samplingPeriod]. Cold stream: the
  /// sensor is registered on listen and released on cancel.
  Stream<AccelSample> accelerometer({
    Duration samplingPeriod = const Duration(milliseconds: 200),
  });

  /// Opens the app's system settings page (permanent denial recovery).
  Future<bool> openSettings();
}

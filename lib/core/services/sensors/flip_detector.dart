// ignore_for_file: prefer_initializing_formals
import 'dart:async';

import 'sensor_service.dart';

/// Reports whether the phone is lying face down, from accelerometer z.
///
/// Battery: the accelerometer is only subscribed while [watch] has a
/// listener. Cancel the listener (or leave the screen) and sampling stops;
/// nothing runs in the background.
///
/// With the device flat, gravity reads about +9.8 m/s^2 on z when face up
/// and -9.8 when face down. To avoid flicker:
/// * hysteresis: face-down needs `z <= -[downThreshold]`, face-up needs
///   `z >= -[upThreshold]` (default -7 / -4); values between hold the
///   previous reading;
/// * debounce: a new state is reported only after it has been continuously
///   observed for [debounce] (measured with sample timestamps, so the
///   behaviour is deterministic and testable without timers).
class FlipDetector {
  FlipDetector({
    required SensorService sensors,
    this.debounce = const Duration(milliseconds: 800),
    this.downThreshold = 7.0,
    this.upThreshold = 4.0,
    this.samplingPeriod = const Duration(milliseconds: 200),
  }) : _sensors = sensors,
       assert(downThreshold > upThreshold);

  final SensorService _sensors;
  final Duration debounce;
  final double downThreshold;
  final double upThreshold;

  /// Sampling interval; a slow rate is plenty for a flip.
  final Duration samplingPeriod;

  /// Emits `true` (face down) / `false` (not) whenever the debounced state
  /// changes. The first emission is the first state that held for
  /// [debounce]. Single-subscription semantics per call.
  Stream<bool> watch() {
    StreamSubscription<AccelSample>? sub;
    late final StreamController<bool> controller;

    bool? stable; // last emitted state
    bool? candidate;
    DateTime? candidateSince;

    controller = StreamController<bool>(
      sync: true,
      onListen: () {
        sub = _sensors
            .accelerometer(samplingPeriod: samplingPeriod)
            .listen(
              (s) {
                final bool? reading = s.z <= -downThreshold
                    ? true
                    : (s.z >= -upThreshold ? false : null);
                if (reading == null) return; // dead band: hold state
                if (reading != candidate) {
                  candidate = reading;
                  candidateSince = s.timestamp;
                }
                if (candidate != stable &&
                    candidateSince != null &&
                    s.timestamp.difference(candidateSince!) >= debounce) {
                  stable = candidate;
                  controller.add(stable!);
                }
              },
              onError: controller.addError,
              onDone: controller.close,
            );
      },
      onCancel: () async {
        await sub?.cancel();
        sub = null;
      },
    );
    return controller.stream;
  }
}

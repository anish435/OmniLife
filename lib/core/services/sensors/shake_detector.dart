// ignore_for_file: prefer_initializing_formals
import 'dart:async';
import 'dart:math' as math;

import 'sensor_service.dart';

/// Detects a double-shake gesture from accelerometer readings.
///
/// A "shake" occurs when total acceleration magnitude sqrt(x^2 + y^2 + z^2)
/// exceeds [shakeThreshold].
///
/// A "double-shake" requires:
/// 1. A first shake exceeding [shakeThreshold].
/// 2. A second shake occurring between [minShakeInterval] and [maxDoubleShakeInterval]
///    after the first shake.
/// 3. A [cooldown] period following detection so subsequent jitter does not
///    re-trigger immediately.
///
/// Battery friendly: accelerometer is only subscribed while [watchDoubleShake]
/// has a listener. Deterministic: intervals are measured via [AccelSample.timestamp].
class ShakeDetector {
  ShakeDetector({
    required SensorService sensors,
    this.shakeThreshold = 18.0,
    this.minShakeInterval = const Duration(milliseconds: 250),
    this.maxDoubleShakeInterval = const Duration(milliseconds: 1500),
    this.cooldown = const Duration(milliseconds: 1500),
    this.samplingPeriod = const Duration(milliseconds: 50),
  }) : _sensors = sensors,
       assert(shakeThreshold > 9.8),
       assert(maxDoubleShakeInterval > minShakeInterval);

  final SensorService _sensors;
  final double shakeThreshold;
  final Duration minShakeInterval;
  final Duration maxDoubleShakeInterval;
  final Duration cooldown;
  final Duration samplingPeriod;

  /// Emits whenever a double-shake gesture is detected.
  /// Cold stream: accelerometer is only registered on listen and released on cancel.
  Stream<void> watchDoubleShake() {
    StreamSubscription<AccelSample>? sub;
    late final StreamController<void> controller;

    DateTime? firstShakeTime;
    DateTime? lastTriggeredTime;

    controller = StreamController<void>(
      sync: true,
      onListen: () {
        sub = _sensors
            .accelerometer(samplingPeriod: samplingPeriod)
            .listen(
              (s) {
                final magnitude = math.sqrt(s.x * s.x + s.y * s.y + s.z * s.z);
                if (magnitude < shakeThreshold) return;

                final now = s.timestamp;

                // Cooldown check after previous successful trigger
                if (lastTriggeredTime != null &&
                    now.difference(lastTriggeredTime!) < cooldown) {
                  return;
                }

                if (firstShakeTime == null) {
                  firstShakeTime = now;
                } else {
                  final elapsed = now.difference(firstShakeTime!);
                  if (elapsed < minShakeInterval) {
                    // Ongoing continuation of the first shake; ignore
                    return;
                  }
                  if (elapsed <= maxDoubleShakeInterval) {
                    // Valid second shake within double-shake window
                    firstShakeTime = null;
                    lastTriggeredTime = now;
                    controller.add(null);
                  } else {
                    // Window expired; treat this as the new first shake
                    firstShakeTime = now;
                  }
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

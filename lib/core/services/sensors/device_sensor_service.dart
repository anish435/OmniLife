import 'package:flutter/foundation.dart';
import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart' as ph;
import 'package:sensors_plus/sensors_plus.dart';

import 'sensor_service.dart';

/// [SensorService] backed by `sensors_plus` (accelerometer), `pedometer`
/// (cumulative step counter) and `permission_handler` (ACTIVITY_RECOGNITION).
///
/// Supported on Android and iOS only. Web and desktop report
/// [SensorAccess.unsupported] and never touch a platform channel. This is a
/// thin plugin shim and is not unit tested; logic lives behind
/// [SensorService] and is tested with fakes.
class DeviceSensorService implements SensorService {
  const DeviceSensorService();

  @override
  bool get isSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  SensorAccess _map(ph.PermissionStatus s) {
    if (s.isGranted || s.isLimited) return SensorAccess.granted;
    if (s.isPermanentlyDenied || s.isRestricted) {
      return SensorAccess.deniedForever;
    }
    return SensorAccess.denied;
  }

  @override
  Future<SensorAccess> checkStepAccess() async {
    if (!isSupported) return SensorAccess.unsupported;
    try {
      return _map(await ph.Permission.activityRecognition.status);
    } catch (_) {
      return SensorAccess.unsupported;
    }
  }

  @override
  Future<SensorAccess> requestStepAccess() async {
    if (!isSupported) return SensorAccess.unsupported;
    try {
      return _map(await ph.Permission.activityRecognition.request());
    } catch (_) {
      return SensorAccess.unsupported;
    }
  }

  @override
  Stream<int> stepCounts() {
    if (!isSupported) return const Stream<int>.empty();
    return Pedometer.stepCountStream.map((e) => e.steps);
  }

  @override
  Stream<AccelSample> accelerometer({
    Duration samplingPeriod = const Duration(milliseconds: 200),
  }) {
    if (!isSupported) return const Stream<AccelSample>.empty();
    return accelerometerEventStream(
      samplingPeriod: samplingPeriod,
    ).map((e) => AccelSample(x: e.x, y: e.y, z: e.z, timestamp: e.timestamp));
  }

  @override
  Future<bool> openSettings() async {
    if (!isSupported) return false;
    try {
      return await ph.openAppSettings();
    } catch (_) {
      return false;
    }
  }
}

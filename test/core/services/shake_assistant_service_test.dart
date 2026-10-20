import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:omnilife/core/services/sensors/shake_assistant_service.dart';
import 'package:omnilife/core/services/sensors/shake_detector.dart';

import '../../support/location_sensor_fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeSensorService sensors;
  late ShakeDetector detector;
  late ShakeAssistantService service;

  setUp(() {
    Get.reset();
    sensors = FakeSensorService(supported: true);
    detector = ShakeDetector(sensors: sensors);
    service = ShakeAssistantService(sensors: sensors, detector: detector);
  });

  tearDown(() {
    service.onClose();
    Get.reset();
  });

  test('subscribes to accelerometer on supported devices', () {
    service.onInit();
    expect(sensors.accelListeners, 1);
  });

  test('does not subscribe when sensors are unsupported', () {
    final unsupportedSensors = FakeSensorService(supported: false);
    final unsupportedDetector = ShakeDetector(sensors: unsupportedSensors);
    final s = ShakeAssistantService(
      sensors: unsupportedSensors,
      detector: unsupportedDetector,
    );
    s.onInit();
    expect(unsupportedSensors.accelListeners, 0);
    s.onClose();
  });

  test('setEnabled(false) unsubscribes and suppresses triggers', () {
    service.onInit();
    expect(sensors.accelListeners, 1);

    service.setEnabled(false);
    expect(sensors.accelListeners, 0);
    expect(service.enabled.value, isFalse);

    service.setEnabled(true);
    expect(sensors.accelListeners, 1);
    expect(service.enabled.value, isTrue);
  });
}

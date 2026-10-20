// ignore_for_file: prefer_initializing_formals
import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../../../app/routes/app_routes.dart';
import '../../../presentation/controllers/assistant_controller.dart';
import '../../../presentation/widgets/assistant/voice_assistant_sheet.dart';
import 'sensor_service.dart';
import 'shake_detector.dart';

/// Service that monitors accelerometer data for a double-shake gesture
/// on mobile devices and summons the Voice Assistant popup.
class ShakeAssistantService extends GetxService with WidgetsBindingObserver {
  ShakeAssistantService({
    SensorService? sensors,
    ShakeDetector? detector,
  }) : _sensors = sensors,
       _detector = detector;

  SensorService? _sensors;
  ShakeDetector? _detector;

  SensorService get sensors => _sensors ??= Get.find<SensorService>();
  ShakeDetector get detector =>
      _detector ??= ShakeDetector(sensors: sensors);

  StreamSubscription<void>? _subscription;
  bool _isSheetOpen = false;
  final enabled = true.obs;

  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);
    _startListening();
  }

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopListening();
    super.onClose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Battery optimization: only sample accelerometer while app is in foreground
    if (state == AppLifecycleState.resumed) {
      _startListening();
    } else {
      _stopListening();
    }
  }

  void setEnabled(bool value) {
    enabled.value = value;
    if (value) {
      _startListening();
    } else {
      _stopListening();
    }
  }

  void _startListening() {
    if (!enabled.value || _subscription != null) return;
    if (!sensors.isSupported) return;

    _subscription = detector.watchDoubleShake().listen(
      (_) => onDoubleShake(),
      onError: (_) {},
    );
  }

  void _stopListening() {
    _subscription?.cancel();
    _subscription = null;
  }

  /// Triggered whenever a double shake is detected or programmatically invoked.
  void onDoubleShake() {
    if (!enabled.value) return;

    // If already on the full assistant page, start listening immediately
    if (Get.currentRoute == AppRoutes.assistant) {
      if (Get.isRegistered<AssistantController>()) {
        final c = Get.find<AssistantController>();
        if (c.status.value == AssistantStatus.idle) {
          c.startListening();
        }
      }
      return;
    }

    // Prevent stacking duplicate bottom sheets
    if (_isSheetOpen) return;

    final context = Get.context;
    if (context == null) return;

    _isSheetOpen = true;
    VoiceAssistantSheet.show(context).whenComplete(() {
      _isSheetOpen = false;
    });
  }

  /// Programmatic trigger for testing or demo actions.
  void triggerShake() => onDoubleShake();
}

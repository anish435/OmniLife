import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../config/telemetry_config.dart';
import '../services/analytics_service.dart';
import '../services/crash_reporter.dart';
import '../services/push_background.dart';

/// Wires Analytics, Crashlytics and the FCM background handler.
///
/// Safe to call when Firebase failed to initialize ([firebaseReady] false):
/// nothing is installed and the no-op services stay in place. Collection is
/// off in debug unless [kTelemetryInDebug] is set.
Future<void> initializeTelemetry({required bool firebaseReady}) async {
  if (!firebaseReady) return;

  final enabled = telemetryEnabled;

  try {
    await FirebaseAnalytics.instance.setAnalyticsCollectionEnabled(enabled);
    if (enabled) AnalyticsService.instance = FirebaseAnalyticsService();
  } catch (_) {}

  // Crashlytics has no web support: plain Flutter error handling stays.
  if (!kIsWeb) {
    try {
      await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(
        enabled,
      );
      if (enabled) {
        CrashReporter.instance = FirebaseCrashReporter();
        FlutterError.onError =
            FirebaseCrashlytics.instance.recordFlutterFatalError;
        PlatformDispatcher.instance.onError = (error, stack) {
          FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
          return true;
        };
      }
    } catch (_) {}

    try {
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    } catch (_) {}
  }
}

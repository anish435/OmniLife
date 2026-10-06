import 'package:flutter/foundation.dart';

/// Set to true to send Analytics/Crashlytics data from debug and profile
/// builds (for example while verifying DebugView). Release builds always
/// report.
const bool kTelemetryInDebug = false;

/// Whether analytics and crash collection are active in this build.
bool get telemetryEnabled => kReleaseMode || kTelemetryInDebug;

/// Optional Web Push VAPID key. Supplied at build time with
/// `--dart-define=FCM_VAPID_KEY=<public key>`; never hardcoded. Web push
/// stays disabled when it is empty.
const String kFcmVapidKey = String.fromEnvironment('FCM_VAPID_KEY');

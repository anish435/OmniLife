import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../../firebase_options.dart';

/// Initializes Firebase for the current platform.
///
/// This is intentionally kept separate from `main()`/UI code so startup
/// failures (e.g. missing native configuration) can be handled in one
/// place instead of crashing the whole app.
///
/// Returns `true` if Firebase initialized successfully, `false` otherwise.
Future<bool> initializeFirebase() async {
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    return true;
  } catch (error, stackTrace) {
    if (kDebugMode) debugPrint('Firebase initialization failed: $error');
    if (kDebugMode) debugPrintStack(stackTrace: stackTrace);
    return false;
  }
}

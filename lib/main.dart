import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'app/app.dart';
import 'core/bindings/pulse_bindings.dart';
import 'core/firebase/firebase_bootstrap.dart';
import 'core/firebase/telemetry_bootstrap.dart';
import 'presentation/bloc/app_bloc_observer.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final firebaseReady = await initializeFirebase();
  // Analytics, Crashlytics (mobile) and the FCM background handler.
  await initializeTelemetry(firebaseReady: firebaseReady);
  Bloc.observer = AppBlocObserver();
  runApp(const OmniLifeApp());
  // Bindings are created while the first frame builds; start uploads after.
  WidgetsBinding.instance.addPostFrameCallback((_) => startSyncEngine());
}

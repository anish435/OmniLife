import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'app/app.dart';
import 'core/bindings/pulse_bindings.dart';
import 'core/firebase/firebase_bootstrap.dart';
import 'presentation/bloc/app_bloc_observer.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeFirebase();
  Bloc.observer = AppBlocObserver();
  runApp(const OmniLifeApp());
  // Bindings are created while the first frame builds; start uploads after.
  WidgetsBinding.instance.addPostFrameCallback((_) => startSyncEngine());
}

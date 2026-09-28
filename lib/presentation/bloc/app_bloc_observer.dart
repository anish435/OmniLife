import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Foundation-only BLoC wiring, per docs/architecture.md §3 (BLoC owns
/// complex/remote feature state, e.g. AI conversation). No feature BLoCs
/// exist yet — this observer just gives every future BLoC consistent
/// debug logging for free, registered once via `Bloc.observer` in main().
class AppBlocObserver extends BlocObserver {
  @override
  void onError(BlocBase<dynamic> bloc, Object error, StackTrace stackTrace) {
    debugPrint('${bloc.runtimeType} error: $error');
    super.onError(bloc, error, stackTrace);
  }
}

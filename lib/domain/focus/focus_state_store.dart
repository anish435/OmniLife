import 'focus_timer.dart';

/// Persists the in-progress timer so it survives app restarts.
abstract class FocusStateStore {
  Future<FocusTimerState?> load(String userId);
  Future<void> save(String userId, FocusTimerState state);
  Future<void> clear(String userId);
}

class InMemoryFocusStateStore implements FocusStateStore {
  final _states = <String, FocusTimerState>{};

  @override
  Future<FocusTimerState?> load(String userId) async => _states[userId];

  @override
  Future<void> save(String userId, FocusTimerState state) async =>
      _states[userId] = state;

  @override
  Future<void> clear(String userId) async => _states.remove(userId);
}

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/focus/focus_state_store.dart';
import '../../domain/focus/focus_timer.dart';

/// Stores the in-progress timer snapshot in SharedPreferences, which works
/// on mobile and web (localStorage). One entry per user.
class SharedPrefsFocusStateStore implements FocusStateStore {
  static String _key(String userId) => 'focus_active_$userId';

  @override
  Future<FocusTimerState?> load(String userId) async {
    try {
      final raw = (await SharedPreferences.getInstance()).getString(
        _key(userId),
      );
      if (raw == null) return null;
      final json = jsonDecode(raw);
      if (json is! Map<String, dynamic>) return null;
      return FocusTimerState.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> save(String userId, FocusTimerState state) async {
    try {
      await (await SharedPreferences.getInstance()).setString(
        _key(userId),
        jsonEncode(state.toJson()),
      );
    } catch (_) {}
  }

  @override
  Future<void> clear(String userId) async {
    try {
      await (await SharedPreferences.getInstance()).remove(_key(userId));
    } catch (_) {}
  }
}

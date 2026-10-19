import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/insights/next_up.dart';

/// Keeps today's dismissed hints on the device. One small record per user;
/// a new day starts empty because the stored day no longer matches.
class PrefsNextUpStore implements NextUpStore {
  String _key(String userId) => 'next_up_v1_$userId';

  String _day(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  Future<Set<String>> load(String userId, DateTime day) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key(userId));
      if (raw == null) return {};
      final decoded = jsonDecode(raw);
      if (decoded is! Map || decoded['day'] != _day(day)) return {};
      final ids = decoded['ids'];
      return ids is List ? {for (final i in ids) '$i'} : {};
    } catch (_) {
      return {};
    }
  }

  @override
  Future<void> add(String userId, DateTime day, String id) async {
    try {
      final ids = await load(userId, day)
        ..add(id);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _key(userId),
        jsonEncode({'day': _day(day), 'ids': ids.toList()}),
      );
    } catch (_) {
      // Worst case the hint shows again; never a crash.
    }
  }
}

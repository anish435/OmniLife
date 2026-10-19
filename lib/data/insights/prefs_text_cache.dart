import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/insights/text_hash.dart';

/// Keeps written advice on the device, keyed by a hash of the data it was
/// written from. Small and capped; any storage problem just means a miss.
class PrefsTextCache implements TextCache {
  PrefsTextCache({this.maxEntries = 30});

  static const _key = 'advice_cache_v1';
  final int maxEntries;

  Future<Map<String, String>> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null) return {};
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return {};
      return {
        for (final e in decoded.entries)
          if (e.value is String) '${e.key}': e.value as String,
      };
    } catch (_) {
      return {};
    }
  }

  @override
  Future<String?> read(String key) async => (await _load())[key];

  @override
  Future<void> write(String key, String value) async {
    try {
      final all = await _load()
        ..remove(key)
        ..[key] = value;
      while (all.length > maxEntries) {
        all.remove(all.keys.first);
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, jsonEncode(all));
    } catch (_) {
      // Caching is a convenience.
    }
  }
}

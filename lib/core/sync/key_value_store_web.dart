import 'package:web/web.dart' as web;

import 'key_value_store.dart';

class _LocalStorageStore implements KeyValueStore {
  @override
  String? read(String key) {
    try {
      return web.window.localStorage.getItem(key);
    } catch (_) {
      return null;
    }
  }

  @override
  void write(String key, String value) {
    try {
      web.window.localStorage.setItem(key, value);
    } catch (_) {
      // Storage full or blocked (private mode): the engine keeps working
      // from memory for this session.
    }
  }
}

KeyValueStore createPlatformKeyValueStore() => _LocalStorageStore();

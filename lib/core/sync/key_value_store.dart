export 'key_value_store_stub.dart'
    if (dart.library.js_interop) 'key_value_store_web.dart';

/// Minimal synchronous string storage used for the web outbox.
abstract class KeyValueStore {
  String? read(String key);
  void write(String key, String value);
}

class MemoryKeyValueStore implements KeyValueStore {
  final Map<String, String> _values = {};

  @override
  String? read(String key) => _values[key];

  @override
  void write(String key, String value) => _values[key] = value;
}

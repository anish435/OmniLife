/// Small stable hash (FNV-1a, 32 bit) used as a cache key for advice. It is
/// not for security, only to tell "same data" from "different data".
String stableHash(String input) {
  var h = 0x811c9dc5;
  for (final unit in input.codeUnits) {
    h ^= unit;
    h = (h * 0x01000193) & 0xffffffff;
  }
  return h.toRadixString(16).padLeft(8, '0');
}

/// A tiny key/value text cache. Advice is cached by a hash of the data it
/// was written from, so the same data never costs a second model call.
abstract class TextCache {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
}

class InMemoryTextCache implements TextCache {
  final Map<String, String> store = {};

  @override
  Future<String?> read(String key) async => store[key];

  @override
  Future<void> write(String key, String value) async => store[key] = value;
}

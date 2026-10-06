import 'key_value_store.dart';

/// Non-web fallback (in-memory). Mobile uses the SQLite outbox instead.
KeyValueStore createPlatformKeyValueStore() => MemoryKeyValueStore();

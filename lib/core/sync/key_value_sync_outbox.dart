import 'dart:convert';

import 'key_value_store.dart';
import 'sync_operation.dart';
import 'sync_outbox.dart';

/// Outbox persisted as one JSON document in a [KeyValueStore]
/// (localStorage on web). Write volume is small (one entry per pending
/// document), so a single JSON blob is simple and safe.
class KeyValueSyncOutbox implements SyncOutbox {
  KeyValueSyncOutbox(this._store, {this.key = 'omnilife.sync_outbox'});

  final KeyValueStore _store;
  final String key;

  Map<String, SyncOperation> _load() {
    final raw = _store.read(key);
    if (raw == null || raw.isEmpty) return {};
    try {
      final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
      return {
        for (final m in list)
          (m['id'] as String): SyncOperation.fromMap(m.cast<String, Object?>()),
      };
    } catch (_) {
      return {};
    }
  }

  void _save(Map<String, SyncOperation> ops) {
    _store.write(key, jsonEncode(ops.values.map((o) => o.toMap()).toList()));
  }

  @override
  Future<void> upsert(SyncOperation op) async {
    final ops = _load()..[op.id] = op;
    _save(ops);
  }

  @override
  Future<void> remove(String id) async {
    final ops = _load()..remove(id);
    _save(ops);
  }

  @override
  Future<SyncOperation?> get(String id) async => _load()[id];

  @override
  Future<List<SyncOperation>> all() async {
    final list = _load().values.toList()
      ..sort((a, b) => a.createdAtMs.compareTo(b.createdAtMs));
    return list;
  }
}

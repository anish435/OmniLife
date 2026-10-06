import 'sync_operation.dart';

/// Durable storage for queued writes. Implementations: SQLite (mobile),
/// browser localStorage (web), memory (tests).
abstract class SyncOutbox {
  /// Inserts or replaces the operation with the same id (coalescing).
  Future<void> upsert(SyncOperation op);

  Future<void> remove(String id);

  Future<SyncOperation?> get(String id);

  /// Every operation, oldest first.
  Future<List<SyncOperation>> all();
}

class MemorySyncOutbox implements SyncOutbox {
  final Map<String, SyncOperation> _ops = {};

  @override
  Future<void> upsert(SyncOperation op) async => _ops[op.id] = op;

  @override
  Future<void> remove(String id) async => _ops.remove(id);

  @override
  Future<SyncOperation?> get(String id) async => _ops[id];

  @override
  Future<List<SyncOperation>> all() async {
    final list = _ops.values.toList()
      ..sort((a, b) => a.createdAtMs.compareTo(b.createdAtMs));
    return list;
  }
}

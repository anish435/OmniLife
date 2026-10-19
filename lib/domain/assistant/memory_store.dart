/// A small fact or exchange the assistant may want to recall later.
class MemoryEntry {
  const MemoryEntry({required this.text, required this.at});

  final String text;
  final DateTime at;

  Map<String, dynamic> toJson() => {'text': text, 'at': at.toIso8601String()};

  static MemoryEntry? fromJson(Object? json) {
    if (json is! Map) return null;
    final text = json['text'];
    final at = DateTime.tryParse('${json['at']}');
    if (text is! String || at == null) return null;
    return MemoryEntry(text: text, at: at);
  }
}

/// Long-term assistant memory. The default implementation keeps nothing;
/// a remote (MongoDB-backed) one is opt-in via `AI_MEMORY_URL`.
abstract class MemoryStore {
  Future<void> remember(String userId, MemoryEntry entry);

  /// The most recent entries, newest last.
  Future<List<MemoryEntry>> recall(String userId, {int limit = 3});
}

class NoopMemoryStore implements MemoryStore {
  const NoopMemoryStore();

  @override
  Future<void> remember(String userId, MemoryEntry entry) async {}

  @override
  Future<List<MemoryEntry>> recall(String userId, {int limit = 3}) async =>
      const [];
}

/// Keeps entries for the life of the process. Useful in tests.
class InMemoryMemoryStore implements MemoryStore {
  final Map<String, List<MemoryEntry>> _byUser = {};

  @override
  Future<void> remember(String userId, MemoryEntry entry) async {
    final list = _byUser.putIfAbsent(userId, () => []);
    list.add(entry);
    if (list.length > 50) list.removeAt(0);
  }

  @override
  Future<List<MemoryEntry>> recall(String userId, {int limit = 3}) async {
    final list = _byUser[userId] ?? const <MemoryEntry>[];
    return list.length <= limit ? [...list] : list.sublist(list.length - limit);
  }
}

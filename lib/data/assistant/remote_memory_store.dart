import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../domain/assistant/memory_store.dart';

/// Optional memory kept behind an HTTP endpoint (for example a small
/// service in front of MongoDB). Off unless `AI_MEMORY_URL` is defined.
///
/// Contract: `POST {url}/memory/{userId}` with `{text, at}` stores an entry;
/// `GET {url}/memory/{userId}?limit=n` returns `[{text, at}, ...]`.
/// Failures are swallowed: memory must never break a command.
class RemoteMemoryStore implements MemoryStore {
  RemoteMemoryStore(
    this.baseUrl, {
    http.Client? client,
    this.timeout = const Duration(seconds: 4),
  }) : _client = client ?? http.Client();

  final String baseUrl;
  final Duration timeout;
  final http.Client _client;

  Uri _uri(String userId, [Map<String, String>? query]) {
    final base = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    return Uri.parse('$base/memory/${Uri.encodeComponent(userId)}')
        .replace(queryParameters: query);
  }

  @override
  Future<void> remember(String userId, MemoryEntry entry) async {
    try {
      await _client
          .post(
            _uri(userId),
            headers: {'content-type': 'application/json'},
            body: jsonEncode(entry.toJson()),
          )
          .timeout(timeout);
    } catch (_) {}
  }

  @override
  Future<List<MemoryEntry>> recall(String userId, {int limit = 3}) async {
    try {
      final res = await _client
          .get(_uri(userId, {'limit': '$limit'}))
          .timeout(timeout);
      if (res.statusCode != 200) return const [];
      final data = jsonDecode(res.body);
      if (data is! List) return const [];
      return [for (final e in data) ?MemoryEntry.fromJson(e)];
    } catch (_) {
      return const [];
    }
  }
}

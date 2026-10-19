import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/assistant/chat_message.dart';

/// Where the chat thread is kept between launches (small, per user).
abstract class ChatHistoryStore {
  Future<List<ChatMessage>> load(String userId);
  Future<void> save(String userId, List<ChatMessage> messages);
  Future<void> clear(String userId);
}

class SharedPrefsChatHistoryStore implements ChatHistoryStore {
  SharedPrefsChatHistoryStore({this.maxMessages = 60});

  final int maxMessages;

  String _key(String userId) => 'assistant_history_v1_$userId';

  @override
  Future<List<ChatMessage>> load(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key(userId));
      if (raw == null) return const [];
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return [for (final m in decoded) ?ChatMessage.fromJson(m)];
    } catch (_) {
      return const [];
    }
  }

  @override
  Future<void> save(String userId, List<ChatMessage> messages) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final tail = messages.length > maxMessages
          ? messages.sublist(messages.length - maxMessages)
          : messages;
      await prefs.setString(
        _key(userId),
        jsonEncode([for (final m in tail) m.toJson()]),
      );
    } catch (_) {
      // History is a convenience; never fail a command because of it.
    }
  }

  @override
  Future<void> clear(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key(userId));
    } catch (_) {}
  }
}

class InMemoryChatHistoryStore implements ChatHistoryStore {
  final Map<String, List<ChatMessage>> data = {};

  @override
  Future<List<ChatMessage>> load(String userId) async => [...?data[userId]];

  @override
  Future<void> save(String userId, List<ChatMessage> messages) async {
    data[userId] = [...messages];
  }

  @override
  Future<void> clear(String userId) async => data.remove(userId);
}

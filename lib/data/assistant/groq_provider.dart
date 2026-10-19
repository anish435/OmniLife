import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../domain/assistant/ai_provider.dart';

/// Talks to Groq's OpenAI-compatible chat completions endpoint with tool
/// calling.
///
/// Free-tier aware: one request per call, a single retry when throttled
/// (honouring `retry-after` if it is short) or on a 5xx, and a friendly
/// message otherwise. No polling, no background traffic.
class GroqProvider implements AiProvider, TextCompleter {
  GroqProvider({
    required this.apiKey,
    http.Client? client,
    this.model = 'openai/gpt-oss-20b',
    this.adviceModel = 'openai/gpt-oss-120b',
    Uri? endpoint,
    this.temperature = 0.2,
    this.maxTokens = 400,
    this.timeout = const Duration(seconds: 25),
    this.maxRetryWait = const Duration(seconds: 20),
    Future<void> Function(Duration)? delay,
  }) : _client = client ?? http.Client(),
       _endpoint =
           endpoint ??
           Uri.parse('https://api.groq.com/openai/v1/chat/completions'),
       _delay = delay ?? Future<void>.delayed;

  final String apiKey;
  final String model;

  /// Written advice is one occasional call, so it gets the stronger model;
  /// tool calls stay on the fast one.
  final String adviceModel;
  final double temperature;
  final int maxTokens;
  final Duration timeout;
  final Duration maxRetryWait;
  final http.Client _client;
  final Uri _endpoint;
  final Future<void> Function(Duration) _delay;

  static const rateLimitMessage =
      'I\'ve hit the free usage limit for a moment. Try again in a minute.';

  @override
  bool get isConfigured => apiKey.trim().isNotEmpty;

  @override
  Future<AiResponse> chat({
    required List<AiMessage> messages,
    required List<AiToolSpec> tools,
  }) => _send(messages, tools, maxTokens, false);

  /// Plain completion for written advice: no tools, a caller-chosen token
  /// budget, and a low reasoning effort on models that think first so the
  /// budget is spent on the answer.
  @override
  Future<String?> complete({
    required List<AiMessage> messages,
    int maxTokens = 400,
  }) async {
    final r = await _send(messages, const [], maxTokens, true);
    return r.text;
  }

  Future<AiResponse> _send(
    List<AiMessage> messages,
    List<AiToolSpec> tools,
    int maxTokens,
    bool lowReasoning,
  ) async {
    if (!isConfigured) {
      throw const AiProviderException(
        AiFailureKind.notConfigured,
        'The assistant isn\'t set up yet.',
      );
    }
    final body = jsonEncode({
      'model': lowReasoning ? adviceModel : model,
      'temperature': lowReasoning ? 0.4 : temperature,
      'max_tokens': maxTokens,
      if (lowReasoning && adviceModel.contains('gpt-oss'))
        'reasoning_effort': 'low',
      'messages': [
        for (final m in messages) {'role': m.role.name, 'content': m.content},
      ],
      if (tools.isNotEmpty) ...{
        'tool_choice': 'auto',
        'tools': [
          for (final t in tools)
            {
              'type': 'function',
              'function': {
                'name': t.name,
                'description': t.description,
                'parameters': t.parameters,
              },
            },
        ],
      },
    });

    for (var attempt = 0; attempt < 2; attempt++) {
      final http.Response res;
      try {
        res = await _client
            .post(
              _endpoint,
              headers: {
                'authorization': 'Bearer $apiKey',
                'content-type': 'application/json',
              },
              body: body,
            )
            .timeout(timeout);
      } catch (_) {
        throw const AiProviderException(
          AiFailureKind.network,
          'I couldn\'t reach the assistant. Check your connection and try again.',
        );
      }

      final code = res.statusCode;
      if (code == 200) return _parse(res.body);

      if (code == 429) {
        final wait = _retryAfter(res) ?? const Duration(seconds: 2);
        if (attempt == 0 && wait <= maxRetryWait) {
          await _delay(wait);
          continue;
        }
        throw const AiProviderException(
          AiFailureKind.rateLimited,
          rateLimitMessage,
        );
      }
      if (code >= 500) {
        if (attempt == 0) {
          await _delay(const Duration(seconds: 1));
          continue;
        }
        throw const AiProviderException(
          AiFailureKind.server,
          'The assistant service is having trouble. Please try again in a bit.',
        );
      }
      if (code == 401 || code == 403) {
        throw const AiProviderException(
          AiFailureKind.unauthorized,
          'The assistant key doesn\'t seem to be valid. Please check it.',
        );
      }
      if (code == 400) {
        throw const AiProviderException(
          AiFailureKind.badRequest,
          'I didn\'t quite get that. Could you say it another way?',
        );
      }
      throw const AiProviderException(
        AiFailureKind.badResponse,
        'Something unexpected happened. Please try again.',
      );
    }
    // Unreachable: every loop path returns, continues once, or throws.
    throw const AiProviderException(
      AiFailureKind.badResponse,
      'Something unexpected happened. Please try again.',
    );
  }

  Duration? _retryAfter(http.Response res) {
    final raw = res.headers['retry-after'];
    if (raw == null) return null;
    final secs = double.tryParse(raw.trim());
    if (secs == null || secs < 0) return null;
    return Duration(milliseconds: (secs * 1000).round());
  }

  AiResponse _parse(String body) {
    try {
      final json = jsonDecode(body);
      final choices = (json as Map)['choices'] as List;
      final message = (choices.first as Map)['message'] as Map;
      final content = message['content'];
      final calls = <AiToolCall>[];
      final rawCalls = message['tool_calls'];
      if (rawCalls is List) {
        for (final c in rawCalls) {
          if (c is! Map) continue;
          final fn = c['function'];
          if (fn is! Map) continue;
          final name = fn['name'];
          if (name is! String || name.isEmpty) continue;
          final id = '${c['id'] ?? 'call_${calls.length}'}';
          final rawArgs = fn['arguments'];
          Map<String, dynamic> args = const {};
          String? error;
          if (rawArgs is Map) {
            args = Map<String, dynamic>.from(rawArgs);
          } else if (rawArgs is String && rawArgs.trim().isNotEmpty) {
            try {
              final decoded = jsonDecode(rawArgs);
              if (decoded is Map) {
                args = Map<String, dynamic>.from(decoded);
              } else {
                error = 'arguments were not an object';
              }
            } catch (_) {
              error = 'arguments were not valid JSON';
            }
          }
          calls.add(
            AiToolCall(
              id: id,
              name: name,
              arguments: args,
              argumentsError: error,
            ),
          );
        }
      }
      return AiResponse(
        text: content is String ? content : null,
        toolCalls: calls,
      );
    } catch (_) {
      throw const AiProviderException(
        AiFailureKind.badResponse,
        'I got a reply I couldn\'t understand. Please try again.',
      );
    }
  }
}

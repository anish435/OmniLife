import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:omnilife/core/config/assistant_config.dart';
import 'package:omnilife/data/assistant/groq_provider.dart';
import 'package:omnilife/domain/assistant/ai_provider.dart';

String _toolReply(String args) => jsonEncode({
  'choices': [
    {
      'message': {
        'role': 'assistant',
        'content': null,
        'tool_calls': [
          {
            'id': 'call_1',
            'type': 'function',
            'function': {'name': 'createReminder', 'arguments': args},
          },
        ],
      },
    },
  ],
});

const _msgs = [AiMessage(AiRole.user, 'remind me')];
const _tools = [
  AiToolSpec(
    name: 'createReminder',
    description: 'Set a reminder',
    parameters: {'type': 'object', 'properties': {}},
  ),
];

void main() {
  final waits = <Duration>[];

  GroqProvider provider(MockClient client, {String key = 'test-key'}) =>
      GroqProvider(
        apiKey: key,
        client: client,
        delay: (d) async => waits.add(d),
      );

  setUp(waits.clear);

  test(
    'sends model, low temperature, compact tools and the key header',
    () async {
      late http.Request seen;
      final p = provider(
        MockClient((req) async {
          seen = req;
          return http.Response(_toolReply('{"title":"x"}'), 200);
        }),
      );
      await p.chat(messages: _msgs, tools: _tools);

      expect(
        seen.url.toString(),
        'https://api.groq.com/openai/v1/chat/completions',
      );
      expect(seen.headers['authorization'], 'Bearer test-key');
      final body = jsonDecode(seen.body) as Map<String, dynamic>;
      expect(body['model'], 'openai/gpt-oss-20b');
      expect(body['temperature'], lessThanOrEqualTo(0.3));
      expect(body['tool_choice'], 'auto');
      expect(
        (body['tools'] as List).single['function']['name'],
        'createReminder',
      );
      expect(body['messages'], [
        {'role': 'user', 'content': 'remind me'},
      ]);
    },
  );

  test('parses tool calls and decodes JSON arguments', () async {
    final p = provider(
      MockClient(
        (_) async => http.Response(
          _toolReply('{"title":"Take tablets","at":"2026-10-19T21:00"}'),
          200,
        ),
      ),
    );
    final r = await p.chat(messages: _msgs, tools: _tools);
    expect(r.toolCalls, hasLength(1));
    final c = r.toolCalls.single;
    expect(c.name, 'createReminder');
    expect(c.arguments['title'], 'Take tablets');
    expect(c.argumentsError, isNull);
  });

  test('invalid JSON arguments are flagged, not thrown', () async {
    final p = provider(
      MockClient((_) async => http.Response(_toolReply('{oops'), 200)),
    );
    final r = await p.chat(messages: _msgs, tools: _tools);
    expect(r.toolCalls.single.argumentsError, isNotNull);
    expect(r.toolCalls.single.arguments, isEmpty);
  });

  test('plain text replies come back as text', () async {
    final p = provider(
      MockClient(
        (_) async => http.Response(
          jsonEncode({
            'choices': [
              {
                'message': {'content': 'Hi!'},
              },
            ],
          }),
          200,
        ),
      ),
    );
    final r = await p.chat(messages: _msgs, tools: _tools);
    expect(r.text, 'Hi!');
    expect(r.toolCalls, isEmpty);
  });

  test('429 retries once, waiting for retry-after, then succeeds', () async {
    var calls = 0;
    final p = provider(
      MockClient((_) async {
        calls++;
        if (calls == 1) {
          return http.Response('{}', 429, headers: {'retry-after': '3'});
        }
        return http.Response(_toolReply('{}'), 200);
      }),
    );
    final r = await p.chat(messages: _msgs, tools: _tools);
    expect(calls, 2);
    expect(waits, [const Duration(seconds: 3)]);
    expect(r.toolCalls, hasLength(1));
  });

  test(
    '429 twice gives the friendly message after exactly one retry',
    () async {
      var calls = 0;
      final p = provider(
        MockClient((_) async {
          calls++;
          return http.Response('{}', 429, headers: {'retry-after': '2'});
        }),
      );
      await expectLater(
        p.chat(messages: _msgs, tools: _tools),
        throwsA(
          isA<AiProviderException>()
              .having((e) => e.kind, 'kind', AiFailureKind.rateLimited)
              .having(
                (e) => e.message,
                'message',
                contains('free usage limit'),
              ),
        ),
      );
      expect(calls, 2);
    },
  );

  test('a long retry-after is not waited out; no retry', () async {
    var calls = 0;
    final p = provider(
      MockClient((_) async {
        calls++;
        return http.Response('{}', 429, headers: {'retry-after': '120'});
      }),
    );
    await expectLater(
      p.chat(messages: _msgs, tools: _tools),
      throwsA(
        isA<AiProviderException>().having(
          (e) => e.message,
          'message',
          'I\'ve hit the free usage limit for a moment. Try again in a minute.',
        ),
      ),
    );
    expect(calls, 1);
    expect(waits, isEmpty);
  });

  test('5xx retries once then reports a friendly server error', () async {
    var calls = 0;
    final p = provider(
      MockClient((_) async {
        calls++;
        return http.Response('boom', 503);
      }),
    );
    await expectLater(
      p.chat(messages: _msgs, tools: _tools),
      throwsA(
        isA<AiProviderException>().having(
          (e) => e.kind,
          'kind',
          AiFailureKind.server,
        ),
      ),
    );
    expect(calls, 2);
  });

  test('401 is reported as a key problem without retrying', () async {
    var calls = 0;
    final p = provider(
      MockClient((_) async {
        calls++;
        return http.Response('{}', 401);
      }),
    );
    await expectLater(
      p.chat(messages: _msgs, tools: _tools),
      throwsA(
        isA<AiProviderException>().having(
          (e) => e.kind,
          'kind',
          AiFailureKind.unauthorized,
        ),
      ),
    );
    expect(calls, 1);
  });

  test('network errors become a friendly message', () async {
    final p = provider(
      MockClient((_) async => throw http.ClientException('offline')),
    );
    await expectLater(
      p.chat(messages: _msgs, tools: _tools),
      throwsA(
        isA<AiProviderException>().having(
          (e) => e.kind,
          'kind',
          AiFailureKind.network,
        ),
      ),
    );
  });

  test('a garbled 200 body is a bad-response error, not a crash', () async {
    final p = provider(MockClient((_) async => http.Response('not json', 200)));
    await expectLater(
      p.chat(messages: _msgs, tools: _tools),
      throwsA(
        isA<AiProviderException>().having(
          (e) => e.kind,
          'kind',
          AiFailureKind.badResponse,
        ),
      ),
    );
  });

  test('missing key is notConfigured and makes no request', () async {
    var calls = 0;
    final p = provider(
      MockClient((_) async {
        calls++;
        return http.Response('{}', 200);
      }),
      key: '  ',
    );
    expect(p.isConfigured, isFalse);
    await expectLater(
      p.chat(messages: _msgs, tools: _tools),
      throwsA(
        isA<AiProviderException>().having(
          (e) => e.kind,
          'kind',
          AiFailureKind.notConfigured,
        ),
      ),
    );
    expect(calls, 0);
  });

  test('config: key presence drives isConfigured; defaults are safe', () {
    expect(const AssistantConfig().isConfigured, isFalse);
    expect(const AssistantConfig(groqApiKey: 'k').isConfigured, isTrue);
    expect(const AssistantConfig().hasRemoteMemory, isFalse);
    expect(const AssistantConfig().model, 'openai/gpt-oss-20b');
    // No key is baked into the test build.
    expect(AssistantConfig.fromEnvironment().isConfigured, isFalse);
  });
}

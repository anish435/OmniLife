import 'package:flutter_test/flutter_test.dart';
import 'package:omnilife/domain/assistant/ai_provider.dart';
import 'package:omnilife/domain/assistant/assistant_engine.dart';

void main() {
  test('entries in one logPulse call become one call per fact', () {
    final out = AssistantEngine.expandEntries([
      const AiToolCall(
        id: 'a',
        name: 'logPulse',
        arguments: {
          'entries': [
            {'kind': 'water', 'ml': 2000, 'period': 'morning'},
            {'kind': 'sleep', 'hours': 3},
          ],
        },
      ),
    ]);

    expect(out, hasLength(2));
    expect(out[0].arguments['kind'], 'water');
    expect(out[1].arguments['hours'], 3);
    expect(out.map((c) => c.id).toSet(), hasLength(2));
  });

  test('other calls and flat logPulse calls pass through untouched', () {
    const flat = AiToolCall(
      id: 'b',
      name: 'logPulse',
      arguments: {'kind': 'water', 'ml': 250},
    );
    const other = AiToolCall(id: 'c', name: 'createTask', arguments: {});

    expect(AssistantEngine.expandEntries([flat, other]), [flat, other]);
  });
}

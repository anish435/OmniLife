import 'package:flutter_test/flutter_test.dart';
import 'package:omnilife/domain/assistant/ai_provider.dart';
import 'package:omnilife/domain/assistant/assistant_engine.dart';
import 'package:omnilife/domain/assistant/assistant_tool.dart';
import 'package:omnilife/domain/assistant/reminder_time.dart';
import 'package:omnilife/domain/assistant/tool_args.dart';

class MockAiProvider implements AiProvider {
  MockAiProvider(this.response);
  final AiResponse response;
  @override
  bool get isConfigured => true;
  @override
  Future<AiResponse> chat({
    required List<AiMessage> messages,
    required List<AiToolSpec> tools,
  }) async => response;
}

class MockFinanceTool extends AssistantTool {
  final List<Map<String, dynamic>> logged = [];
  @override
  String get name => 'addTransaction';
  @override
  String get description => 'Add transaction';
  @override
  Map<String, dynamic> get parameters => {'type': 'object'};
  @override
  Future<ToolOutcome> run(ToolArgs args, ToolContext ctx) async {
    logged.add(args.raw);
    final isInc = args.boolean('income') ?? false;
    final amt = args.number('amount') ?? 0;
    return ToolOutcome.done(
      label: '${isInc ? 'Income' : 'Expense'} added: $amt',
      spoken: isInc ? "I've recorded $amt as income." : "I've recorded a $amt expense.",
    );
  }
}

void main() {
  test('Compound finance command generates both entries and Net calculation', () async {
    final tool = MockFinanceTool();
    final registry = ToolRegistry([tool]);
    
    // Simulate what Groq outputs when asked "I received 2500 and spent 500"
    final mockProvider = MockAiProvider(
      AiResponse(
        text: 'I will record both transactions.',
        toolCalls: [
          AiToolCall(
            id: 'call_1',
            name: 'addTransaction',
            arguments: {
              'entries': [
                {'amount': 2500.0, 'income': true, 'title': 'Income'},
                {'amount': 500.0, 'income': false, 'title': 'Expense'},
              ]
            },
          ),
        ],
      ),
    );

    final engine = AssistantEngine(
      provider: mockProvider,
      tools: registry,
      now: () => DateTime(2026, 10, 20, 22, 0),
    );

    final turn = await engine.handle('I received 2500 and spent 500');
    
    expect(turn.outcomes.length, 2);
    expect(tool.logged.length, 2);
    expect(tool.logged[0]['amount'], 2500.0);
    expect(tool.logged[0]['income'], true);
    expect(tool.logged[1]['amount'], 500.0);
    expect(tool.logged[1]['income'], false);
    
    expect(turn.reply, contains('Net: +2,000'));
    expect(turn.reply, contains("I've recorded 2500.0 as income"));
    expect(turn.reply, contains("I've recorded a 500.0 expense"));
  });

  test('Fallback deterministic extraction triggers if provider returns no tool calls', () async {
    final tool = MockFinanceTool();
    final registry = ToolRegistry([tool]);
    
    final mockProvider = MockAiProvider(
      AiResponse(text: 'Sure, I got you.', toolCalls: []),
    );

    final engine = AssistantEngine(
      provider: mockProvider,
      tools: registry,
      now: () => DateTime(2026, 10, 20, 22, 0),
    );

    final turn = await engine.handle('I received 2500 and spent 500');
    
    expect(turn.outcomes.length, 2);
    expect(tool.logged.length, 2);
    expect(turn.reply, contains('Net: +2,000'));
  });

  test('ReminderTimeResolver correctly extracts 9pm and 11:30 clock times', () {
    final now = DateTime(2026, 10, 20, 10, 0);
    final resolver = ReminderTimeResolver(now);
    
    final r1 = resolver.resolve(utterance: 'remind me to check server at 9pm');
    expect(r1.at.hour, 21);
    expect(r1.at.minute, 0);

    final r2 = resolver.resolve(utterance: 'remind me to call pharmacy at 11:30');
    expect(r2.at.hour, 11);
    expect(r2.at.minute, 30);
  });
}

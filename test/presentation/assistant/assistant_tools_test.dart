import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:omnilife/domain/assistant/ai_provider.dart';
import 'package:omnilife/domain/assistant/assistant_engine.dart';
import 'package:omnilife/domain/assistant/assistant_tool.dart';
import 'package:omnilife/domain/assistant/tool_args.dart';
import 'package:omnilife/domain/entities/finance_transaction.dart';
import 'package:omnilife/domain/entities/life_event.dart';
import 'package:omnilife/domain/entities/reminder.dart';

import '../../support/assistant_fakes.dart';

void main() {
  tearDown(Get.reset);

  Future<AssistantHarness> harness(
    AiResponse Function(String) script, {
    DateTime? now,
    bool withReminders = true,
  }) => AssistantHarness.create(
    script: script,
    now: now,
    withReminders: withReminders,
  );

  group('reminders', () {
    test(
      '"remind me to take tablets tonight" sets one 9 PM reminder',
      () async {
        final h = await harness(
          (_) => calls([
            // The model guesses 20:00; house rules say tonight is 9 PM.
            call('createReminder', {
              'title': 'Take tablets',
              'at': '2026-10-19T20:00',
              'repeat': 'none',
            }),
          ]),
        );
        final turn = await h.engine.handle('remind me to take tablets tonight');

        expect(h.reminders.store, hasLength(1));
        final r = h.reminders.store.single;
        expect(r.title, 'Take tablets');
        expect(r.scheduledAt, DateTime(2026, 10, 19, 21));
        expect(r.repeat, ReminderRepeat.none);
        expect(turn.reply, 'Done. I\'ve set a reminder for 9 PM tonight.');
        expect(
          turn.outcomes.single.label,
          'Reminder set: Take tablets, today 9:00 PM',
        );
        // One model request for the whole command.
        expect(h.provider.requests, hasLength(1));
      },
    );

    test('"remind me daily at 8 to take vitamins" repeats daily', () async {
      final h = await harness(
        (_) => calls([
          call('createReminder', {
            'title': 'Take vitamins',
            'at': '2026-10-19T08:00',
          }),
        ]),
        now: DateTime(2026, 10, 19, 7),
      );
      await h.engine.handle('remind me daily at 8 to take vitamins');
      final r = h.reminders.store.single;
      expect(r.repeat, ReminderRepeat.daily);
      expect(r.scheduledAt, DateTime(2026, 10, 19, 8));
    });

    test('undo removes the reminder', () async {
      final h = await harness(
        (_) => calls([
          call('createReminder', {
            'title': 'Call mum',
            'at': '2026-10-19T18:00',
          }),
        ]),
      );
      final turn = await h.engine.handle('remind me at 6 to call mum');
      expect(h.reminders.store, hasLength(1));
      await turn.outcomes.single.undo!();
      expect(h.reminders.store, isEmpty);
    });

    test('missing time asks a question and creates nothing', () async {
      final h = await harness(
        (_) => calls([
          call('createReminder', {'title': 'Pay rent'}),
        ]),
      );
      final turn = await h.engine.handle('remind me to pay rent');
      expect(turn.outcomes.single.status, ToolStatus.question);
      expect(turn.reply, contains('What time'));
      expect(h.reminders.store, isEmpty);
    });

    test('works only once the ReminderService exists', () async {
      final h = await harness(
        (_) => calls([
          call('createReminder', {'title': 'x', 'at': '2026-10-19T18:00'}),
        ]),
        withReminders: false,
      );
      final turn = await h.engine.handle('remind me at 6');
      expect(turn.outcomes.single.status, ToolStatus.failed);
      expect(turn.reply, contains('Reminders aren\'t available'));
    });
  });

  group('finance', () {
    test('"I paid 200 to alex today" records a 200 expense', () async {
      final h = await harness(
        (_) => calls([
          call('addTransaction', {
            'amount': 200,
            'title': 'Paid Alex',
            'category': 'other',
            'income': false,
            'date': '2026-10-19',
          }),
        ]),
      );
      final turn = await h.engine.handle('I paid 200 to alex today');

      expect(h.financeRepo.store, hasLength(1));
      final t = h.financeRepo.store.values.single;
      expect(t.amount, 200);
      expect(t.title, 'Paid Alex');
      expect(t.isIncome, isFalse);
      expect(t.category, TransactionCategory.other);
      expect(t.date.day, 19);
      expect(turn.reply, 'Done. I\'ve recorded a 200 expense.');

      await turn.outcomes.single.undo!();
      expect(h.financeRepo.store, isEmpty);
    });

    test('received/salary wording records income', () async {
      final h = await harness(
        (_) => calls([
          call('addTransaction', {'amount': '5,000', 'title': 'Salary'}),
        ]),
      );
      await h.engine.handle('I received my salary of 5000');
      final t = h.financeRepo.store.values.single;
      expect(t.isIncome, isTrue);
      expect(t.amount, 5000);
      expect(t.category, TransactionCategory.income);
    });

    test('multi-command: received 2500 and spent 500 records both and reports net', () async {
      final h = await harness(
        (_) => calls([
          call('addTransaction', {'amount': 2500, 'title': 'Received', 'income': true}),
          call('addTransaction', {'amount': 500, 'title': 'Spent', 'income': false}),
        ]),
      );
      final turn = await h.engine.handle('I received 2500 and spent 500');
      expect(h.financeRepo.store, hasLength(2));
      final items = h.financeRepo.store.values.toList();
      final inc = items.firstWhere((t) => t.isIncome);
      final exp = items.firstWhere((t) => !t.isIncome);
      expect(inc.amount, 2500);
      expect(exp.amount, 500);
      expect(turn.reply, contains('2,500 as income'));
      expect(turn.reply, contains('500 expense'));
      expect(turn.reply, contains('Net: +2,000'));
    });

    test('multi-command auto-completes missing side if model only called one', () async {
      final h = await harness(
        (_) => calls([
          call('addTransaction', {'amount': 2500, 'title': 'Received', 'income': true}),
        ]),
      );
      final turn = await h.engine.handle('i recieved 2500 and spent 500');
      expect(h.financeRepo.store, hasLength(2));
      final items = h.financeRepo.store.values.toList();
      final inc = items.firstWhere((t) => t.isIncome);
      final exp = items.firstWhere((t) => !t.isIncome);
      expect(inc.amount, 2500);
      expect(exp.amount, 500);
      expect(turn.reply, contains('Net: +2,000'));
    });

    test('invalid amounts never reach the repository', () async {
      for (final bad in ['abc', -5, 0, 1e12]) {
        final h = await harness(
          (_) => calls([
            call('addTransaction', {'amount': bad, 'title': 'x'}),
          ]),
        );
        final turn = await h.engine.handle('I paid something');
        expect(turn.outcomes.single.status, ToolStatus.failed, reason: '$bad');
        expect(h.financeRepo.store, isEmpty, reason: '$bad');
      }
    });

    test('missing amount asks how much', () async {
      final h = await harness(
        (_) => calls([
          call('addTransaction', {'title': 'Lunch'}),
        ]),
      );
      final turn = await h.engine.handle('I bought lunch');
      expect(turn.reply, 'How much was it?');
    });

    test('spending summary reads the repository', () async {
      final h = await harness(
        (_) => calls([
          call('getSpendingSummary', {'period': 'month'}),
        ]),
      );
      await h.finance.addTransaction(
        amount: 600,
        title: 'Groceries',
        category: TransactionCategory.food,
        date: DateTime(2026, 10, 3),
        isIncome: false,
      );
      await h.finance.addTransaction(
        amount: 100,
        title: 'Bus',
        category: TransactionCategory.transport,
        date: DateTime(2026, 10, 4),
        isIncome: false,
      );
      final turn = await h.engine.handle('how much did I spend this month');
      expect(turn.reply, contains('700'));
      expect(turn.reply, contains('food (600)'));
    });
  });

  group('tasks, notes, events, habits, pulse', () {
    test('createTask then undo deletes it', () async {
      final h = await harness(
        (_) => calls([
          call('createTask', {
            'title': 'Call the bank',
            'due': '2026-10-20',
            'priority': 'high',
          }),
        ]),
      );
      final turn = await h.engine.handle(
        'add a task to call the bank tomorrow',
      );
      expect(h.taskRepo.storage.single.title, 'Call the bank');
      expect(h.tasks.tasks.single.priority.name, 'high');
      expect(
        turn.outcomes.single.label,
        'Task added: Call the bank, due tomorrow',
      );
      await turn.outcomes.single.undo!();
      expect(h.taskRepo.storage, isEmpty);
    });

    test('completeTask finds the task by title and can be undone', () async {
      final h = await harness(
        (_) => calls([
          call('completeTask', {'title': 'bank'}),
        ]),
      );
      await h.tasks.createTask(title: 'Call the bank');
      await _tick();
      await h.tasks.createTask(title: 'Buy milk');
      final turn = await h.engine.handle('I called the bank');
      expect(
        h.tasks.tasks.firstWhere((t) => t.title == 'Call the bank').completed,
        isTrue,
      );
      await turn.outcomes.single.undo!();
      expect(
        h.tasks.tasks.firstWhere((t) => t.title == 'Call the bank').completed,
        isFalse,
      );
    });

    test('ambiguous task asks which one', () async {
      final h = await harness(
        (_) => calls([
          call('completeTask', {'title': 'call'}),
        ]),
      );
      await h.tasks.createTask(title: 'Call the bank');
      await _tick();
      await h.tasks.createTask(title: 'Call mum');
      final turn = await h.engine.handle('I made the call');
      expect(turn.outcomes.single.status, ToolStatus.question);
      expect(turn.reply, contains('Which task'));
      expect(h.tasks.tasks.where((t) => t.completed), isEmpty);
    });

    test('createCalendarEvent defaults to one hour; undo deletes', () async {
      final h = await harness(
        (_) => calls([
          call('createCalendarEvent', {
            'title': 'Dentist',
            'start': '2026-10-20T15:00',
          }),
        ]),
      );
      final turn = await h.engine.handle('dentist tomorrow at 3');
      final e = h.calendarRepo.storage.single;
      expect(e.startAt, DateTime(2026, 10, 20, 15));
      expect(e.endAt, DateTime(2026, 10, 20, 16));
      expect(turn.reply, contains('3 PM tomorrow'));
      await turn.outcomes.single.undo!();
      expect(h.calendarRepo.storage, isEmpty);
    });

    test('createNote saves and undo deletes', () async {
      final h = await harness(
        (_) => calls([
          call('createNote', {'content': 'Wifi password is on the fridge'}),
        ]),
      );
      final turn = await h.engine.handle(
        'note that the wifi password is on the fridge',
      );
      expect(h.noteRepo.storage.values.single.content, contains('fridge'));
      await turn.outcomes.single.undo!();
      expect(h.noteRepo.storage, isEmpty);
    });

    test('toggleHabit ticks today once and undo clears it', () async {
      final h = await harness(
        (_) => calls([
          call('toggleHabit', {'name': 'read'}),
        ]),
      );
      final habit = (await h.habits.createHabit(title: 'Read'))!;
      final turn = await h.engine.handle('I read today');
      expect(h.habits.isHabitCompleted(habit.id, h.now), isTrue);

      // Asking again does not untick it.
      final again = await h.engine.handle('I read today');
      expect(again.outcomes.single.isInfo, isTrue);
      expect(h.habits.isHabitCompleted(habit.id, h.now), isTrue);

      await turn.outcomes.single.undo!();
      expect(h.habits.isHabitCompleted(habit.id, h.now), isFalse);
    });

    test('logPulse water records and undo removes', () async {
      final h = await harness(
        (_) => calls([
          call('logPulse', {'kind': 'water', 'value': 500}),
        ]),
      );
      final turn = await h.engine.handle('I drank 500 ml of water');
      final e = h.lifeEvents.events.values.single;
      expect(e.type, LifeEventType.water);
      expect(e.metadata['ml'], 500);
      await turn.outcomes.single.undo!();
      expect(h.lifeEvents.events, isEmpty);
    });

    test('logPulse mood without a score asks, bad score is rejected', () async {
      var args = <String, dynamic>{'kind': 'mood'};
      final h = await harness((_) => calls([call('logPulse', args)]));
      var turn = await h.engine.handle('log my mood');
      expect(turn.outcomes.single.status, ToolStatus.question);

      args = {'kind': 'mood', 'value': 9};
      turn = await h.engine.handle('mood 9');
      expect(turn.outcomes.single.status, ToolStatus.failed);
      expect(h.lifeEvents.events, isEmpty);

      args = {'kind': 'mood', 'value': '4'};
      turn = await h.engine.handle('mood 4');
      expect(h.lifeEvents.events.values.single.moodScore, 4);
    });

    test('listTasksToday reads today\'s open tasks', () async {
      final h = await harness((_) => calls([call('listTasksToday', {})]));
      await h.tasks.createTask(title: 'Buy milk');
      final turn = await h.engine.handle('what do I have today');
      expect(turn.reply, 'You have 1 task today: Buy milk.');
      expect(turn.outcomes.single.isInfo, isTrue);
    });
  });

  group('safety', () {
    test('delete never happens without confirmation', () async {
      final h = await harness(
        (_) => calls([
          call('deleteItem', {'kind': 'task', 'title': 'Buy milk'}),
        ]),
      );
      await h.tasks.createTask(title: 'Buy milk');
      final turn = await h.engine.handle('delete my buy milk task');

      final o = turn.outcomes.single;
      expect(o.status, ToolStatus.confirm);
      expect(o.isWrite, isFalse);
      expect(h.taskRepo.storage, hasLength(1), reason: 'nothing deleted yet');
      expect(turn.reply, contains('Delete the task "Buy milk"?'));

      final result = await o.onConfirm!();
      expect(result.status, ToolStatus.done);
      expect(h.taskRepo.storage, isEmpty);
    });

    test('deleting a reminder is also confirmed first', () async {
      final h = await harness(
        (_) => calls([
          call('deleteItem', {'kind': 'reminder', 'title': 'tablets'}),
        ]),
      );
      await h.reminders.create(
        title: 'Take tablets',
        at: DateTime(2026, 10, 19, 21),
      );
      final turn = await h.engine.handle('delete the tablets reminder');
      expect(turn.outcomes.single.status, ToolStatus.confirm);
      expect(h.reminders.store, hasLength(1));
      await turn.outcomes.single.onConfirm!();
      expect(h.reminders.store, isEmpty);
    });

    test('unknown tool is a friendly failure', () async {
      final h = await harness((_) => calls([call('launchRocket', {})]));
      final turn = await h.engine.handle('do something');
      expect(turn.outcomes.single.status, ToolStatus.failed);
      expect(turn.reply, 'I can\'t do that one yet.');
    });

    test('malformed arguments never crash', () async {
      final h = await harness(
        (_) => const AiResponse(
          toolCalls: [
            AiToolCall(id: '1', name: 'createTask', argumentsError: 'not json'),
          ],
        ),
      );
      final turn = await h.engine.handle('add a task');
      expect(turn.outcomes.single.status, ToolStatus.failed);
      expect(turn.reply, contains('say it again'));
    });

    test('wrong argument types fail politely', () async {
      for (final args in <Map<String, dynamic>>[
        {'title': 42, 'due': 'not a date'},
        {
          'title': {'a': 1},
        },
        {'title': 'x', 'due': '1850-01-01'},
        {'title': 'x' * 500},
        <String, dynamic>{},
      ]) {
        final h = await harness((_) => calls([call('createTask', args)]));
        final turn = await h.engine.handle('add task');
        expect(turn.outcomes.single.status, ToolStatus.failed, reason: '$args');
        expect(h.taskRepo.storage, isEmpty, reason: '$args');
      }
    });

    test('a tool that throws is contained', () async {
      final h = await harness((_) => calls([call('boom', {})]));
      final engine = AssistantEngine(
        provider: h.provider,
        tools: ToolRegistry([_ThrowingTool()]),
        now: () => h.now,
      );
      final turn = await engine.handle('go');
      expect(turn.outcomes.single.status, ToolStatus.failed);
      expect(turn.reply, contains('Something went wrong'));
    });

    test('plain chat with no tool call returns the text', () async {
      final h = await harness((_) => const AiResponse(text: 'Hello there.'));
      final turn = await h.engine.handle('hi');
      expect(turn.reply, 'Hello there.');
      expect(turn.outcomes, isEmpty);
    });
  });

  group('prompt and history', () {
    test('system prompt carries date, weekday and timezone', () async {
      final h = await harness((_) => const AiResponse(text: 'ok'));
      await h.engine.handle('hi');
      final system = h.provider.requests.single.first;
      expect(system.role, AiRole.system);
      expect(system.content, contains('Monday 2026-10-19 14:05'));
      expect(system.content, contains('UTC'));
    });

    test('only the last twelve history messages are sent', () async {
      final h = await harness((_) => const AiResponse(text: 'ok'));
      final history = [
        for (var i = 0; i < 30; i++)
          AiMessage(i.isEven ? AiRole.user : AiRole.assistant, 'm$i'),
      ];
      await h.engine.handle('now', history: history);
      final sent = h.provider.requests.single;
      // system + 12 history + the new user message
      expect(sent, hasLength(14));
      expect(sent[1].content, 'm18');
      expect(sent.last.content, 'now');
    });

    test('model failures become friendly replies, not exceptions', () async {
      final h = await harness((_) => const AiResponse());
      final engine = AssistantEngine(
        provider: _FailingProvider(),
        tools: ToolRegistry(const []),
      );
      final turn = await engine.handle('hi');
      expect(turn.failure, AiFailureKind.rateLimited);
      expect(turn.reply, contains('free usage limit'));
      expect(h.provider.requests, isEmpty);
    });
  });
}

/// TaskController derives ids from the clock; keep two creates apart.
Future<void> _tick() => Future<void>.delayed(const Duration(milliseconds: 3));

class _FailingProvider implements AiProvider {
  @override
  bool get isConfigured => true;

  @override
  Future<AiResponse> chat({
    required List<AiMessage> messages,
    required List<AiToolSpec> tools,
  }) async => throw const AiProviderException(
    AiFailureKind.rateLimited,
    'I\'ve hit the free usage limit for a moment. Try again in a minute.',
  );
}

class _ThrowingTool extends AssistantTool {
  @override
  String get name => 'boom';
  @override
  String get description => 'throws';
  @override
  Map<String, dynamic> get parameters => const {};
  @override
  Future<ToolOutcome> run(ToolArgs args, ToolContext context) =>
      throw StateError('boom');
}

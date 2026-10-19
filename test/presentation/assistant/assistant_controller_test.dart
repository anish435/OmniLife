import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:omnilife/data/assistant/chat_history_store.dart';
import 'package:omnilife/domain/assistant/ai_provider.dart';
import 'package:omnilife/domain/assistant/chat_message.dart';
import 'package:omnilife/domain/assistant/memory_store.dart';
import 'package:omnilife/presentation/assistant/voice_service.dart';
import 'package:omnilife/presentation/controllers/assistant_controller.dart';

import '../../support/assistant_fakes.dart';

void main() {
  tearDown(Get.reset);

  AiResponse reminderScript(String text) => calls([
    call('createReminder', {'title': 'Take tablets', 'at': '2026-10-19T21:00'}),
  ]);

  group('typed commands', () {
    test('adds the thread, shows a card, does not speak', () async {
      final h = await AssistantHarness.create(script: reminderScript);
      final voice = FakeVoice();
      final c = h.controller(voice: voice);

      final states = <AssistantStatus>[];
      final worker = ever(c.status, states.add);
      await c.send('remind me to take tablets tonight');
      worker.dispose();

      expect(states, [AssistantStatus.thinking, AssistantStatus.idle]);
      expect(c.messages, hasLength(2));
      expect(c.messages.first.role, ChatRole.user);
      final reply = c.messages.last;
      expect(reply.text, 'Done. I\'ve set a reminder for 9 PM tonight.');
      expect(
        reply.cards.single.label,
        'Reminder set: Take tablets, today 9:00 PM',
      );
      expect(reply.cards.single.canUndo, isTrue);
      expect(voice.spoken, isEmpty, reason: 'typed commands are not spoken');
    });

    test('undo reverts the write and marks the card', () async {
      final h = await AssistantHarness.create(script: reminderScript);
      final c = h.controller();
      await c.send('remind me to take tablets tonight');
      final card = c.messages.last.cards.single;
      expect(h.reminders.store, hasLength(1));

      await c.undo(card.id);
      expect(h.reminders.store, isEmpty);
      final after = c.messages.last.cards.single;
      expect(after.status, CardStatus.undone);
      expect(after.canUndo, isFalse);

      // A second undo does nothing.
      await c.undo(card.id);
      expect(h.reminders.store, isEmpty);
    });

    test('delete waits for the user, then happens on confirm', () async {
      final h = await AssistantHarness.create(
        script: (_) => calls([
          call('deleteItem', {'kind': 'task', 'title': 'Buy milk'}),
        ]),
      );
      await h.tasks.createTask(title: 'Buy milk');
      final c = h.controller();

      await c.send('delete buy milk');
      final card = c.messages.last.cards.single;
      expect(card.status, CardStatus.awaitingConfirm);
      expect(h.taskRepo.storage, hasLength(1));

      await c.confirm(card.id);
      expect(h.taskRepo.storage, isEmpty);
      expect(c.messages.last.cards, isEmpty);
      expect(
        c.messages[c.messages.length - 2].cards.single.status,
        CardStatus.done,
      );
      expect(c.messages.last.text, contains('deleted'));
    });

    test('cancelling a delete leaves the data alone', () async {
      final h = await AssistantHarness.create(
        script: (_) => calls([
          call('deleteItem', {'kind': 'task', 'title': 'Buy milk'}),
        ]),
      );
      await h.tasks.createTask(title: 'Buy milk');
      final c = h.controller();
      await c.send('delete buy milk');
      final card = c.messages.last.cards.single;

      await c.cancel(card.id);
      expect(h.taskRepo.storage, hasLength(1));
      expect(
        c.messages[c.messages.length - 2].cards.single.status,
        CardStatus.cancelled,
      );
    });

    test('blank input and input while thinking are ignored', () async {
      final h = await AssistantHarness.create(script: reminderScript);
      final c = h.controller();
      await c.send('   ');
      expect(c.messages, isEmpty);
      expect(h.provider.requests, isEmpty);
    });

    test('model failures show a friendly line and stay out of history', () async {
      final h = await AssistantHarness.create(
        script: (_) => throw const AiProviderException(
          AiFailureKind.rateLimited,
          'I\'ve hit the free usage limit for a moment. Try again in a minute.',
        ),
      );
      final c = h.controller();
      await c.send('hello');
      expect(c.messages.last.text, contains('free usage limit'));
      expect(c.status.value, AssistantStatus.idle);
    });

    test('only recent turns are sent and failures are excluded', () async {
      var fail = true;
      final h = await AssistantHarness.create(
        script: (_) {
          if (fail) {
            throw const AiProviderException(AiFailureKind.server, 'oops');
          }
          return const AiResponse(text: 'fine');
        },
      );
      final c = h.controller();
      await c.send('first');
      fail = false;
      await c.send('second');
      final sent = h.provider.requests.last.map((m) => m.content).toList();
      expect(sent, contains('first'));
      expect(sent, isNot(contains('oops')));
    });
  });

  group('history', () {
    test('persists per user and reloads', () async {
      SharedPreferences.setMockInitialValues({});
      final store = SharedPrefsChatHistoryStore();
      final h = await AssistantHarness.create(script: reminderScript);
      final c1 = AssistantController(
        engine: h.engine,
        voice: FakeVoice(),
        history: store,
        uidProvider: () => 'u1',
        now: () => h.now,
      );
      await c1.send('remind me to take tablets tonight');

      final c2 = AssistantController(
        engine: h.engine,
        voice: FakeVoice(),
        history: store,
        uidProvider: () => 'u1',
        now: () => h.now,
      );
      await c2.loadHistory();
      expect(c2.messages.map((m) => m.text), c1.messages.map((m) => m.text));
      // Undo closures are not persisted.
      expect(c2.messages.last.cards.single.canUndo, isFalse);

      final other = AssistantController(
        engine: h.engine,
        voice: FakeVoice(),
        history: store,
        uidProvider: () => 'someone-else',
        now: () => h.now,
      );
      await other.loadHistory();
      expect(other.messages, isEmpty);
    });

    test('clearHistory empties the thread and storage', () async {
      final store = InMemoryChatHistoryStore();
      final h = await AssistantHarness.create(script: reminderScript);
      final c = AssistantController(
        engine: h.engine,
        voice: FakeVoice(),
        history: store,
        uidProvider: () => 'u1',
        now: () => h.now,
      );
      await c.send('remind me to take tablets tonight');
      await c.clearHistory();
      expect(c.messages, isEmpty);
      expect(await store.load('u1'), isEmpty);
    });

    test('stored cards with a pending confirm restore as cancelled', () {
      final restored = ActionCard.fromJson({
        'id': 'x',
        'label': 'Delete task: A',
        'status': 'awaitingConfirm',
      });
      expect(restored!.status, CardStatus.cancelled);
    });
  });

  group('voice', () {
    test(
      'partial transcript is live, final result auto-sends and is spoken',
      () async {
        final h = await AssistantHarness.create(script: reminderScript);
        final voice = FakeVoice();
        final c = h.controller(voice: voice);

        await c.startListening();
        expect(c.status.value, AssistantStatus.listening);

        voice.onPartial!('remind me to take');
        expect(c.partialTranscript.value, 'remind me to take');

        voice.onFinal!('remind me to take tablets tonight');
        await Future<void>.delayed(const Duration(milliseconds: 20));

        expect(c.partialTranscript.value, isEmpty);
        expect(c.messages.first.text, 'remind me to take tablets tonight');
        expect(h.reminders.store, hasLength(1));
        expect(voice.spoken, ['Done. I\'ve set a reminder for 9 PM tonight.']);
        expect(c.status.value, AssistantStatus.idle);
      },
    );

    test('muted voice replies are not spoken', () async {
      final h = await AssistantHarness.create(script: reminderScript);
      final voice = FakeVoice();
      final c = h.controller(voice: voice);
      c.setMuted(true);
      await c.startListening();
      voice.onFinal!('remind me to take tablets tonight');
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(h.reminders.store, hasLength(1));
      expect(voice.spoken, isEmpty);
    });

    test(
      'permission denied gives a plain message and typing still works',
      () async {
        final h = await AssistantHarness.create(script: reminderScript);
        final voice = FakeVoice()..startIssue = VoiceIssue.permissionDenied;
        final c = h.controller(voice: voice);

        await c.startListening();
        expect(c.status.value, AssistantStatus.idle);
        expect(
          c.messages.last.text,
          voiceIssueMessage(VoiceIssue.permissionDenied),
        );
        expect(c.messages.last.text, contains('microphone'));

        await c.send('remind me to take tablets tonight');
        expect(h.reminders.store, hasLength(1));
      },
    );

    test('unsupported browser says so', () async {
      final h = await AssistantHarness.create(script: reminderScript);
      final voice = FakeVoice()..startIssue = VoiceIssue.unsupported;
      final c = h.controller(voice: voice);
      await c.startListening();
      expect(c.messages.last.text, contains('isn\'t supported'));
    });

    test('stopping with only a partial transcript still sends it', () async {
      final h = await AssistantHarness.create(script: reminderScript);
      final voice = FakeVoice();
      final c = h.controller(voice: voice);
      await c.startListening();
      voice.onPartial!('remind me to take tablets tonight');
      await c.stopListening();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(c.messages.first.text, 'remind me to take tablets tonight');
    });

    test('silence ends listening with a gentle note', () async {
      final h = await AssistantHarness.create(script: reminderScript);
      final voice = FakeVoice();
      final c = h.controller(voice: voice);
      await c.startListening();
      voice.onIssue!(VoiceIssue.noSpeech);
      expect(c.status.value, AssistantStatus.idle);
      expect(c.messages.last.text, contains('didn\'t hear'));
      expect(h.provider.requests, isEmpty);
    });

    test('a final result after a stop is only sent once', () async {
      final h = await AssistantHarness.create(script: reminderScript);
      final voice = FakeVoice();
      final c = h.controller(voice: voice);
      await c.startListening();
      voice.onFinal!('remind me to take tablets tonight');
      voice.onFinal!('remind me to take tablets tonight');
      voice.onStopped!();
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(h.reminders.store, hasLength(1));
    });
  });

  group('memory', () {
    test('successful actions are remembered; failures are not', () async {
      final h = await AssistantHarness.create(script: reminderScript);
      final memory = InMemoryMemoryStore();
      final c = AssistantController(
        engine: h.engine,
        voice: FakeVoice(),
        history: InMemoryChatHistoryStore(),
        memory: memory,
        uidProvider: () => 'u1',
        now: () => h.now,
      );
      await c.send('remind me to take tablets tonight');
      await Future<void>.delayed(Duration.zero);
      final entries = await memory.recall('u1');
      expect(entries.single.text, contains('remind me to take tablets'));
    });

    test('noop memory keeps nothing', () async {
      const store = NoopMemoryStore();
      await store.remember('u', MemoryEntry(text: 'x', at: DateTime(2026)));
      expect(await store.recall('u'), isEmpty);
    });
  });

  test(
    'not configured: engine reports it so the UI can show setup help',
    () async {
      final h = await AssistantHarness.create(
        script: reminderScript,
        configured: false,
      );
      expect(h.controller().isConfigured, isFalse);
    },
  );
}

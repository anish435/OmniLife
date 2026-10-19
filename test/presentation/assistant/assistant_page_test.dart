import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:omnilife/app/routes/app_routes.dart';
import 'package:omnilife/app/theme/app_theme.dart';
import 'package:omnilife/domain/assistant/ai_provider.dart';
import 'package:omnilife/domain/assistant/chat_message.dart';
import 'package:omnilife/presentation/assistant/voice_service.dart';
import 'package:omnilife/presentation/controllers/assistant_controller.dart';
import 'package:omnilife/presentation/pages/assistant/assistant_page.dart';
import 'package:omnilife/presentation/widgets/assistant/assistant_mic_button.dart';
import 'package:omnilife/presentation/widgets/assistant/listening_dot.dart';

import '../../support/assistant_fakes.dart';

void main() {
  tearDown(Get.reset);

  late FakeVoice voice;

  Future<AssistantController> pumpPage(
    WidgetTester tester, {
    double width = 375,
    bool configured = true,
    AiResponse Function(String)? script,
    ThemeData? theme,
  }) async {
    tester.view.physicalSize = Size(width, 812);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final h = (await tester.runAsync(
      () => AssistantHarness.create(
        configured: configured,
        script:
            script ??
            (_) => calls([
              call('createReminder', {
                'title': 'Take tablets',
                'at': '2026-10-19T21:00',
              }),
            ]),
      ),
    ))!;
    voice = FakeVoice();
    final c = h.controller(voice: voice);
    Get.put<AssistantController>(c);

    await tester.pumpWidget(
      GetMaterialApp(
        theme: theme ?? AppTheme.light,
        home: const AssistantPage(),
      ),
    );
    await tester.pump();
    return c;
  }

  testWidgets('not configured shows the setup message and no composer', (
    tester,
  ) async {
    await pumpPage(tester, configured: false);

    expect(find.text('The assistant isn\'t set up yet.'), findsOneWidget);
    expect(find.textContaining('GROQ_API_KEY'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty thread invites a first message', (tester) async {
    await pumpPage(tester);
    expect(find.text('Assistant'), findsOneWidget);
    expect(find.text('Tell me what you need.'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('typing a command shows both sides and a result card with Undo', (
    tester,
  ) async {
    await pumpPage(tester);

    await tester.enterText(
      find.byType(TextField),
      'remind me to take tablets tonight',
    );
    await tester.tap(find.byTooltip('Send'));
    await tester.pumpAndSettle();

    expect(find.text('remind me to take tablets tonight'), findsOneWidget);
    expect(
      find.text('Done. I\'ve set a reminder for 9 PM tonight.'),
      findsOneWidget,
    );
    expect(
      find.text('Reminder set: Take tablets, today 9:00 PM'),
      findsOneWidget,
    );
    expect(find.text('Undo'), findsOneWidget);

    // The user's bubble is right aligned, the reply left aligned.
    final user = tester
        .getTopLeft(find.text('remind me to take tablets tonight'))
        .dx;
    final reply = tester
        .getTopLeft(find.text('Done. I\'ve set a reminder for 9 PM tonight.'))
        .dx;
    expect(user, greaterThan(reply));

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(find.textContaining('(Undone)'), findsOneWidget);
    expect(find.text('Undo'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('long thread with cards and a confirmation fits 375px', (
    tester,
  ) async {
    final c = await pumpPage(tester, width: 375);
    final long =
        'Reminder set: ${'Take the tablets with water ' * 4}, today 9:00 PM';
    c.messages.assignAll([
      for (var i = 0; i < 6; i++) ...[
        ChatMessage(
          id: 'u$i',
          role: ChatRole.user,
          text:
              'A fairly long message from the user number $i that wraps over several lines',
          createdAt: DateTime(2026, 10, 19),
        ),
        ChatMessage(
          id: 'a$i',
          role: ChatRole.assistant,
          text: 'Done. I\'ve set a reminder for 9 PM tonight, and another thing as well.',
          createdAt: DateTime(2026, 10, 19),
          cards: [
            ActionCard(
              id: 'c$i',
              label: long,
              status: CardStatus.done,
              canUndo: true,
            ),
          ],
        ),
      ],
      ChatMessage(
        id: 'z',
        role: ChatRole.assistant,
        text: 'Delete the task "Buy milk"? This can\'t be undone.',
        createdAt: DateTime(2026, 10, 19),
        cards: const [
          ActionCard(
            id: 'cz',
            label: 'Delete task: Buy milk and a very long extra description',
            status: CardStatus.awaitingConfirm,
          ),
        ],
      ),
    ]);
    await tester.pumpAndSettle();
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('Delete'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('dark theme at 320px does not overflow', (tester) async {
    final c = await pumpPage(tester, width: 320, theme: AppTheme.dark);
    c.messages.assignAll([
      ChatMessage(
        id: 'a',
        role: ChatRole.assistant,
        text: 'Hello',
        createdAt: DateTime(2026, 10, 19),
      ),
    ]);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('listening shows the live transcript with a pulsing dot', (
    tester,
  ) async {
    final c = await pumpPage(tester);

    await tester.tap(find.byTooltip('Speak'));
    await tester.pump();
    expect(find.byType(ListeningDot), findsOneWidget);
    expect(find.text('Listening…'), findsOneWidget);

    voice.onPartial!('remind me to');
    await tester.pump();
    expect(find.text('remind me to'), findsOneWidget);
    expect(c.status.value, AssistantStatus.listening);

    voice.onFinal!('remind me to take tablets tonight');
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byType(ListeningDot), findsNothing);
    expect(find.text('remind me to take tablets tonight'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 300));
    expect(voice.spoken, isNotEmpty);
  });

  testWidgets('mic problems are explained in plain words', (tester) async {
    await pumpPage(tester);
    voice.startIssue = VoiceIssue.permissionDenied;
    await tester.tap(find.byTooltip('Speak'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('microphone'), findsOneWidget);
  });

  testWidgets('mute toggle switches the icon', (tester) async {
    final c = await pumpPage(tester);
    expect(find.byIcon(Icons.volume_up_outlined), findsOneWidget);
    await tester.tap(find.byTooltip('Mute spoken replies'));
    await tester.pump();
    expect(c.muted.value, isTrue);
    expect(find.byIcon(Icons.volume_off_outlined), findsOneWidget);
  });

  group('mic entry points', () {
    Future<void> pumpHost(WidgetTester tester, Widget body) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final h = (await tester.runAsync(
        () => AssistantHarness.create(
          script: (_) => const AiResponse(text: 'hi'),
        ),
      ))!;
      voice = FakeVoice();
      Get.put<AssistantController>(h.controller(voice: voice));
      await tester.pumpWidget(
        GetMaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            appBar: AppBar(actions: const [AssistantMicAction()]),
            body: body,
          ),
          getPages: [
            GetPage(
              name: AppRoutes.assistant,
              page: () => const AssistantPage(),
            ),
          ],
        ),
      );
      await tester.pump();
    }

    testWidgets('app bar mic opens the assistant and starts listening', (
      tester,
    ) async {
      await pumpHost(tester, const SizedBox());
      await tester.tap(find.byTooltip('Talk to the assistant'));
      // The page opens already listening, so the pulsing dot never settles.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(AssistantPage), findsOneWidget);
      expect(voice.starts, 1);
    });

    testWidgets('floating mic is small and sits where told', (tester) async {
      await pumpHost(
        tester,
        const Stack(
          children: [
            Positioned(left: 16, bottom: 16, child: AssistantMicFab()),
          ],
        ),
      );
      final size = tester.getSize(find.byType(AssistantMicFab));
      expect(size.width, lessThanOrEqualTo(48));
      await tester.tap(find.byType(AssistantMicFab));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(AssistantPage), findsOneWidget);
    });
  });
}

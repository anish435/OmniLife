import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:omnilife/app/theme/app_theme.dart';
import 'package:omnilife/domain/assistant/ai_provider.dart';
import 'package:omnilife/presentation/controllers/assistant_controller.dart';
import 'package:omnilife/presentation/widgets/assistant/voice_assistant_sheet.dart';

import '../../support/assistant_fakes.dart';

void main() {
  tearDown(Get.reset);

  late FakeVoice voice;

  Future<AssistantController> pumpSheet(
    WidgetTester tester, {
    bool configured = true,
  }) async {
    final h = (await tester.runAsync(
      () => AssistantHarness.create(
        configured: configured,
        script: (_) => const AiResponse(text: 'Done'),
      ),
    ))!;
    voice = FakeVoice();
    final c = h.controller(voice: voice);
    Get.put<AssistantController>(c);

    await tester.pumpWidget(
      GetMaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: Builder(
            builder: (ctx) => ElevatedButton(
              onPressed: () => VoiceAssistantSheet.show(ctx),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );

    // Tap to open sheet
    await tester.tap(find.text('Open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    return c;
  }

  testWidgets('renders Voice Assistant popup sheet and header elements', (
    tester,
  ) async {
    await pumpSheet(tester);

    expect(find.text('Voice Assistant'), findsOneWidget);
    expect(find.byIcon(Icons.close), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('tapping close icon dismisses the sheet', (tester) async {
    await pumpSheet(tester);
    expect(find.text('Voice Assistant'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Voice Assistant'), findsNothing);
  });

  testWidgets('when not configured, shows guidance message', (tester) async {
    await pumpSheet(tester, configured: false);

    expect(find.text('Voice Assistant'), findsOneWidget);
    expect(find.text('Assistant not configured'), findsOneWidget);
  });
}

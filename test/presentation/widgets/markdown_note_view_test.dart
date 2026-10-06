import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omnilife/app/theme/app_theme.dart';
import 'package:omnilife/presentation/widgets/notes/markdown_note_view.dart';

void main() {
  Future<void> pump(
    WidgetTester tester,
    String content, {
    ValueChanged<int>? onToggle,
    Size size = const Size(375, 700),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: SingleChildScrollView(
            child: MarkdownNoteView(
              content: content,
              onToggleChecklist: onToggle,
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('renders headings, emphasis, lists, links and code', (
    tester,
  ) async {
    await pump(
      tester,
      '# Big heading\n\n'
      'Some **bold** and *italic* text with [a link](https://example.com).\n\n'
      '- first bullet\n- second bullet\n\n'
      'Inline `snippet` here.\n\n'
      '```\nblock code\n```',
    );
    expect(
      find.textContaining('Big heading', findRichText: true),
      findsOneWidget,
    );
    expect(find.textContaining('bold', findRichText: true), findsOneWidget);
    expect(
      find.textContaining('first bullet', findRichText: true),
      findsOneWidget,
    );
    expect(find.textContaining('a link', findRichText: true), findsOneWidget);
    expect(find.textContaining('snippet', findRichText: true), findsOneWidget);
    expect(
      find.textContaining('block code', findRichText: true),
      findsOneWidget,
    );
    // Markdown markers are consumed, not shown literally.
    expect(find.textContaining('**', findRichText: true), findsNothing);
    expect(find.textContaining('# Big', findRichText: true), findsNothing);
  });

  testWidgets('tapping a checklist row reports its source line', (
    tester,
  ) async {
    final taps = <int>[];
    await pump(
      tester,
      'Intro\n- [ ] buy milk\n- [x] call mom\n\nOutro',
      onToggle: taps.add,
    );
    await tester.tap(find.byKey(const ValueKey('checklist-line-1')));
    await tester.tap(find.byKey(const ValueKey('checklist-line-2')));
    expect(taps, [1, 2]);
    // Checked rows show a check icon; unchecked do not.
    expect(find.byIcon(Icons.check), findsOneWidget);
  });

  testWidgets('checklist rows expose checked semantics', (tester) async {
    final handle = tester.ensureSemantics();
    await pump(tester, '- [ ] a\n- [x] b', onToggle: (_) {});
    expect(
      tester.getSemantics(find.bySemanticsLabel('b')),
      matchesSemantics(
        label: 'b',
        hasCheckedState: true,
        isChecked: true,
        hasTapAction: true,
      ),
    );
    handle.dispose();
  });

  testWidgets('empty content shows a placeholder and does not overflow', (
    tester,
  ) async {
    await pump(tester, '   ');
    expect(find.text('Nothing to preview yet.'), findsOneWidget);
  });

  testWidgets('long unbroken lines do not overflow at 375px', (tester) async {
    await pump(
      tester,
      '- [ ] ${'verylongword' * 12}\n\n${'x' * 300}',
      onToggle: (_) {},
    );
    expect(tester.takeException(), isNull);
  });
}

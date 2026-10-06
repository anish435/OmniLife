import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omnilife/app/theme/app_theme.dart';
import 'package:omnilife/presentation/widgets/habits/animated_check_circle.dart';
import 'package:omnilife/presentation/widgets/habits/habit_heatmap.dart';

void main() {
  final today = DateTime(2026, 3, 11, 10);

  void setSize(WidgetTester tester, Size size) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  group('HabitHeatmap', () {
    Future<void> pumpHeatmap(
      WidgetTester tester, {
      Set<String> done = const {},
      int longest = 0,
      Size size = const Size(375, 800),
    }) async {
      setSize(tester, size);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: HabitHeatmap(
                completedDates: done,
                today: today,
                longestStreak: longest,
              ),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('summary states done days of 365 and the longest streak', (
      tester,
    ) async {
      await pumpHeatmap(
        tester,
        done: {'2026-03-11', '2026-03-10', '2026-01-01'},
        longest: 2,
      );
      expect(find.text('3 of 365 days, longest streak 2 days'), findsOneWidget);
    });

    testWidgets('singular wording and zero state', (tester) async {
      await pumpHeatmap(tester, longest: 1);
      expect(find.text('0 of 365 days, longest streak 1 day'), findsOneWidget);
    });

    testWidgets('shows legend entries and month labels', (tester) async {
      await pumpHeatmap(tester);
      expect(find.text('Done'), findsOneWidget);
      expect(find.text('Not done'), findsOneWidget);
      expect(find.text('Today'), findsOneWidget);
      // Scrolled to the newest weeks, so recent months are built.
      expect(find.text('Mar'), findsWidgets);
    });

    testWidgets('does not overflow at 375px and scrolls horizontally', (
      tester,
    ) async {
      await pumpHeatmap(tester);
      expect(tester.takeException(), isNull);
      final scroll = tester.state<ScrollableState>(
        find.descendant(
          of: find.byKey(const ValueKey('heatmap-scroll')),
          matching: find.byType(Scrollable),
        ),
      );
      expect(scroll.position.maxScrollExtent, greaterThan(100));
      // Starts at the newest week.
      expect(scroll.position.pixels, scroll.position.maxScrollExtent);
      // The oldest week is off-screen to the left until scrolled.
      await tester.drag(
        find.byKey(const ValueKey('heatmap-scroll')),
        const Offset(2000, 0),
      );
      await tester.pump();
      expect(scroll.position.pixels, 0);
      expect(tester.takeException(), isNull);
    });

    testWidgets('tapping a cell shows its date and status', (tester) async {
      await pumpHeatmap(tester, done: {'2026-03-10'});
      expect(find.text('Tap a day to see its status'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('heat-2026-03-10')));
      await tester.pump();
      expect(find.text('Tuesday 10 March 2026: Done'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('heat-2026-03-09')));
      await tester.pump();
      expect(find.text('Monday 9 March 2026: Not done'), findsOneWidget);
    });

    testWidgets('cells expose date and status to screen readers', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpHeatmap(tester, done: {'2026-03-10'});
      expect(
        find.bySemanticsLabel('Tuesday 10 March 2026, done'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel('Monday 9 March 2026, not done'),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('exactly 365 cells are rendered across the scroll extent', (
      tester,
    ) async {
      await pumpHeatmap(tester, size: const Size(3000, 800));
      final cells = find.byWidgetPredicate(
        (w) =>
            w.key is ValueKey<String> &&
            (w.key! as ValueKey<String>).value.startsWith('heat-'),
      );
      expect(cells, findsNWidgets(365));
    });
  });

  group('AnimatedCheckCircle', () {
    final haptics = <String>[];

    setUp(() => haptics.clear());

    void mockHaptics(WidgetTester tester) {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'HapticFeedback.vibrate') {
            haptics.add(call.arguments as String);
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
    }

    Future<void> pumpCircle(
      WidgetTester tester, {
      required ValueNotifier<bool> done,
      bool disableAnimations = false,
      VoidCallback? onTap,
    }) async {
      await tester.pumpWidget(
        MediaQuery(
          data: MediaQueryData(disableAnimations: disableAnimations),
          child: MaterialApp(
            theme: AppTheme.light,
            home: Scaffold(
              body: Center(
                child: ValueListenableBuilder<bool>(
                  valueListenable: done,
                  builder: (_, v, _) => AnimatedCheckCircle(
                    completed: v,
                    onTap: () {
                      onTap?.call();
                      done.value = !done.value;
                    },
                    semanticLabel: 'Read, Wednesday',
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('completing fires a light haptic and animates', (tester) async {
      mockHaptics(tester);
      final done = ValueNotifier(false);
      await pumpCircle(tester, done: done);
      await tester.tap(find.byType(AnimatedCheckCircle));
      await tester.pump();
      expect(haptics, ['HapticFeedbackType.lightImpact']);
      expect(done.value, isTrue);
      expect(tester.hasRunningAnimations, isTrue);
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.hasRunningAnimations, isTrue);
      await tester.pumpAndSettle();
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('un-completing gives no haptic and no animation', (
      tester,
    ) async {
      mockHaptics(tester);
      final done = ValueNotifier(true);
      await pumpCircle(tester, done: done);
      await tester.tap(find.byType(AnimatedCheckCircle));
      await tester.pump();
      expect(haptics, isEmpty);
      expect(done.value, isFalse);
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('respects disableAnimations: shows the end state at once', (
      tester,
    ) async {
      mockHaptics(tester);
      final done = ValueNotifier(false);
      await pumpCircle(tester, done: done, disableAnimations: true);
      await tester.tap(find.byType(AnimatedCheckCircle));
      await tester.pump();
      expect(done.value, isTrue);
      expect(tester.hasRunningAnimations, isFalse);
      // Haptics are not motion, so they still fire.
      expect(haptics.length, 1);
    });

    testWidgets('exposes label and checked state to accessibility', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final done = ValueNotifier(true);
      await pumpCircle(tester, done: done);
      expect(
        tester.getSemantics(find.bySemanticsLabel('Read, Wednesday')),
        matchesSemantics(
          label: 'Read, Wednesday',
          isButton: true,
          hasCheckedState: true,
          isChecked: true,
          hasTapAction: true,
        ),
      );
      handle.dispose();
    });

    testWidgets('touch target is at least 48 dp tall', (tester) async {
      final done = ValueNotifier(false);
      await pumpCircle(tester, done: done);
      final size = tester.getSize(find.byType(AnimatedCheckCircle));
      expect(size.height, greaterThanOrEqualTo(48));
    });
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omnilife/app/theme/app_theme.dart';
import 'package:omnilife/domain/entities/task.dart';
import 'package:omnilife/presentation/widgets/task_card.dart';

void main() {
  final now = DateTime.now();
  final testTask = Task(
    id: 'test-1',
    userId: 'user-1',
    title: 'Finish report',
    description: 'Quarterly review report',
    completed: false,
    priority: TaskPriority.high,
    dueDate: DateTime(now.year, now.month, now.day, 14, 0),
    createdAt: now,
    updatedAt: now,
  );

  Widget wrapWithTheme(Widget child) {
    return MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(body: child),
    );
  }

  testWidgets('renders task title, description, priority badge, and due date', (tester) async {
    await tester.pumpWidget(
      wrapWithTheme(
        TaskCard(
          task: testTask,
          onToggle: () {},
          onDelete: () {},
        ),
      ),
    );

    expect(find.text('Finish report'), findsOneWidget);
    expect(find.text('Quarterly review report'), findsOneWidget);
    expect(find.text('HIGH'), findsOneWidget);
    expect(find.text('Today'), findsOneWidget);
  });

  testWidgets('tapping checkbox invokes onToggle', (tester) async {
    bool toggled = false;

    await tester.pumpWidget(
      wrapWithTheme(
        TaskCard(
          task: testTask,
          onToggle: () => toggled = true,
          onDelete: () {},
        ),
      ),
    );

    final checkbox = find.byType(AnimatedContainer);
    expect(checkbox, findsOneWidget);
    await tester.tap(checkbox);
    expect(toggled, isTrue);
  });

  testWidgets('tapping card invokes onTap', (tester) async {
    bool tapped = false;

    await tester.pumpWidget(
      wrapWithTheme(
        TaskCard(
          task: testTask,
          onToggle: () {},
          onDelete: () {},
          onTap: () => tapped = true,
        ),
      ),
    );

    // Tap main card
    await tester.tap(find.text('Finish report'));
    expect(tapped, isTrue);
  });

  testWidgets('tapping delete button invokes onDelete', (tester) async {
    bool deleted = false;

    await tester.pumpWidget(
      wrapWithTheme(
        TaskCard(
          task: testTask,
          onToggle: () {},
          onDelete: () => deleted = true,
        ),
      ),
    );

    final deleteIcon = find.byIcon(Icons.delete_outline);
    expect(deleteIcon, findsOneWidget);

    await tester.tap(deleteIcon);
    expect(deleted, isTrue);
  });
}

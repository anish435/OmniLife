import 'package:flutter_test/flutter_test.dart';
import 'package:omnilife/domain/entities/task.dart';

Task _buildTask({bool completed = false}) {
  final now = DateTime(2026, 1, 1, 9);
  return Task(
    id: 't1',
    userId: 'u1',
    title: 'Write report',
    description: 'Quarterly report',
    completed: completed,
    priority: TaskPriority.high,
    createdAt: now,
    updatedAt: now,
    dueDate: DateTime(2026, 1, 5),
  );
}

void main() {
  test('two tasks with identical fields are equal', () {
    expect(_buildTask(), _buildTask());
    expect(_buildTask().hashCode, _buildTask().hashCode);
  });

  test('copyWith overrides only the given fields', () {
    final task = _buildTask();
    final updated = task.copyWith(completed: true, title: 'Write report v2');

    expect(updated.completed, isTrue);
    expect(updated.title, 'Write report v2');
    // Untouched fields are preserved.
    expect(updated.id, task.id);
    expect(updated.userId, task.userId);
    expect(updated.priority, task.priority);
    expect(updated.createdAt, task.createdAt);
    expect(updated.dueDate, task.dueDate);
  });

  test('defaults are incomplete and medium priority', () {
    final task = Task(
      id: 't2',
      userId: 'u1',
      title: 'Untitled',
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );

    expect(task.completed, isFalse);
    expect(task.priority, TaskPriority.medium);
    expect(task.description, isNull);
    expect(task.dueDate, isNull);
  });
}

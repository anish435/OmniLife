import 'package:flutter_test/flutter_test.dart';
import 'package:omnilife/data/models/task_model.dart';
import 'package:omnilife/domain/entities/task.dart';

void main() {
  test('toMap encodes booleans, enums and timestamps for SQLite', () {
    final model = TaskModel(
      id: 't1',
      userId: 'u1',
      title: 'Write report',
      description: 'Quarterly report',
      completed: true,
      priority: TaskPriority.high,
      createdAt: DateTime.fromMillisecondsSinceEpoch(1000),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(2000),
      dueDate: DateTime.fromMillisecondsSinceEpoch(3000),
    );

    final map = model.toMap();

    expect(map['id'], 't1');
    expect(map['user_id'], 'u1');
    expect(map['title'], 'Write report');
    expect(map['description'], 'Quarterly report');
    expect(map['completed'], 1);
    expect(map['priority'], 'high');
    expect(map['created_at'], 1000);
    expect(map['updated_at'], 2000);
    expect(map['due_date'], 3000);
  });

  test('toMap encodes an incomplete task and null optionals', () {
    final model = TaskModel(
      id: 't2',
      userId: 'u1',
      title: 'Untitled',
      createdAt: DateTime.fromMillisecondsSinceEpoch(0),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(0),
    );

    final map = model.toMap();

    expect(map['completed'], 0);
    expect(map['description'], isNull);
    expect(map['due_date'], isNull);
  });

  test('fromMap is the inverse of toMap', () {
    final original = TaskModel(
      id: 't1',
      userId: 'u1',
      title: 'Write report',
      description: 'Quarterly report',
      completed: true,
      priority: TaskPriority.low,
      createdAt: DateTime.fromMillisecondsSinceEpoch(1000),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(2000),
      dueDate: DateTime.fromMillisecondsSinceEpoch(3000),
    );

    final roundTripped = TaskModel.fromMap(original.toMap());

    expect(roundTripped, original);
  });

  test('fromMap handles a null due_date', () {
    final map = {
      'id': 't3',
      'user_id': 'u1',
      'title': 'No due date',
      'description': null,
      'completed': 0,
      'priority': 'medium',
      'due_date': null,
      'created_at': 1000,
      'updated_at': 1000,
    };

    final model = TaskModel.fromMap(map);

    expect(model.dueDate, isNull);
    expect(model.completed, isFalse);
    expect(model.priority, TaskPriority.medium);
  });
}

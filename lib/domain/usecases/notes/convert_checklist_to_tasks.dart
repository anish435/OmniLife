import 'package:uuid/uuid.dart';

import '../../entities/note.dart';
import '../../entities/task.dart';
import '../../repositories/task_repository.dart';
import 'checklist_parser.dart';

class ConvertChecklistResult {
  const ConvertChecklistResult({
    required this.created,
    required this.alreadyLinked,
    required this.tasks,
  });

  /// Number of new tasks created by this run.
  final int created;

  /// Unchecked items skipped because a task for them already exists.
  final int alreadyLinked;
  final List<Task> tasks;

  String get message {
    if (created == 0 && alreadyLinked == 0) {
      return 'No unchecked checklist items to convert';
    }
    if (created == 0) {
      return 'Already converted: $alreadyLinked '
          '${alreadyLinked == 1 ? 'task exists' : 'tasks exist'}';
    }
    final base = 'Created $created ${created == 1 ? 'task' : 'tasks'}';
    return alreadyLinked > 0 ? '$base ($alreadyLinked already existed)' : base;
  }
}

/// Turns the unchecked `- [ ]` lines of a note into real tasks.
///
/// Idempotent without any schema change: every created task carries a
/// `[note:<noteId>]` marker in its description, and an item is skipped when
/// a task with the same title and marker already exists (duplicate lines in
/// one note are matched one-to-one).
class ConvertChecklistToTasks {
  ConvertChecklistToTasks(this._taskRepository, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final TaskRepository _taskRepository;
  final DateTime Function() _clock;

  static const _maxTitleLength = 200;

  static String markerFor(String noteId) => '[note:$noteId]';

  Future<ConvertChecklistResult> call(Note note) async {
    final items = ChecklistParser.unchecked(note.content);
    if (items.isEmpty) {
      return const ConvertChecklistResult(
        created: 0,
        alreadyLinked: 0,
        tasks: [],
      );
    }

    final marker = markerFor(note.id);
    final existing = await _taskRepository.getTasks(note.userId);
    // title -> how many linked tasks already exist
    final linked = <String, int>{};
    for (final t in existing) {
      if (t.description?.contains(marker) ?? false) {
        linked[t.title] = (linked[t.title] ?? 0) + 1;
      }
    }

    final noteLabel = note.title.trim().isEmpty
        ? 'Untitled'
        : note.title.trim();
    final created = <Task>[];
    var skipped = 0;
    for (final item in items) {
      final title = item.text.length > _maxTitleLength
          ? item.text.substring(0, _maxTitleLength)
          : item.text;
      final remaining = linked[title] ?? 0;
      if (remaining > 0) {
        linked[title] = remaining - 1;
        skipped++;
        continue;
      }
      final now = _clock();
      final task = Task(
        id: const Uuid().v4(),
        userId: note.userId,
        title: title,
        description: 'From note "$noteLabel" $marker',
        createdAt: now,
        updatedAt: now,
      );
      created.add(await _taskRepository.createTask(task));
    }
    return ConvertChecklistResult(
      created: created.length,
      alreadyLinked: skipped,
      tasks: created,
    );
  }
}

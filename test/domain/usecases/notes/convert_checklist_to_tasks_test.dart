import 'package:flutter_test/flutter_test.dart';
import 'package:omnilife/domain/entities/note.dart';
import 'package:omnilife/domain/usecases/notes/convert_checklist_to_tasks.dart';

import '../../../presentation/controllers/task_controller_test.dart'
    show FakeTaskRepository;

Note noteWith(String content, {String id = 'n1', String title = 'Groceries'}) {
  final now = DateTime(2026, 5, 1);
  return Note(
    id: id,
    userId: 'u1',
    title: title,
    content: content,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  late FakeTaskRepository repo;
  late ConvertChecklistToTasks convert;

  setUp(() {
    repo = FakeTaskRepository();
    convert = ConvertChecklistToTasks(repo);
  });

  test('creates one task per unchecked line, skipping checked ones', () async {
    final result = await convert(
      noteWith('- [ ] milk\n- [x] eggs\n- [ ] bread\nplain'),
    );
    expect(result.created, 2);
    expect(repo.storage.map((t) => t.title), ['milk', 'bread']);
    expect(repo.storage.every((t) => !t.completed && t.userId == 'u1'), isTrue);
    expect(repo.storage.first.description, contains('[note:n1]'));
    expect(repo.storage.first.description, contains('Groceries'));
    expect(result.message, 'Created 2 tasks');
  });

  test('converting twice does not duplicate tasks', () async {
    final note = noteWith('- [ ] milk\n- [ ] bread');
    await convert(note);
    final second = await convert(note);
    expect(second.created, 0);
    expect(second.alreadyLinked, 2);
    expect(repo.storage.length, 2);
    expect(second.message, 'Already converted: 2 tasks exist');
  });

  test('new items added later are converted, old ones not repeated', () async {
    await convert(noteWith('- [ ] milk'));
    final result = await convert(noteWith('- [ ] milk\n- [ ] jam'));
    expect(result.created, 1);
    expect(result.alreadyLinked, 1);
    expect(repo.storage.map((t) => t.title), ['milk', 'jam']);
    expect(result.message, 'Created 1 task (1 already existed)');
  });

  test('completed linked tasks still count as converted', () async {
    final note = noteWith('- [ ] milk');
    await convert(note);
    await repo.completeTask(repo.storage.single.id);
    final again = await convert(note);
    expect(again.created, 0);
    expect(repo.storage.length, 1);
  });

  test('duplicate lines in a note are matched one-to-one', () async {
    final note = noteWith('- [ ] pay\n- [ ] pay');
    expect((await convert(note)).created, 2);
    expect((await convert(note)).created, 0);
    expect(repo.storage.length, 2);
  });

  test('same item text in a different note is not deduplicated', () async {
    await convert(noteWith('- [ ] milk', id: 'n1'));
    final r = await convert(noteWith('- [ ] milk', id: 'n2'));
    expect(r.created, 1);
    expect(repo.storage.length, 2);
  });

  test('no unchecked items creates nothing', () async {
    final r = await convert(noteWith('- [x] all done'));
    expect(r.created, 0);
    expect(r.message, 'No unchecked checklist items to convert');
    expect(repo.storage, isEmpty);
  });

  test('checklist lines inside code fences are ignored', () async {
    final r = await convert(noteWith('```\n- [ ] sample\n```'));
    expect(r.created, 0);
  });
}

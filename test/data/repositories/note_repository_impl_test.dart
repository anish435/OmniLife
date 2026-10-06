import 'package:flutter_test/flutter_test.dart';
import 'package:omnilife/data/datasources/local/app_database.dart';
import 'package:omnilife/data/datasources/local/local_note_data_source.dart';
import 'package:omnilife/data/repositories/note_repository_impl.dart';
import 'package:omnilife/domain/entities/note.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Note _note(
  String id, {
  String title = '',
  String content = '',
  List<String> tags = const [],
  String category = 'General',
}) {
  final t = DateTime(2026, 3, 1);
  return Note(
    id: id,
    userId: 'u1',
    title: title,
    content: content,
    tags: tags,
    category: category,
    createdAt: t,
    updatedAt: t,
  );
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late Database db;
  late NoteRepositoryImpl repo;

  setUp(() async {
    db = await databaseFactory.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: AppDatabase.schemaVersion,
        onCreate: (db, version) => AppDatabase.createSchema(db),
      ),
    );
    repo = NoteRepositoryImpl(
      localDataSource: LocalNoteDataSource(databaseProvider: () async => db),
    );
  });

  tearDown(() => db.close());

  test('round-trips tags, category and checklist content', () async {
    await repo.createNote(
      _note(
        'a',
        title: 'Plan',
        content: '- [ ] one\n- [x] two',
        tags: ['x', 'y'],
        category: 'Work',
      ),
    );
    final loaded = (await repo.getNotes('u1')).single;
    expect(loaded.tags, ['x', 'y']);
    expect(loaded.category, 'Work');
    expect(loaded.content, '- [ ] one\n- [x] two');
  });

  test('archiving moves a note between the two lists', () async {
    final n = _note('a', title: 'T');
    await repo.createNote(n);
    await repo.updateNote(n.copyWith(isArchived: true));
    expect(await repo.getNotes('u1'), isEmpty);
    expect((await repo.getArchivedNotes('u1')).single.id, 'a');
    await repo.updateNote(n.copyWith(isArchived: false));
    expect((await repo.getNotes('u1')).single.id, 'a');
  });

  test(
    'searchNotes ranks title over tag over content, across archives',
    () async {
      await repo.createNote(_note('content', content: 'about plan b'));
      await repo.createNote(_note('tag', tags: ['plan']));
      await repo.createNote(_note('title', title: 'Plan'));
      final archived = _note('arch', content: 'plan', title: 'Archived plan');
      await repo.createNote(archived);
      await repo.updateNote(archived.copyWith(isArchived: true));
      final results = await repo.searchNotes('u1', 'plan');
      final order = results.map((e) => e.id).toList();
      expect(order.first, 'title');
      expect(order.toSet(), {'title', 'tag', 'content', 'arch'});
      expect(order.indexOf('tag'), lessThan(order.indexOf('content')));
    },
  );

  test('search does not leak other users notes', () async {
    await repo.createNote(_note('mine', title: 'secret'));
    expect(await repo.searchNotes('someone-else', 'secret'), isEmpty);
  });

  test('deleteNote removes it permanently', () async {
    await repo.createNote(_note('a', title: 'gone'));
    await repo.deleteNote('a');
    expect(await repo.getNotes('u1'), isEmpty);
  });
}

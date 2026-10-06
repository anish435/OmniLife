import 'package:flutter_test/flutter_test.dart';
import 'package:omnilife/domain/entities/note.dart';
import 'package:omnilife/domain/usecases/notes/note_search_ranker.dart';

Note note(
  String id, {
  String title = '',
  String content = '',
  String category = 'General',
  List<String> tags = const [],
  bool pinned = false,
  int minute = 0,
}) {
  final t = DateTime(2026, 1, 1, 0, minute);
  return Note(
    id: id,
    userId: 'u',
    title: title,
    content: content,
    category: category,
    tags: tags,
    isPinned: pinned,
    createdAt: t,
    updatedAt: t,
  );
}

List<String> ids(Iterable<Note> notes, String q) =>
    NoteSearchRanker.rank(notes, q).map((r) => r.note.id).toList();

void main() {
  test('title match outranks tag match outranks content match', () {
    final notes = [
      note('content', title: 'Misc', content: 'we should plan the trip'),
      note('tag', title: 'Misc', tags: ['plan']),
      note('title', title: 'Plan for Q3'),
    ];
    expect(ids(notes, 'plan'), ['title', 'tag', 'content']);
  });

  test('category matches rank above content but below tags', () {
    final notes = [
      note('content', content: 'recipes inside'),
      note('cat', category: 'Recipes'),
      note('tag', tags: ['recipes']),
    ];
    expect(ids(notes, 'recipes'), ['tag', 'cat', 'content']);
  });

  test('exact and prefix title matches beat substring matches', () {
    final notes = [
      note('sub', title: 'Unplanned'),
      note('prefix', title: 'Planning'),
      note('exact', title: 'plan'),
    ];
    expect(ids(notes, 'plan'), ['exact', 'prefix', 'sub']);
  });

  test('all tokens must match (AND), in any field', () {
    final notes = [
      note('a', title: 'Trip', tags: ['paris']),
      note('b', title: 'Trip', content: 'rome'),
    ];
    expect(ids(notes, 'trip paris'), ['a']);
    expect(ids(notes, 'trip berlin'), isEmpty);
  });

  test('is case-insensitive and ignores blank queries', () {
    final notes = [note('a', title: 'HELLO world')];
    expect(ids(notes, 'hello'), ['a']);
    expect(ids(notes, '   '), isEmpty);
    expect(ids(notes, ''), isEmpty);
  });

  test('#tag queries only match tags', () {
    final notes = [
      note('tagged', tags: ['work']),
      note('titled', title: 'work stuff'),
    ];
    expect(ids(notes, '#work'), ['tagged']);
  });

  test('ties break by pinned, then most recently updated', () {
    final notes = [
      note('old', title: 'same', minute: 1),
      note('new', title: 'same', minute: 9),
      note('pin', title: 'same', minute: 0, pinned: true),
    ];
    expect(ids(notes, 'same'), ['pin', 'new', 'old']);
  });

  test('repeated content hits add a small capped bonus', () {
    final notes = [
      note('once', content: 'cat'),
      note('many', content: 'cat cat cat cat'),
    ];
    expect(ids(notes, 'cat'), ['many', 'once']);
    final score = NoteSearchRanker.rank([
      note('x', content: List.filled(40, 'cat').join(' ')),
    ], 'cat').single.score;
    expect(
      score,
      NoteSearchRanker.contentMatch +
          NoteSearchRanker.contentOccurrenceBonusCap,
    );
  });

  test('regex metacharacters in the query are treated literally', () {
    final notes = [note('a', title: 'what? (now)')];
    expect(ids(notes, '(now)'), ['a']);
    expect(ids(notes, 'a.b'), isEmpty);
  });
}

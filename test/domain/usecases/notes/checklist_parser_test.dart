import 'package:flutter_test/flutter_test.dart';
import 'package:omnilife/domain/usecases/notes/checklist_parser.dart';

void main() {
  const content =
      '# Plan\n'
      '- [ ] buy milk\n'
      '- [x] call mom\n'
      '* [X] done star\n'
      'plain line\n'
      '  - [ ] nested item\n'
      '```\n'
      '- [ ] inside code\n'
      '```\n'
      '- [ ]\n'
      '- [ ] last';

  test('parse finds checked and unchecked items outside code fences', () {
    final items = ChecklistParser.parse(content);
    expect(items.map((e) => e.text), [
      'buy milk',
      'call mom',
      'done star',
      'nested item',
      'last',
    ]);
    expect(items.map((e) => e.checked), [false, true, true, false, false]);
    expect(items.map((e) => e.lineIndex), [1, 2, 3, 5, 10]);
  });

  test('unchecked excludes checked items', () {
    expect(ChecklistParser.unchecked(content).map((e) => e.text), [
      'buy milk',
      'nested item',
      'last',
    ]);
  });

  test('toggle flips only the targeted line, both directions', () {
    final once = ChecklistParser.toggle(content, 1);
    expect(once.split('\n')[1], '- [x] buy milk');
    expect(once.split('\n')[2], '- [x] call mom');
    final twice = ChecklistParser.toggle(once, 1);
    expect(twice, content);
    expect(
      ChecklistParser.toggle(content, 3).split('\n')[3],
      '* [ ] done star',
    );
  });

  test('toggle ignores non-checklist lines, code fences and bad indexes', () {
    expect(ChecklistParser.toggle(content, 0), content);
    expect(ChecklistParser.toggle(content, 7), content);
    expect(ChecklistParser.toggle(content, 99), content);
    expect(ChecklistParser.toggle(content, -1), content);
  });

  test('CRLF content is preserved when toggling', () {
    const crlf = '- [ ] a\r\n- [ ] b';
    expect(ChecklistParser.parse(crlf).map((e) => e.text), ['a', 'b']);
    expect(ChecklistParser.toggle(crlf, 0), '- [x] a\r\n- [ ] b');
  });

  test('segments interleave markdown runs with checklist lines', () {
    final segs = ChecklistParser.segments('intro\n- [ ] a\n- [x] b\noutro');
    expect(segs.length, 4);
    expect(segs[0].text, 'intro');
    expect(segs[1].item!.text, 'a');
    expect(segs[2].item!.checked, isTrue);
    expect(segs[3].text, 'outro');
  });

  test('progress reports done and total, null without a checklist', () {
    expect(ChecklistParser.progress('no list'), isNull);
    final p = ChecklistParser.progress('- [x] a\n- [ ] b\n- [ ] c')!;
    expect((p.done, p.total), (1, 3));
  });
}

/// One markdown task-list line (`- [ ] text` / `- [x] text`) inside a note.
class ChecklistItem {
  const ChecklistItem({
    required this.lineIndex,
    required this.checked,
    required this.text,
  });

  /// Zero-based index of the line in `content.split('\n')`.
  final int lineIndex;
  final bool checked;
  final String text;

  @override
  bool operator ==(Object other) =>
      other is ChecklistItem &&
      other.lineIndex == lineIndex &&
      other.checked == checked &&
      other.text == text;

  @override
  int get hashCode => Object.hash(lineIndex, checked, text);

  @override
  String toString() => 'ChecklistItem($lineIndex, $checked, "$text")';
}

/// A run of note content: either plain markdown [text] or a checklist [item].
class NoteSegment {
  const NoteSegment.text(String this.text) : item = null;
  const NoteSegment.item(ChecklistItem this.item) : text = null;

  final String? text;
  final ChecklistItem? item;
}

/// Pure-Dart helpers for markdown task lists. Fenced code blocks are skipped
/// so a `- [ ]` inside a code sample is never treated as a task.
abstract final class ChecklistParser {
  static final _itemPattern = RegExp(r'^(\s*[-*+]\s+\[)([ xX])(\]\s+)(\S.*)$');
  static final _fencePattern = RegExp(r'^\s*(```|~~~)');

  static String _stripCr(String line) =>
      line.endsWith('\r') ? line.substring(0, line.length - 1) : line;

  static ChecklistItem? _parseLine(String line, int index) {
    final m = _itemPattern.firstMatch(_stripCr(line));
    if (m == null) return null;
    return ChecklistItem(
      lineIndex: index,
      checked: m.group(2) != ' ',
      text: m.group(4)!.trim(),
    );
  }

  /// All checklist items outside fenced code, in document order.
  static List<ChecklistItem> parse(String content) {
    final items = <ChecklistItem>[];
    var inFence = false;
    final lines = content.split('\n');
    for (var i = 0; i < lines.length; i++) {
      if (_fencePattern.hasMatch(lines[i])) {
        inFence = !inFence;
        continue;
      }
      if (inFence) continue;
      final item = _parseLine(lines[i], i);
      if (item != null) items.add(item);
    }
    return items;
  }

  static List<ChecklistItem> unchecked(String content) =>
      parse(content).where((e) => !e.checked).toList();

  /// Returns [content] with the checkbox on [lineIndex] flipped. Returns the
  /// content unchanged if that line is not a checklist item.
  static String toggle(String content, int lineIndex) {
    if (parse(content).every((e) => e.lineIndex != lineIndex)) return content;
    final lines = content.split('\n');
    final m = _itemPattern.firstMatch(_stripCr(lines[lineIndex]))!;
    final prefix = m.group(1)!;
    final marker = m.group(2) == ' ' ? 'x' : ' ';
    lines[lineIndex] =
        '$prefix$marker${lines[lineIndex].substring(prefix.length + 1)}';
    return lines.join('\n');
  }

  /// Splits [content] into plain-markdown runs and individual checklist
  /// lines, so the renderer can make each checklist line tappable.
  static List<NoteSegment> segments(String content) {
    final out = <NoteSegment>[];
    final buffer = <String>[];
    void flush() {
      if (buffer.isEmpty) return;
      final text = buffer.join('\n');
      if (text.trim().isNotEmpty) out.add(NoteSegment.text(text));
      buffer.clear();
    }

    final byLine = {for (final i in parse(content)) i.lineIndex: i};
    final lines = content.split('\n');
    for (var i = 0; i < lines.length; i++) {
      final item = byLine[i];
      if (item != null) {
        flush();
        out.add(NoteSegment.item(item));
      } else {
        buffer.add(_stripCr(lines[i]));
      }
    }
    flush();
    return out;
  }

  /// "done/total" progress, or null if the note has no checklist.
  static ({int done, int total})? progress(String content) {
    final items = parse(content);
    if (items.isEmpty) return null;
    return (done: items.where((e) => e.checked).length, total: items.length);
  }
}

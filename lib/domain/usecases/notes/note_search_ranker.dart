import '../../entities/note.dart';

class RankedNote {
  const RankedNote(this.note, this.score);
  final Note note;
  final int score;
}

/// Pure-Dart relevance ranking over already-loaded notes. Works identically
/// on mobile and web; no dependency on SQLite FTS.
///
/// Every whitespace-separated token must match somewhere (AND semantics).
/// A token scores by the best field it hits, with title > tag > category >
/// content. A token written `#tag` only matches tags.
abstract final class NoteSearchRanker {
  static const titleExact = 100;
  static const titlePrefix = 80;
  static const titleWord = 65;
  static const titleContains = 55;
  static const tagExact = 45;
  static const tagContains = 35;
  static const categoryMatch = 20;
  static const contentMatch = 10;
  static const contentOccurrenceBonusCap = 5;

  static List<String> tokenize(String query) => query
      .toLowerCase()
      .split(RegExp(r'\s+'))
      .where((t) => t.isNotEmpty && t != '#')
      .toList();

  static List<RankedNote> rank(Iterable<Note> notes, String query) {
    final tokens = tokenize(query);
    if (tokens.isEmpty) return const [];
    final results = <RankedNote>[];
    for (final note in notes) {
      final score = scoreNote(note, tokens);
      if (score > 0) results.add(RankedNote(note, score));
    }
    results.sort((a, b) {
      if (a.score != b.score) return b.score.compareTo(a.score);
      if (a.note.isPinned != b.note.isPinned) return a.note.isPinned ? -1 : 1;
      return b.note.updatedAt.compareTo(a.note.updatedAt);
    });
    return results;
  }

  /// Total score, or 0 when any token fails to match.
  static int scoreNote(Note note, List<String> tokens) {
    final title = note.title.toLowerCase();
    final content = note.content.toLowerCase();
    final category = note.category.toLowerCase();
    final tags = note.tags.map((t) => t.toLowerCase()).toList();

    var total = 0;
    for (final raw in tokens) {
      final tagOnly = raw.startsWith('#');
      final token = tagOnly ? raw.substring(1) : raw;
      if (token.isEmpty) return 0;
      var best = 0;

      for (final tag in tags) {
        if (tag == token) {
          if (best < tagExact) best = tagExact;
        } else if (tag.contains(token)) {
          if (best < tagContains) best = tagContains;
        }
      }

      if (!tagOnly) {
        if (title == token) {
          best = titleExact;
        } else if (title.startsWith(token)) {
          if (best < titlePrefix) best = titlePrefix;
        } else if (title.contains(token)) {
          final word = RegExp('(^|[^a-z0-9])${RegExp.escape(token)}')
              .hasMatch(title);
          final s = word ? titleWord : titleContains;
          if (best < s) best = s;
        }
        if (best < categoryMatch && category.contains(token)) {
          best = categoryMatch;
        }
        if (best < contentMatch && content.contains(token)) {
          var count = 0;
          var from = 0;
          while (count < 50) {
            final idx = content.indexOf(token, from);
            if (idx < 0) break;
            count++;
            from = idx + token.length;
          }
          final bonus = (count - 1).clamp(0, contentOccurrenceBonusCap);
          best = contentMatch + bonus;
        }
      }

      if (best == 0) return 0;
      total += best;
    }
    return total;
  }
}

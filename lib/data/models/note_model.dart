import 'dart:convert';
import '../../domain/entities/note.dart';

class NoteModel extends Note {
  const NoteModel({
    required super.id,
    required super.userId,
    required super.title,
    required super.content,
    super.category,
    super.colorTag,
    super.isPinned,
    super.isArchived,
    super.tags,
    required super.createdAt,
    required super.updatedAt,
  });

  factory NoteModel.fromEntity(Note note) {
    return NoteModel(
      id: note.id,
      userId: note.userId,
      title: note.title,
      content: note.content,
      category: note.category,
      colorTag: note.colorTag,
      isPinned: note.isPinned,
      isArchived: note.isArchived,
      tags: note.tags,
      createdAt: note.createdAt,
      updatedAt: note.updatedAt,
    );
  }

  factory NoteModel.fromMap(Map<String, Object?> map) {
    DateTime parseDate(Object? val, DateTime fallback) {
      if (val is int) return DateTime.fromMillisecondsSinceEpoch(val);
      if (val is String) return DateTime.tryParse(val) ?? fallback;
      return fallback;
    }

    final rawPinned = map['is_pinned'] ?? map['isPinned'];
    final isPinned = rawPinned is bool ? rawPinned : (rawPinned == 1);

    final rawArchived = map['is_archived'] ?? map['isArchived'];
    final isArchived = rawArchived is bool ? rawArchived : (rawArchived == 1);

    List<String> tags = [];
    final rawTags = map['tags'];
    if (rawTags is String) {
      try {
        final decoded = jsonDecode(rawTags);
        if (decoded is List) {
          tags = decoded.map((e) => e.toString()).toList();
        }
      } catch (_) {}
    } else if (rawTags is List) {
      tags = rawTags.map((e) => e.toString()).toList();
    }

    final now = DateTime.now();

    return NoteModel(
      id: (map['id'] ?? '') as String,
      userId: ((map['user_id'] ?? map['userId']) ?? '') as String,
      title: (map['title'] ?? '') as String,
      content: (map['content'] ?? '') as String,
      category: (map['category'] ?? 'General') as String,
      colorTag: (map['color_tag'] ?? map['colorTag'] ?? 'default') as String,
      isPinned: isPinned,
      isArchived: isArchived,
      tags: tags,
      createdAt: parseDate(map['created_at'] ?? map['createdAt'], now),
      updatedAt: parseDate(map['updated_at'] ?? map['updatedAt'], now),
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'title': title,
      'content': content,
      'category': category,
      'color_tag': colorTag,
      'is_pinned': isPinned ? 1 : 0,
      'is_archived': isArchived ? 1 : 0,
      'tags': jsonEncode(tags),
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
    };
  }

  Map<String, dynamic> toFirestoreMap() {
    return {
      'userId': userId,
      'title': title,
      'content': content,
      'category': category,
      'colorTag': colorTag,
      'isPinned': isPinned,
      'isArchived': isArchived,
      'tags': tags,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
}

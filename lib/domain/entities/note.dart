import 'package:equatable/equatable.dart';

class Note extends Equatable {
  const Note({
    required this.id,
    required this.userId,
    required this.title,
    required this.content,
    this.category = 'General',
    this.colorTag = 'default',
    this.isPinned = false,
    this.isArchived = false,
    this.tags = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String userId;
  final String title;
  final String content;
  final String category;
  final String colorTag;
  final bool isPinned;
  final bool isArchived;
  final List<String> tags;
  final DateTime createdAt;
  final DateTime updatedAt;

  Note copyWith({
    String? id,
    String? userId,
    String? title,
    String? content,
    String? category,
    String? colorTag,
    bool? isPinned,
    bool? isArchived,
    List<String>? tags,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Note(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      content: content ?? this.content,
      category: category ?? this.category,
      colorTag: colorTag ?? this.colorTag,
      isPinned: isPinned ?? this.isPinned,
      isArchived: isArchived ?? this.isArchived,
      tags: tags ?? this.tags,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        userId,
        title,
        content,
        category,
        colorTag,
        isPinned,
        isArchived,
        tags,
        createdAt,
        updatedAt,
      ];
}

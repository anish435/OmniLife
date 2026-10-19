enum ChatRole { user, assistant }

enum CardStatus { done, undone, awaitingConfirm, cancelled }

/// A small result card under an assistant reply, e.g.
/// "Reminder set: Take tablets, today 9:00 PM".
class ActionCard {
  const ActionCard({
    required this.id,
    required this.label,
    required this.status,
    this.canUndo = false,
  });

  final String id;
  final String label;
  final CardStatus status;

  /// Runtime only: undo closures are not persisted, so a card restored
  /// from storage can no longer be undone.
  final bool canUndo;

  ActionCard copyWith({String? label, CardStatus? status, bool? canUndo}) =>
      ActionCard(
        id: id,
        label: label ?? this.label,
        status: status ?? this.status,
        canUndo: canUndo ?? this.canUndo,
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'label': label,
    'status': status.name,
  };

  static ActionCard? fromJson(Object? json) {
    if (json is! Map) return null;
    final id = json['id'];
    final label = json['label'];
    if (id is! String || label is! String) return null;
    var status = CardStatus.values.firstWhere(
      (s) => s.name == json['status'],
      orElse: () => CardStatus.done,
    );
    // A confirmation that was never answered can't be answered after a
    // restart; show it as cancelled.
    if (status == CardStatus.awaitingConfirm) status = CardStatus.cancelled;
    return ActionCard(id: id, label: label, status: status);
  }
}

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.role,
    required this.text,
    required this.createdAt,
    this.cards = const [],
  });

  final String id;
  final ChatRole role;
  final String text;
  final DateTime createdAt;
  final List<ActionCard> cards;

  ChatMessage copyWith({String? text, List<ActionCard>? cards}) => ChatMessage(
    id: id,
    role: role,
    text: text ?? this.text,
    createdAt: createdAt,
    cards: cards ?? this.cards,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'role': role.name,
    'text': text,
    'at': createdAt.toIso8601String(),
    'cards': [for (final c in cards) c.toJson()],
  };

  static ChatMessage? fromJson(Object? json) {
    if (json is! Map) return null;
    final id = json['id'];
    final text = json['text'];
    final at = DateTime.tryParse('${json['at']}');
    if (id is! String || text is! String || at == null) return null;
    final role = json['role'] == 'user' ? ChatRole.user : ChatRole.assistant;
    final rawCards = json['cards'];
    return ChatMessage(
      id: id,
      role: role,
      text: text,
      createdAt: at,
      cards: [
        if (rawCards is List)
          for (final c in rawCards) ?ActionCard.fromJson(c),
      ],
    );
  }
}

import 'package:equatable/equatable.dart';

/// A finished focus block, stored under `users/{uid}/focus_sessions`.
class FocusSession extends Equatable {
  const FocusSession({
    required this.id,
    required this.userId,
    required this.startedAt,
    required this.endedAt,
    required this.plannedSeconds,
    required this.focusedSeconds,
    this.completed = true,
  });

  final String id;
  final String userId;
  final DateTime startedAt;
  final DateTime endedAt;

  /// Length the user chose for the block.
  final int plannedSeconds;

  /// Time actually spent focusing (pauses excluded).
  final int focusedSeconds;

  /// True when the block ran to its planned end.
  final bool completed;

  int get focusedMinutes => (focusedSeconds / 60).round();

  @override
  List<Object?> get props => [
    id,
    userId,
    startedAt,
    endedAt,
    plannedSeconds,
    focusedSeconds,
    completed,
  ];
}

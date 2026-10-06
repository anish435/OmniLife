import 'package:equatable/equatable.dart';

/// One checkable step toward a [Goal].
class GoalMilestone extends Equatable {
  const GoalMilestone({
    required this.id,
    required this.title,
    this.done = false,
  });

  final String id;
  final String title;
  final bool done;

  GoalMilestone copyWith({String? title, bool? done}) => GoalMilestone(
    id: id,
    title: title ?? this.title,
    done: done ?? this.done,
  );

  @override
  List<Object?> get props => [id, title, done];
}

/// A longer-term target, optionally tied to a habit, broken into milestones.
class Goal extends Equatable {
  const Goal({
    required this.id,
    required this.userId,
    required this.title,
    this.targetDescription = '',
    this.targetDate,
    this.linkedHabitId,
    this.milestones = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String userId;
  final String title;
  final String targetDescription;
  final DateTime? targetDate;
  final String? linkedHabitId;
  final List<GoalMilestone> milestones;
  final DateTime createdAt;
  final DateTime updatedAt;

  int get totalMilestones => milestones.length;
  int get doneMilestones => milestones.where((m) => m.done).length;

  /// 0..1, or 0 when there are no milestones.
  double get progress =>
      milestones.isEmpty ? 0 : doneMilestones / milestones.length;

  bool get isComplete =>
      milestones.isNotEmpty && doneMilestones == milestones.length;

  Goal copyWith({
    String? title,
    String? targetDescription,
    DateTime? targetDate,
    bool clearTargetDate = false,
    String? linkedHabitId,
    bool clearLinkedHabit = false,
    List<GoalMilestone>? milestones,
    DateTime? updatedAt,
  }) {
    return Goal(
      id: id,
      userId: userId,
      title: title ?? this.title,
      targetDescription: targetDescription ?? this.targetDescription,
      targetDate: clearTargetDate ? null : (targetDate ?? this.targetDate),
      linkedHabitId: clearLinkedHabit
          ? null
          : (linkedHabitId ?? this.linkedHabitId),
      milestones: milestones ?? this.milestones,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
    id,
    userId,
    title,
    targetDescription,
    targetDate,
    linkedHabitId,
    milestones,
    createdAt,
    updatedAt,
  ];
}

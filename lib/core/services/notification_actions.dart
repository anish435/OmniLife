import 'notification_routing.dart';

/// Action ids shared by the notification builder and the response handler.
abstract final class NotificationActionIds {
  static const markDone = 'mark_done';
  static const snooze = 'snooze_10';
  static const snoozeMinutes = 10;
  static const darwinCategory = 'omnilife_reminder';
}

enum NotificationActionOutcome { none, completed, snoozed, failed }

/// Runs "Mark done" and "Snooze 10 min" for a reminder notification.
///
/// Pure logic with injected side effects so it works from the background
/// isolate (real task repository and scheduler) and in tests (fakes).
class NotificationActionHandler {
  NotificationActionHandler({
    required this.completeTask,
    required this.scheduleSnooze,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final Future<void> Function(String taskId) completeTask;

  /// Re-schedules the reminder at [when] with the same [payload].
  final Future<void> Function(
    int notificationId,
    String? payload,
    DateTime when,
  )
  scheduleSnooze;
  final DateTime Function() _clock;

  Future<NotificationActionOutcome> handle({
    required String? actionId,
    required String? payload,
    required int? notificationId,
  }) async {
    try {
      switch (actionId) {
        case NotificationActionIds.markDone:
          final target = NotificationRouting.fromPayload(payload);
          if (target?.kind == NotificationRouting.kindTask &&
              target?.id != null) {
            await completeTask(target!.id!);
            return NotificationActionOutcome.completed;
          }
          return NotificationActionOutcome.none;
        case NotificationActionIds.snooze:
          final id = notificationId ?? payload.hashCode & 0x7FFFFFFF;
          await scheduleSnooze(
            id,
            payload,
            _clock().add(
              const Duration(minutes: NotificationActionIds.snoozeMinutes),
            ),
          );
          return NotificationActionOutcome.snoozed;
        default:
          return NotificationActionOutcome.none;
      }
    } catch (_) {
      return NotificationActionOutcome.failed;
    }
  }
}

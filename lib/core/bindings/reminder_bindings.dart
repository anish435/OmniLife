import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import '../../data/repositories/reminder_repository_impl.dart';
import '../../domain/entities/app_notification.dart';
import '../../domain/entities/reminder.dart';
import '../../domain/repositories/reminder_repository.dart';
import '../../domain/usecases/reminders/reminder_service_impl.dart';
import '../../presentation/controllers/auth_controller.dart';
import '../../presentation/controllers/reminders_controller.dart';
import '../services/notification_service.dart';
import '../services/reminder_scheduler.dart';
import '../sync/sync_engine.dart';
import 'pulse_bindings.dart';

bool _authHooked = false;

/// Registers the reminder stack. Idempotent and lazy: nothing touches the
/// database, notifications or Firebase until a reminder is used. Called from
/// `InitialBinding` (so alerts are restored after sign-in) and from the
/// reminders route.
void registerReminderDependencies() {
  if (!Get.isRegistered<SyncEngine>()) registerSyncAndPulse();

  if (!Get.isRegistered<ReminderRepository>()) {
    Get.lazyPut<ReminderRepository>(
      () => ReminderRepositoryImpl(sync: Get.find<SyncEngine>()),
      fenix: true,
    );
  }
  if (!Get.isRegistered<ReminderScheduler>()) {
    Get.lazyPut<ReminderScheduler>(
      () => kIsWeb
          ? InAppReminderScheduler(onDue: _showInAppAlert)
          : NotificationReminderScheduler(onDue: _showInAppAlert),
      fenix: true,
    );
  }
  if (!Get.isRegistered<ReminderService>()) {
    Get.lazyPut<ReminderService>(
      () => ReminderServiceImpl(
        repository: Get.find<ReminderRepository>(),
        scheduler: Get.find<ReminderScheduler>(),
        uidProvider: () {
          if (!Get.isRegistered<AuthController>()) return 'guest-user';
          return Get.find<AuthController>().currentUser.value?.uid ??
              'guest-user';
        },
      ),
      fenix: true,
    );
  }
  if (!Get.isRegistered<RemindersController>()) {
    Get.lazyPut<RemindersController>(() => RemindersController(), fenix: true);
  }
  _hookAuth();
}

/// After sign-in (or when the app starts already signed in), pull reminders
/// saved on other devices and re-register every alert, so they survive
/// restarts and reinstalls.
void _hookAuth() {
  if (_authHooked || !Get.isRegistered<AuthController>()) return;
  _authHooked = true;
  final auth = Get.find<AuthController>();
  ever<dynamic>(auth.currentUser, (user) {
    final uid = user?.uid as String?;
    if (uid != null) unawaited(restoreReminders(uid));
  });
  final current = auth.currentUser.value?.uid;
  if (current != null) unawaited(restoreReminders(current));
}

/// Merges remote reminders into local storage, then reschedules all alerts.
/// Never throws.
Future<void> restoreReminders(String uid) async {
  try {
    final repo = Get.find<ReminderRepository>();
    if (repo is ReminderRepositoryImpl) await repo.refreshFromRemote(uid);
    final service = Get.find<ReminderService>();
    if (service is ReminderServiceImpl) await service.rescheduleAll(uid);
  } catch (e) {
    if (kDebugMode) debugPrint('[Reminders] restore skipped: $e');
  }
}

/// Shows an alert while the app is open.
void _showInAppAlert(Reminder reminder) {
  if (!Get.isRegistered<NotificationService>()) return;
  Get.find<NotificationService>().showInAppNotification(
    AppNotification(
      id: 'reminder_${reminder.id}_${DateTime.now().millisecondsSinceEpoch}',
      title: reminder.title,
      body: (reminder.note?.trim().isNotEmpty ?? false)
          ? reminder.note!.trim()
          : 'Your reminder is due now',
      type: NotificationType.taskReminder,
      timestamp: DateTime.now(),
    ),
  );
  if (Get.isRegistered<RemindersController>()) {
    Get.find<RemindersController>().load();
  }
}

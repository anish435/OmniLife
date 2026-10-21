import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app/theme/app_radius.dart';
import '../../app/theme/app_spacing.dart';
import '../../core/services/demo_data_seeder.dart';
import '../controllers/auth_controller.dart';
import '../controllers/calendar_controller.dart';
import '../controllers/finance_controller.dart';
import '../controllers/habits_controller.dart';
import '../controllers/notes_controller.dart';
import '../controllers/task_controller.dart';

/// Load or remove the signed-in account's sample data, with a plain
/// progress message and a plain result message.
Future<void> toggleSampleData(BuildContext context) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  final removing = DemoDataSeeder.isDemoMode.value;
  messenger?.hideCurrentSnackBar();
  messenger?.showSnackBar(
    SnackBar(
      content: Text(
        removing ? 'Removing sample data...' : 'Loading sample data...',
      ),
      duration: const Duration(seconds: 2),
    ),
  );
  final ok = removing
      ? await DemoDataSeeder.clearDemoData()
      : await DemoDataSeeder.seedAll();
  messenger?.hideCurrentSnackBar();
  messenger?.showSnackBar(
    SnackBar(
      content: Text(
        ok
            ? (removing ? 'Sample data removed.' : 'Sample data loaded.')
            : (DemoDataSeeder.lastError ??
                  (removing
                      ? 'Could not remove all the sample data.'
                      : 'Could not load all the sample data.')),
      ),
      duration: const Duration(seconds: 3),
    ),
  );
}

/// Dashboard card shown only while the account has no data at all. It also
/// keeps the sample-data state in step with the signed-in account.
class SampleDataPrompt extends StatefulWidget {
  const SampleDataPrompt({super.key});

  static const message =
      'Your space is empty. Load sample data to see how everything looks.';

  @override
  State<SampleDataPrompt> createState() => _SampleDataPromptState();
}

class _SampleDataPromptState extends State<SampleDataPrompt> {
  Worker? _userWorker;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    unawaited(DemoDataSeeder.checkStatus());
    if (Get.isRegistered<AuthController>()) {
      _userWorker = ever(Get.find<AuthController>().currentUser, (_) {
        unawaited(DemoDataSeeder.checkStatus());
      });
    }
  }

  @override
  void dispose() {
    _userWorker?.dispose();
    super.dispose();
  }

  /// False while any module is still on its first load.
  bool _isEmpty() {
    var empty = true;
    void check(bool registered, bool Function() loaded, bool Function() none) {
      if (!registered) return;
      if (!loaded()) {
        empty = false;
        return;
      }
      if (!none()) empty = false;
    }

    final tasks = Get.isRegistered<TaskController>()
        ? Get.find<TaskController>()
        : null;
    final events = Get.isRegistered<CalendarController>()
        ? Get.find<CalendarController>()
        : null;
    final notes = Get.isRegistered<NotesController>()
        ? Get.find<NotesController>()
        : null;
    final habits = Get.isRegistered<HabitsController>()
        ? Get.find<HabitsController>()
        : null;
    final money = Get.isRegistered<FinanceController>()
        ? Get.find<FinanceController>()
        : null;
    check(
      tasks != null,
      () => tasks!.hasLoaded.value,
      () => tasks!.tasks.isEmpty,
    );
    check(
      events != null,
      () => events!.hasLoaded.value,
      () => events!.events.isEmpty,
    );
    check(
      notes != null,
      () => notes!.hasLoaded.value,
      () => notes!.notes.isEmpty,
    );
    check(
      habits != null,
      () => habits!.hasLoaded.value,
      () => habits!.habits.isEmpty,
    );
    check(
      money != null,
      () => money!.hasLoaded.value,
      () => money!.transactions.isEmpty,
    );
    return empty;
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final signedIn =
          Get.isRegistered<AuthController>() &&
          Get.find<AuthController>().currentUser.value != null;
      final show = signedIn && !DemoDataSeeder.isDemoMode.value && _isEmpty();
      if (!show) return const SizedBox.shrink();

      final theme = Theme.of(context);
      return Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.sectionGap),
        child: Container(
          key: const ValueKey('sample_data_prompt'),
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: AppRadius.cardRadius,
            border: Border.all(color: theme.colorScheme.outline),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(SampleDataPrompt.message, style: theme.textTheme.bodyMedium),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  key: const ValueKey('sample_data_prompt_button'),
                  onPressed: _busy
                      ? null
                      : () async {
                          setState(() => _busy = true);
                          await toggleSampleData(context);
                          if (mounted) setState(() => _busy = false);
                        },
                  icon: const Icon(Icons.science_outlined, size: 16),
                  label: Text(_busy ? 'Loading...' : 'Load sample data'),
                ),
              ),
            ],
          ),
        ),
      );
    });
  }
}

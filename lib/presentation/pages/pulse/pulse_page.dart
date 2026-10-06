import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../app/routes/app_routes.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../domain/entities/life_event.dart';
import '../../../domain/services/pulse/timeline_builder.dart';
import '../../controllers/pulse_controller.dart';
import '../../widgets/app_error_view.dart';
import '../../widgets/app_loading_view.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/pulse/day_replay_card.dart';
import '../../widgets/pulse/pulse_quick_log.dart';
import '../../widgets/pulse/pulse_timeline.dart';
import '../../widgets/section_label.dart';
import '../../widgets/sync_status_indicator.dart';

/// OmniPulse: capture a moment in one tap, then see the day as a timeline
/// and a factual replay.
class PulsePage extends StatefulWidget {
  const PulsePage({super.key});

  @override
  State<PulsePage> createState() => _PulsePageState();
}

class _PulsePageState extends State<PulsePage> {
  final PulseController c = Get.find<PulseController>();

  @override
  void initState() {
    super.initState();
    c.goToday();
    c.refreshOpenSleep();
  }

  @override
  Widget build(BuildContext context) {
    final gutter = AppSpacing.responsiveGutter(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pulse'),
        actions: [
          const Padding(
            padding: EdgeInsets.only(right: AppSpacing.sm),
            child: Center(child: SyncStatusIndicator()),
          ),
          IconButton(
            tooltip: 'Insights',
            icon: const Icon(Icons.insights_outlined),
            onPressed: () => Get.toNamed(AppRoutes.insights),
          ),
          IconButton(
            tooltip: 'Sleep history',
            icon: const Icon(Icons.bedtime_outlined),
            onPressed: () => Get.toNamed(AppRoutes.sleep),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: RefreshIndicator(
              onRefresh: () async {
                await c.loadDay();
                await c.refreshOpenSleep();
              },
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(gutter, 8, gutter, 48),
                children: [
                  _DayNavigator(controller: c),
                  const SizedBox(height: AppSpacing.md),
                  const SectionLabel(title: 'Log a moment'),
                  const PulseQuickLog(),
                  const SizedBox(height: AppSpacing.sectionGap),
                  _Body(controller: c),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.controller});

  final PulseController controller;

  @override
  Widget build(BuildContext context) => Obx(() => _content(context));

  Widget _content(BuildContext context) {
    final view = controller.dayView.value;
    if (controller.isLoading.value && view == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
        child: AppLoadingView(message: 'Loading your day'),
      );
    }
    if (controller.error.value != null && view == null) {
      return AppErrorView(
        message: controller.error.value!,
        onRetry: controller.loadDay,
      );
    }
    if (view == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionLabel(title: 'Your day'),
        DayReplayCard(replay: view.replay),
        const SizedBox(height: AppSpacing.sectionGap),
        const SectionLabel(title: 'Timeline'),
        if (view.timeline.isEmpty)
          const EmptyState(
            icon: Icons.timeline_outlined,
            message:
                'Nothing logged yet. Tap a button above to record a moment.',
          )
        else
          PulseTimeline(
            entries: view.timeline,
            onTapEntry: (entry) => _edit(context, view.events, entry),
          ),
      ],
    );
  }

  Future<void> _edit(
    BuildContext context,
    List<LifeEvent> events,
    TimelineEntry entry,
  ) async {
    final event = events.where((e) => e.id == entry.eventId).firstOrNull;
    if (event == null) return;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                0,
                AppSpacing.lg,
                AppSpacing.sm,
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '${entry.title} · ${DateFormat('h:mm a').format(event.timestamp)}',
                  style: Theme.of(ctx).textTheme.titleSmall,
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.schedule),
              title: const Text('Change time'),
              onTap: () async {
                Navigator.of(ctx).pop();
                final picked = await showTimePicker(
                  context: context,
                  initialTime: TimeOfDay.fromDateTime(event.timestamp),
                );
                if (picked == null) return;
                final t = event.timestamp;
                await controller.correctTime(
                  event,
                  DateTime(t.year, t.month, t.day, picked.hour, picked.minute),
                );
              },
            ),
            ListTile(
              leading: Icon(
                Icons.delete_outline,
                color: Theme.of(ctx).colorScheme.error,
              ),
              title: const Text('Delete'),
              onTap: () async {
                Navigator.of(ctx).pop();
                await controller.undo(event);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _DayNavigator extends StatelessWidget {
  const _DayNavigator({required this.controller});

  final PulseController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final day = controller.selectedDay.value;
      final today = controller.isToday;
      return Row(
        children: [
          IconButton(
            tooltip: 'Previous day',
            icon: const Icon(Icons.chevron_left),
            onPressed: controller.previousDay,
          ),
          Expanded(
            child: Text(
              today
                  ? 'Today, ${DateFormat('d MMM').format(day)}'
                  : DateFormat('EEEE, d MMM').format(day),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          IconButton(
            tooltip: 'Next day',
            icon: const Icon(Icons.chevron_right),
            onPressed: today ? null : controller.nextDay,
          ),
        ],
      );
    });
  }
}

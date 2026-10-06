import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/theme/app_semantic_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/services/sensors/sensor_service.dart';
import '../../controllers/sensors_controller.dart';
import '../../widgets/access_state_card.dart';
import '../../widgets/app_loading_view.dart';
import '../../widgets/app_section_container.dart';
import '../../widgets/sensors/steps_bar_chart.dart';

/// Steps today vs goal, 7-day history, and the face-down detector.
class SensorsPage extends StatefulWidget {
  const SensorsPage({super.key});

  @override
  State<SensorsPage> createState() => _SensorsPageState();
}

class _SensorsPageState extends State<SensorsPage> {
  late final SensorsController _c = Get.find<SensorsController>();
  Worker? _noticeWorker;

  @override
  void initState() {
    super.initState();
    _noticeWorker = ever<String?>(_c.notice, (msg) {
      if (msg == null || !mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(msg)));
      _c.notice.value = null;
    });
  }

  @override
  void dispose() {
    _noticeWorker?.dispose();
    // The accelerometer must never keep sampling after leaving the screen.
    _c.setFlipDetection(false);
    super.dispose();
  }

  Future<void> _editGoal() async {
    final controller = TextEditingController(
      text: _c.goal.value?.toString() ?? '',
    );
    final result = await showDialog<_GoalResult>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Daily step goal'),
        content: TextField(
          key: const Key('goal_field'),
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(hintText: 'For example 8000'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          if (_c.goal.value != null)
            TextButton(
              onPressed: () => Navigator.pop(ctx, const _GoalResult(null)),
              child: const Text('Clear goal'),
            ),
          FilledButton(
            key: const Key('goal_save_button'),
            onPressed: () {
              final n = int.tryParse(controller.text.trim());
              if (n == null || n < 100 || n > 100000) return;
              Navigator.pop(ctx, _GoalResult(n));
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (result != null) await _c.setGoal(result.steps);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sensors')),
      body: Obx(() {
        if (_c.isLoading.value) {
          return const AppLoadingView(message: 'Loading your steps');
        }
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.screenPadding),
              children: [
                _stepsSection(context),
                const SizedBox(height: AppSpacing.md),
                AppSectionContainer(
                  title: 'Last 7 days',
                  child: StepsBarChart(
                    days: _c.week.toList(),
                    goal: _c.goal.value,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                _flipSection(context),
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget _stepsSection(BuildContext context) {
    final theme = Theme.of(context);
    final muted = context.semanticColors.mutedText;
    final goal = _c.goal.value;
    final progress = _c.goalProgress;
    final access = _c.stepAccess.value;

    Widget status;
    if (!_c.isSupported || access == SensorAccess.unsupported) {
      status = const AccessStateCard(
        icon: Icons.info_outline,
        title: 'Step counting is not available here',
        message:
            'Steps come from the motion sensors of an Android or iOS phone. '
            'This device or browser has none, so only saved history can be '
            'shown.',
      );
    } else if (access == SensorAccess.deniedForever) {
      status = AccessStateCard(
        icon: Icons.directions_walk,
        title: 'Activity permission is blocked',
        message:
            'OmniLife cannot count steps without the physical activity '
            'permission. Allow it in settings, then come back.',
        primaryLabel: 'Open settings',
        onPrimary: _c.openSettings,
        secondaryLabel: 'Check again',
        onSecondary: _c.recheckAccess,
      );
    } else if (!_c.trackingEnabled.value || access != SensorAccess.granted) {
      status = AccessStateCard(
        icon: Icons.directions_walk,
        title: access == SensorAccess.denied && _c.trackingEnabled.value
            ? 'Step permission was turned off'
            : 'Count your steps',
        message:
            'Uses your phone\'s step counter, which is light on battery. '
            'Android asks for the physical activity permission when you '
            'turn this on.',
        primaryLabel: 'Turn on step tracking',
        onPrimary: _c.enableTracking,
        busy: _c.isRequesting.value,
      );
    } else {
      status = Row(
        children: [
          Icon(
            _c.hasReading.value ? Icons.check_circle_outline : Icons.sync,
            size: 18,
            color: muted,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              _c.hasReading.value
                  ? 'Tracking is on'
                  : 'Tracking is on. Waiting for the first reading.',
              style: theme.textTheme.bodySmall?.copyWith(color: muted),
            ),
          ),
          TextButton(
            onPressed: _c.disableTracking,
            child: const Text('Turn off'),
          ),
        ],
      );
    }

    return AppSectionContainer(
      title: 'Steps today',
      trailing: TextButton(
        key: const Key('edit_goal_button'),
        onPressed: _editGoal,
        child: Text(goal == null ? 'Set goal' : 'Edit goal'),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '${_c.todaySteps.value}',
                key: const Key('today_steps_value'),
                style: theme.textTheme.displaySmall?.copyWith(
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Flexible(
                child: Text(
                  goal == null ? 'steps' : 'of $goal steps',
                  style: theme.textTheme.bodyMedium?.copyWith(color: muted),
                ),
              ),
            ],
          ),
          if (progress != null) ...[
            const SizedBox(height: AppSpacing.sm),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                key: const Key('goal_progress'),
                value: progress,
                minHeight: 6,
                backgroundColor: theme.colorScheme.outline,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          status,
        ],
      ),
    );
  }

  Widget _flipSection(BuildContext context) {
    final theme = Theme.of(context);
    final muted = context.semanticColors.mutedText;
    if (!_c.isSupported) {
      return const AccessStateCard(
        icon: Icons.screen_rotation_alt_outlined,
        title: 'Face-down detection is not available here',
        message: 'It needs the accelerometer of an Android or iOS phone.',
      );
    }
    final down = _c.faceDown.value;
    final label = !_c.flipActive.value
        ? 'Off. The motion sensor is only used while this is on.'
        : down == null
        ? 'Listening. Hold the phone steady for a moment.'
        : down
        ? 'Phone is face down'
        : 'Phone is face up';
    return AppSectionContainer(
      title: 'Face-down detection',
      child: SwitchListTile(
        key: const Key('flip_switch'),
        contentPadding: EdgeInsets.zero,
        title: Text(label, key: const Key('flip_status')),
        subtitle: Text(
          'Samples the accelerometer only while you are on this screen.',
          style: theme.textTheme.bodySmall?.copyWith(color: muted),
        ),
        value: _c.flipActive.value,
        onChanged: _c.setFlipDetection,
      ),
    );
  }
}

class _GoalResult {
  const _GoalResult(this.steps);
  final int? steps;
}

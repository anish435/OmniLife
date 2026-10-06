import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/theme/app_radius.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/services/push_messaging_service.dart';
import '../../controllers/push_controller.dart';

/// Opt-in switch for push notifications plus topic subscriptions.
///
/// The OS permission prompt is only ever triggered from this switch. Renders
/// nothing when push is not wired up (for example in tests).
class PushSettingsSection extends StatelessWidget {
  const PushSettingsSection({super.key});

  @override
  Widget build(BuildContext context) {
    if (!Get.isRegistered<PushController>()) return const SizedBox.shrink();
    final controller = Get.find<PushController>();
    final theme = Theme.of(context);
    final hairline = theme.colorScheme.outline;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.mdPlus),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: AppRadius.cardRadius,
        border: Border.all(color: hairline),
      ),
      child: Obx(() {
        if (!controller.supported.value) {
          return Padding(
            padding: const EdgeInsets.all(AppSpacing.smPlus),
            child: Text(
              'Push notifications are not available on this device. '
              'Reminders still appear while the app is installed.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          );
        }
        final blocked =
            controller.permission.value == PushPermission.permanentlyDenied;
        return Column(
          children: [
            SwitchListTile(
              key: const Key('push_enable_switch'),
              title: const Text('Push notifications'),
              subtitle: Text(
                blocked
                    ? 'Blocked by the system. Enable OmniLife in device '
                          'settings.'
                    : 'Reminders and updates when the app is closed',
              ),
              value: controller.enabled.value,
              onChanged: controller.busy.value
                  ? null
                  : (v) => _run(context, controller.setEnabled(v)),
            ),
            if (controller.enabled.value) ...[
              Divider(height: 1, color: hairline),
              _topic(
                context,
                controller,
                PushTopics.announcements,
                'Announcements',
              ),
              _topic(context, controller, PushTopics.tips, 'Tips'),
            ],
          ],
        );
      }),
    );
  }

  Widget _topic(
    BuildContext context,
    PushController controller,
    String topic,
    String label,
  ) {
    return SwitchListTile(
      key: Key('push_topic_$topic'),
      dense: true,
      title: Text(label),
      value: controller.topics.contains(topic),
      onChanged: (v) => _run(context, controller.setTopic(topic, v)),
    );
  }

  Future<void> _run(BuildContext context, Future<String> action) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final message = await action;
    messenger
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

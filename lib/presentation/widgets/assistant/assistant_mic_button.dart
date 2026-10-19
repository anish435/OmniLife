import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/routes/app_routes.dart';

/// Opens the assistant already listening. Reachable from the dashboard.
void openAssistantListening() =>
    Get.toNamed(AppRoutes.assistant, arguments: const {'listen': true});

/// Compact mic for app bars and header rows.
class AssistantMicAction extends StatelessWidget {
  const AssistantMicAction({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Talk to the assistant',
      onPressed: openAssistantListening,
      icon: const Icon(Icons.mic_none_outlined, size: 22),
    );
  }
}

/// A small, quiet mic that sits in a corner of a screen. Outlined rather
/// than filled, so it never competes with the screen's main action.
class AssistantMicFab extends StatelessWidget {
  const AssistantMicFab({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surface,
      shape: CircleBorder(
        side: BorderSide(color: theme.colorScheme.outline, width: 1),
      ),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: openAssistantListening,
        child: Tooltip(
          message: 'Talk to the assistant',
          child: SizedBox(
            width: 44,
            height: 44,
            child: Icon(
              Icons.mic_none_outlined,
              size: 22,
              color: theme.colorScheme.primary,
            ),
          ),
        ),
      ),
    );
  }
}

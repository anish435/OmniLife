import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app/theme/app_semantic_colors.dart';
import '../../core/sync/sync_engine.dart';
import '../controllers/sync_controller.dart';

/// A restrained one-line sync state: a dot and a short label. Tap when
/// failed to retry. Hidden if sync is not set up (e.g. in widget tests).
class SyncStatusIndicator extends StatelessWidget {
  const SyncStatusIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    if (!Get.isRegistered<SyncController>()) return const SizedBox.shrink();
    final controller = Get.find<SyncController>();
    final semantic = context.semanticColors;
    final scheme = Theme.of(context).colorScheme;

    return Obx(() {
      final s = controller.snapshot.value;
      final (String label, Color color) = switch (s.status) {
        SyncStatus.synced => ('Synced', semantic.success),
        SyncStatus.syncing => ('Syncing', semantic.info),
        SyncStatus.offline => (
          s.pendingCount == 0
              ? 'Offline'
              : 'Offline, ${s.pendingCount} pending',
          semantic.warning,
        ),
        SyncStatus.pending => ('${s.pendingCount} pending', semantic.warning),
        SyncStatus.failed => ('Sync failed, tap to retry', scheme.error),
      };
      final child = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(label, style: Theme.of(context).textTheme.labelSmall),
        ],
      );
      return Semantics(
        label: 'Sync status: $label',
        button: s.status == SyncStatus.failed,
        child: s.status == SyncStatus.failed
            ? InkWell(onTap: controller.retry, child: child)
            : child,
      );
    });
  }
}

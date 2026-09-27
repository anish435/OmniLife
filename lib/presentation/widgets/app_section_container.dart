import 'package:flutter/material.dart';

import '../../app/theme/app_spacing.dart';

/// A titled, bordered section container — the standard way related
/// content is grouped on dashboard-style screens. Justified use of a
/// card: it groups genuinely related information, not decoration.
class AppSectionContainer extends StatelessWidget {
  const AppSectionContainer({
    super.key,
    required this.title,
    required this.child,
    this.trailing,
  });

  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(title, style: theme.textTheme.titleMedium),
                ),
                ?trailing,
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            child,
          ],
        ),
      ),
    );
  }
}

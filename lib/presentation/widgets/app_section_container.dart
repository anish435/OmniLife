import 'package:flutter/material.dart';

import '../../app/theme/app_spacing.dart';
import 'section_label.dart';

/// Clean semantic section container for dashboard and overview screens.
///
/// Replaces generic card-in-a-card templates with editorial uppercase
/// section labels, crisp spacing rhythm, and optional trailing controls.
class AppSectionContainer extends StatelessWidget {
  const AppSectionContainer({
    super.key,
    required this.title,
    required this.child,
    this.trailing,
    this.useCard = false,
  });

  final String title;
  final Widget child;
  final Widget? trailing;
  final bool useCard;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        SectionLabel(
          title: title,
          trailing: trailing,
        ),
        if (useCard)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: child,
            ),
          )
        else
          child,
        const SizedBox(height: AppSpacing.sectionGap),
      ],
    );
  }
}

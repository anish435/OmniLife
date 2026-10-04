import 'package:flutter/material.dart';

import '../../app/theme/app_semantic_colors.dart';
import '../../app/theme/app_typography.dart';

/// Section heading label: 12px uppercase, +0.8 tracking, tertiary color.
class SectionLabel extends StatelessWidget {
  const SectionLabel({
    super.key,
    required this.title,
    this.trailing,
    this.padding = const EdgeInsets.only(bottom: 8),
  });

  final String title;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final semantic = context.semanticColors;

    return Padding(
      padding: padding,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title.toUpperCase(),
            style: AppTypography.sectionLabel(semantic.tertiaryText),
          ),
          if (trailing case final Widget tr) tr,
        ],
      ),
    );
  }
}

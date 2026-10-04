import 'package:flutter/material.dart';

import '../../app/theme/app_spacing.dart';

/// Standard frame for modal bottom sheets:
/// - 20px top corner radius
/// - Minimalist drag handle
/// - Crisp title bar with close button
/// - Padding and scroll wrapper
class AppBottomSheetFrame extends StatelessWidget {
  const AppBottomSheetFrame({
    super.key,
    required this.title,
    required this.child,
    this.action,
  });

  final String title;
  final Widget child;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surface = theme.colorScheme.surface;
    final hairline = theme.colorScheme.outlineVariant.withValues(alpha: 0.5);

    return Container(
      decoration: BoxDecoration(
        color: surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border(top: BorderSide(color: hairline, width: 1)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Drag handle
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 10, bottom: 6),
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Title bar
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.gutterMobile,
                  vertical: 4,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      tooltip: 'Close',
                      visualDensity: VisualDensity.compact,
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),

              const Divider(height: 1),

              // Content
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(AppSpacing.gutterMobile),
                  child: child,
                ),
              ),

              // Action button row
              if (action case final act) ...[
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.gutterMobile),
                  child: act,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

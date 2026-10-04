import 'package:flutter/material.dart';

import '../../app/theme/app_radius.dart';

/// Outlined 1px hairline secondary button.
class SecondaryButton extends StatelessWidget {
  const SecondaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.isFullWidth = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final Widget? icon;
  final bool isFullWidth;

  @override
  Widget build(BuildContext context) {
    Widget child;
    if (icon != null) {
      child = Row(
        mainAxisSize: isFullWidth ? MainAxisSize.max : MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          icon!,
          const SizedBox(width: 8),
          Text(label),
        ],
      );
    } else {
      child = Text(label);
    }

    final button = OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: AppRadius.inputRadius),
      ),
      child: child,
    );

    if (isFullWidth) {
      return SizedBox(
        width: double.infinity,
        child: button,
      );
    }

    return button;
  }
}

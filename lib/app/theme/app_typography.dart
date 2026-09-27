import 'package:flutter/material.dart';

/// Centralized text styles, built on top of a [TextTheme] so Material
/// widgets pick them up automatically via `Theme.of(context).textTheme`.
abstract final class AppTypography {
  static TextTheme textTheme(ColorScheme scheme) {
    return TextTheme(
      headlineMedium: TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.w600,
        color: scheme.onSurface,
      ),
      titleLarge: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: scheme.onSurface,
      ),
      titleMedium: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: scheme.onSurface,
      ),
      bodyLarge: TextStyle(fontSize: 16, color: scheme.onSurface),
      bodyMedium: TextStyle(fontSize: 14, color: scheme.onSurfaceVariant),
    );
  }
}

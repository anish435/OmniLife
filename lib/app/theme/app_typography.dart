import 'package:flutter/material.dart';

/// Centralized text styles, built on top of a [TextTheme] so Material
/// widgets pick them up automatically via `Theme.of(context).textTheme`.
///
/// Deliberately restrained sizes — no marketing-scale headings. Roughly:
/// displaySmall/headlineSmall = page/section titles, titleMedium/Small =
/// sub-headings, bodyLarge/Medium = content, labelLarge = buttons,
/// bodySmall/labelSmall = captions and muted secondary text.
abstract final class AppTypography {
  static TextTheme textTheme(ColorScheme scheme, Color mutedText) {
    return TextTheme(
      displaySmall: TextStyle(
        fontSize: 26,
        fontWeight: FontWeight.w600,
        color: scheme.onSurface,
      ),
      headlineSmall: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        color: scheme.onSurface,
      ),
      titleLarge: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: scheme.onSurface,
      ),
      titleMedium: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: scheme.onSurface,
      ),
      titleSmall: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: scheme.onSurface,
      ),
      bodyLarge: TextStyle(fontSize: 15, color: scheme.onSurface),
      bodyMedium: TextStyle(fontSize: 14, color: scheme.onSurface),
      bodySmall: TextStyle(fontSize: 12, color: mutedText),
      labelLarge: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: scheme.onSurface,
      ),
      labelMedium: TextStyle(fontSize: 12, color: mutedText),
      labelSmall: TextStyle(fontSize: 11, color: mutedText),
    );
  }
}

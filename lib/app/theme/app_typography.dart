import 'package:flutter/material.dart';

/// Centralized typographic scale for OmniLife.
///
/// Follows an editorial, restrained hierarchy:
/// - Display: 32 / w600
/// - Title: 20 / w600
/// - Section label: 12 / w600 uppercase +0.8 tracking in tertiary color
/// - Body: 15 / w400
/// - Caption: 12 / w400
///
/// Tabular figures are enabled for numbers/dates/times.
abstract final class AppTypography {
  static const tabularFontFeatures = [FontFeature.tabularFigures()];

  static TextTheme textTheme({
    required Color textPrimary,
    required Color textSecondary,
    required Color textTertiary,
  }) {
    return TextTheme(
      // Display: 32 / w600
      displayLarge: TextStyle(
        fontSize: 32,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.6,
        color: textPrimary,
      ),
      displayMedium: TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.5,
        color: textPrimary,
      ),
      displaySmall: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.4,
        color: textPrimary,
      ),

      // Headline / Large Titles
      headlineMedium: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.3,
        color: textPrimary,
      ),
      headlineSmall: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
        color: textPrimary,
      ),

      // Title: 20 / w600
      titleLarge: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
        color: textPrimary,
      ),
      titleMedium: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: textPrimary,
      ),
      titleSmall: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: textPrimary,
      ),

      // Body: 15 / w400
      bodyLarge: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w400,
        height: 1.45,
        color: textPrimary,
      ),
      bodyMedium: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        height: 1.45,
        color: textPrimary,
      ),
      bodySmall: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        height: 1.4,
        color: textSecondary,
      ),

      // Labels & Buttons
      labelLarge: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.1,
        color: textPrimary,
      ),
      labelMedium: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.4,
        color: textSecondary,
      ),
      // Section label: 12 / w600 uppercase +0.8 tracking in tertiary color
      labelSmall: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.8,
        color: textTertiary,
      ),
    );
  }

  /// Helper for section labels (12 / w600 uppercase +0.8 tracking in tertiary color)
  static TextStyle sectionLabel(Color tertiaryColor) => TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.8,
        color: tertiaryColor,
      );

  /// Tabular figure style helper for timestamps, metrics, counters
  static TextStyle tabular(TextStyle base) => base.copyWith(
        fontFeatures: [...?base.fontFeatures, ...tabularFontFeatures],
      );
}

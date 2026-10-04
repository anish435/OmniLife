import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_radius.dart';
import 'app_semantic_colors.dart';
import 'app_typography.dart';

/// The single source of truth for OmniLife's warm, editorial, restrained themes.
abstract final class AppTheme {
  static ThemeData get light => _build(
        brightness: Brightness.light,
        background: AppColors.lightBackground,
        surface: AppColors.lightSurface,
        surfaceRaised: AppColors.lightSurfaceRaised,
        hairline: AppColors.lightHairline,
        textPrimary: AppColors.lightTextPrimary,
        textSecondary: AppColors.lightTextSecondary,
        textTertiary: AppColors.lightTextTertiary,
        accent: AppColors.accentTerracottaLight,
        accentSoft: AppColors.accentSoftLight,
        error: AppColors.error,
        semanticColors: AppSemanticColors.light,
      );

  static ThemeData get dark => _build(
        brightness: Brightness.dark,
        background: AppColors.darkBackground,
        surface: AppColors.darkSurface,
        surfaceRaised: AppColors.darkSurfaceRaised,
        hairline: AppColors.darkHairline,
        textPrimary: AppColors.darkTextPrimary,
        textSecondary: AppColors.darkTextSecondary,
        textTertiary: AppColors.darkTextTertiary,
        accent: AppColors.accentTerracottaDark,
        accentSoft: AppColors.accentSoftDark,
        error: AppColors.error,
        semanticColors: AppSemanticColors.dark,
      );

  static ThemeData _build({
    required Brightness brightness,
    required Color background,
    required Color surface,
    required Color surfaceRaised,
    required Color hairline,
    required Color textPrimary,
    required Color textSecondary,
    required Color textTertiary,
    required Color accent,
    required Color accentSoft,
    required Color error,
    required AppSemanticColors semanticColors,
  }) {
    final isDark = brightness == Brightness.dark;

    final colorScheme = ColorScheme(
      brightness: brightness,
      primary: accent,
      onPrimary: Colors.white,
      primaryContainer: accentSoft,
      onPrimaryContainer: isDark ? const Color(0xFFF9D2C9) : const Color(0xFF7A2718),
      secondary: textSecondary,
      onSecondary: surface,
      secondaryContainer: surfaceRaised,
      onSecondaryContainer: textPrimary,
      tertiary: semanticColors.moduleCalendar,
      onTertiary: Colors.white,
      error: error,
      onError: Colors.white,
      surface: surface,
      onSurface: textPrimary,
      onSurfaceVariant: textSecondary,
      surfaceContainerHighest: surfaceRaised,
      outline: hairline,
      outlineVariant: hairline.withValues(alpha: 0.6),
    );

    final textTheme = AppTypography.textTheme(
      textPrimary: textPrimary,
      textSecondary: textSecondary,
      textTertiary: textTertiary,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: background,
      textTheme: textTheme,
      extensions: [semanticColors],

      // Restrained flat AppBar with subtle hairline bottom border
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        foregroundColor: textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge,
        iconTheme: IconThemeData(color: textPrimary, size: 22),
      ),

      // 1px hairline bordered cards, no floating blur or excessive shadows
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.cardRadius,
          side: BorderSide(color: hairline, width: 1),
        ),
      ),

      dividerTheme: DividerThemeData(
        color: hairline,
        thickness: 1,
        space: 1,
      ),

      iconTheme: IconThemeData(color: textSecondary, size: 20),

      // Solid accent primary buttons
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: accent,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: AppRadius.inputRadius),
          textStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          elevation: 0,
          backgroundColor: accent,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: AppRadius.inputRadius),
          textStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
      ),

      // 1px hairline outlined secondary buttons
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          elevation: 0,
          foregroundColor: textPrimary,
          side: BorderSide(color: hairline, width: 1),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: AppRadius.inputRadius),
          textStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: accent,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          shape: RoundedRectangleBorder(borderRadius: AppRadius.chipRadius),
          textStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
      ),

      // Input fields: 8px radius, subtle surface fill, 1px hairline border
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceRaised,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: textTheme.bodyMedium?.copyWith(color: textTertiary),
        labelStyle: textTheme.bodyMedium?.copyWith(color: textSecondary),
        border: OutlineInputBorder(
          borderRadius: AppRadius.inputRadius,
          borderSide: BorderSide(color: hairline, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.inputRadius,
          borderSide: BorderSide(color: hairline, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.inputRadius,
          borderSide: BorderSide(color: accent, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AppRadius.inputRadius,
          borderSide: BorderSide(color: error, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: AppRadius.inputRadius,
          borderSide: BorderSide(color: error, width: 1.5),
        ),
      ),

      // Bottom sheets: 20px radius, clean solid surface
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        elevation: 4,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),

      // Dialogs: 12px radius, hairline border, no slop
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.cardRadius,
          side: BorderSide(color: hairline, width: 1),
        ),
        titleTextStyle: textTheme.titleLarge,
        contentTextStyle: textTheme.bodyMedium,
      ),

      // Date / Time picker dialog theme
      datePickerTheme: DatePickerThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        headerBackgroundColor: accent,
        headerForegroundColor: Colors.white,
        dividerColor: hairline,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.cardRadius,
          side: BorderSide(color: hairline, width: 1),
        ),
      ),

      timePickerTheme: TimePickerThemeData(
        backgroundColor: surface,
        dialBackgroundColor: surfaceRaised,
        dialHandColor: accent,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.cardRadius,
          side: BorderSide(color: hairline, width: 1),
        ),
      ),

      // Terracotta Accent FAB (never default blue)
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: accent,
        foregroundColor: Colors.white,
        elevation: 2,
        focusElevation: 2,
        hoverElevation: 3,
        highlightElevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),

      // Chips: 8px radius
      chipTheme: ChipThemeData(
        backgroundColor: surfaceRaised,
        disabledColor: surfaceRaised.withValues(alpha: 0.5),
        selectedColor: accentSoft,
        labelStyle: textTheme.labelMedium?.copyWith(color: textPrimary),
        secondaryLabelStyle: textTheme.labelMedium?.copyWith(color: accent),
        side: BorderSide(color: hairline, width: 1),
        shape: RoundedRectangleBorder(borderRadius: AppRadius.chipRadius),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      ),

      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return accent;
          return Colors.transparent;
        }),
        checkColor: WidgetStateProperty.all(Colors.white),
        side: BorderSide(color: textSecondary, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),

      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return Colors.white;
          return textTertiary;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return accent;
          return surfaceRaised;
        }),
        trackOutlineColor: WidgetStateProperty.all(hairline),
      ),

      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isDark ? const Color(0xFF262B30) : const Color(0xFF2E2C29),
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: AppRadius.inputRadius),
      ),

      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: surface,
        selectedIconTheme: IconThemeData(color: accent, size: 24),
        unselectedIconTheme: IconThemeData(color: textSecondary, size: 22),
        selectedLabelTextStyle: textTheme.labelSmall?.copyWith(color: accent, fontWeight: FontWeight.w600),
        unselectedLabelTextStyle: textTheme.labelSmall?.copyWith(color: textSecondary),
      ),

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        elevation: 0,
        indicatorColor: accentSoft,
        surfaceTintColor: Colors.transparent,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return textTheme.labelSmall?.copyWith(color: accent, fontWeight: FontWeight.w600);
          }
          return textTheme.labelSmall?.copyWith(color: textSecondary);
        }),
      ),
    );
  }
}

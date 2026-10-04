import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Semantic colors and module accents for OmniLife.
@immutable
class AppSemanticColors extends ThemeExtension<AppSemanticColors> {
  const AppSemanticColors({
    required this.mutedText,
    required this.tertiaryText,
    required this.hairline,
    required this.surfaceRaised,
    required this.accentSoft,
    required this.success,
    required this.onSuccess,
    required this.warning,
    required this.onWarning,
    required this.info,
    required this.onInfo,
    required this.moduleTasks,
    required this.moduleCalendar,
    required this.moduleNotes,
    required this.moduleHabits,
    required this.moduleFinance,
    required this.moduleWellness,
  });

  final Color mutedText;
  final Color tertiaryText;
  final Color hairline;
  final Color surfaceRaised;
  final Color accentSoft;

  final Color success;
  final Color onSuccess;
  final Color warning;
  final Color onWarning;
  final Color info;
  final Color onInfo;

  final Color moduleTasks;
  final Color moduleCalendar;
  final Color moduleNotes;
  final Color moduleHabits;
  final Color moduleFinance;
  final Color moduleWellness;

  Color get tasks => moduleTasks;
  Color get calendar => moduleCalendar;
  Color get notes => moduleNotes;
  Color get habits => moduleHabits;
  Color get finance => moduleFinance;
  Color get wellness => moduleWellness;

  static const light = AppSemanticColors(
    mutedText: AppColors.lightTextSecondary,
    tertiaryText: AppColors.lightTextTertiary,
    hairline: AppColors.lightHairline,
    surfaceRaised: AppColors.lightSurfaceRaised,
    accentSoft: AppColors.accentSoftLight,
    success: AppColors.success,
    onSuccess: Colors.white,
    warning: AppColors.warning,
    onWarning: Colors.white,
    info: AppColors.info,
    onInfo: Colors.white,
    moduleTasks: AppColors.moduleTasks,
    moduleCalendar: AppColors.moduleCalendar,
    moduleNotes: AppColors.moduleNotes,
    moduleHabits: AppColors.moduleHabits,
    moduleFinance: AppColors.moduleFinance,
    moduleWellness: AppColors.moduleWellness,
  );

  static const dark = AppSemanticColors(
    mutedText: AppColors.darkTextSecondary,
    tertiaryText: AppColors.darkTextTertiary,
    hairline: AppColors.darkHairline,
    surfaceRaised: AppColors.darkSurfaceRaised,
    accentSoft: AppColors.accentSoftDark,
    success: AppColors.success,
    onSuccess: Color(0xFF0C2414),
    warning: AppColors.warning,
    onWarning: Color(0xFF2C1E04),
    info: AppColors.info,
    onInfo: Color(0xFF082236),
    moduleTasks: AppColors.moduleTasks,
    moduleCalendar: AppColors.moduleCalendar,
    moduleNotes: AppColors.moduleNotes,
    moduleHabits: AppColors.moduleHabits,
    moduleFinance: AppColors.moduleFinance,
    moduleWellness: AppColors.moduleWellness,
  );

  @override
  AppSemanticColors copyWith({
    Color? mutedText,
    Color? tertiaryText,
    Color? hairline,
    Color? surfaceRaised,
    Color? accentSoft,
    Color? success,
    Color? onSuccess,
    Color? warning,
    Color? onWarning,
    Color? info,
    Color? onInfo,
    Color? moduleTasks,
    Color? moduleCalendar,
    Color? moduleNotes,
    Color? moduleHabits,
    Color? moduleFinance,
    Color? moduleWellness,
  }) {
    return AppSemanticColors(
      mutedText: mutedText ?? this.mutedText,
      tertiaryText: tertiaryText ?? this.tertiaryText,
      hairline: hairline ?? this.hairline,
      surfaceRaised: surfaceRaised ?? this.surfaceRaised,
      accentSoft: accentSoft ?? this.accentSoft,
      success: success ?? this.success,
      onSuccess: onSuccess ?? this.onSuccess,
      warning: warning ?? this.warning,
      onWarning: onWarning ?? this.onWarning,
      info: info ?? this.info,
      onInfo: onInfo ?? this.onInfo,
      moduleTasks: moduleTasks ?? this.moduleTasks,
      moduleCalendar: moduleCalendar ?? this.moduleCalendar,
      moduleNotes: moduleNotes ?? this.moduleNotes,
      moduleHabits: moduleHabits ?? this.moduleHabits,
      moduleFinance: moduleFinance ?? this.moduleFinance,
      moduleWellness: moduleWellness ?? this.moduleWellness,
    );
  }

  @override
  AppSemanticColors lerp(ThemeExtension<AppSemanticColors>? other, double t) {
    if (other is! AppSemanticColors) return this;
    return AppSemanticColors(
      mutedText: Color.lerp(mutedText, other.mutedText, t)!,
      tertiaryText: Color.lerp(tertiaryText, other.tertiaryText, t)!,
      hairline: Color.lerp(hairline, other.hairline, t)!,
      surfaceRaised: Color.lerp(surfaceRaised, other.surfaceRaised, t)!,
      accentSoft: Color.lerp(accentSoft, other.accentSoft, t)!,
      success: Color.lerp(success, other.success, t)!,
      onSuccess: Color.lerp(onSuccess, other.onSuccess, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      onWarning: Color.lerp(onWarning, other.onWarning, t)!,
      info: Color.lerp(info, other.info, t)!,
      onInfo: Color.lerp(onInfo, other.onInfo, t)!,
      moduleTasks: Color.lerp(moduleTasks, other.moduleTasks, t)!,
      moduleCalendar: Color.lerp(moduleCalendar, other.moduleCalendar, t)!,
      moduleNotes: Color.lerp(moduleNotes, other.moduleNotes, t)!,
      moduleHabits: Color.lerp(moduleHabits, other.moduleHabits, t)!,
      moduleFinance: Color.lerp(moduleFinance, other.moduleFinance, t)!,
      moduleWellness: Color.lerp(moduleWellness, other.moduleWellness, t)!,
    );
  }
}

extension AppSemanticColorsX on BuildContext {
  AppSemanticColors get semanticColors =>
      Theme.of(this).extension<AppSemanticColors>() ?? AppSemanticColors.dark;
}

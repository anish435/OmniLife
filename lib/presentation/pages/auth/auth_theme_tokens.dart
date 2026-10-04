import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';

/// Warm, editorial theme tokens for OmniLife authentication.
///
/// Strips out artificial violet/indigo neon gradients, replacing them with
/// warm terracotta accents, natural paper surfaces, and crisp hairline borders.
abstract final class AuthThemeTokens {
  // Light Palette — Warm paper
  static const lightBackground = AppColors.lightBackground;
  static const lightSurface = AppColors.lightSurface;
  static const lightPrimary = AppColors.accentTerracottaLight;
  static const lightTeal = AppColors.moduleHabits;
  static const lightAI = AppColors.moduleFinance;
  static const lightText = AppColors.lightTextPrimary;
  static const lightTextSecondary = AppColors.lightTextSecondary;
  static const lightBorder = AppColors.lightHairline;
  static const lightInputFill = AppColors.lightSurfaceRaised;

  // Dark Palette — Carbon slate
  static const darkBackground = AppColors.darkBackground;
  static const darkSurface = AppColors.darkSurface;
  static const darkPrimary = AppColors.accentTerracottaDark;
  static const darkTeal = AppColors.moduleHabits;
  static const darkAI = AppColors.moduleFinance;
  static const darkText = AppColors.darkTextPrimary;
  static const darkTextSecondary = AppColors.darkTextSecondary;
  static const darkBorder = AppColors.darkHairline;
  static const darkInputFill = AppColors.darkSurfaceRaised;

  static Color background(bool isDark) => isDark ? darkBackground : lightBackground;
  static Color surface(bool isDark) => isDark ? darkSurface : lightSurface;
  static Color primary(bool isDark) => isDark ? darkPrimary : lightPrimary;
  static Color teal(bool isDark) => isDark ? darkTeal : lightTeal;
  static Color ai(bool isDark) => isDark ? darkAI : lightAI;
  static Color text(bool isDark) => isDark ? darkText : lightText;
  static Color textSecondary(bool isDark) => isDark ? darkTextSecondary : lightTextSecondary;
  static Color border(bool isDark) => isDark ? darkBorder : lightBorder;
  static Color inputFill(bool isDark) => isDark ? darkInputFill : lightInputFill;
}

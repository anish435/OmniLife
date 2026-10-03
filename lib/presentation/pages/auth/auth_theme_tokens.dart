import 'package:flutter/material.dart';

/// Exact color palette requested for the OmniLife authentication redesign.
///
/// Light mode:
/// - Background: #F8F9FC
/// - Surface: #FFFFFF
/// - Primary: #6366F1 (Indigo)
/// - Teal: #14B8A6
/// - AI: #8B5CF6 (Violet)
/// - Text: #111827
///
/// Dark mode:
/// - Background: #0F172A
/// - Surface: #1E293B
/// - Primary: #818CF8 (Indigo)
/// - Teal: #2DD4BF
/// - AI: #A78BFA (Violet)
/// - Text: #F8FAFC
abstract final class AuthThemeTokens {
  // Light Palette
  static const lightBackground = Color(0xFFF8F9FC);
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightPrimary = Color(0xFF6366F1);
  static const lightTeal = Color(0xFF14B8A6);
  static const lightAI = Color(0xFF8B5CF6);
  static const lightText = Color(0xFF111827);
  static const lightTextSecondary = Color(0xFF64748B);
  static const lightBorder = Color(0xFFE2E8F0);
  static const lightInputFill = Color(0xFFF1F5F9);

  // Dark Palette
  static const darkBackground = Color(0xFF0F172A);
  static const darkSurface = Color(0xFF1E293B);
  static const darkPrimary = Color(0xFF818CF8);
  static const darkTeal = Color(0xFF2DD4BF);
  static const darkAI = Color(0xFFA78BFA);
  static const darkText = Color(0xFFF8FAFC);
  static const darkTextSecondary = Color(0xFF94A3B8);
  static const darkBorder = Color(0xFF334155);
  static const darkInputFill = Color(0xFF0F172A);

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

import 'package:flutter/material.dart';

/// Centralized color roles for OmniLife's warm, editorial, restrained palette.
///
/// Features an artisanal terracotta accent on warm paper (light) and
/// deep carbon-slate surfaces (dark) — strictly avoiding neon gradients
/// and generic purple SaaS slop.
abstract final class AppColors {
  // Primary brand accent: artisanal terracotta
  static const accentTerracottaDark = Color(0xFFE2725B);
  static const accentTerracottaLight = Color(0xFFC9553D);

  // Accent soft (14% alpha)
  static const accentSoftDark = Color(0x24E2725B);
  static const accentSoftLight = Color(0x24C9553D);

  // Dark palette (default) — warm carbon-slate
  static const darkBackground = Color(0xFF101214);
  static const darkSurface = Color(0xFF171A1D);
  static const darkSurfaceRaised = Color(0xFF1E2226);
  static const darkHairline = Color(0xFF2A2F34);
  static const darkTextPrimary = Color(0xFFECE9E4);
  static const darkTextSecondary = Color(0xFF9A9A94);
  static const darkTextTertiary = Color(0xFF6B6C68);

  // Light palette — warm paper, not white-on-gray
  static const lightBackground = Color(0xFFF6F3EE);
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightSurfaceRaised = Color(0xFFFBF9F5);
  static const lightHairline = Color(0xFFE4DFD6);
  static const lightTextPrimary = Color(0xFF1C1B18);
  static const lightTextSecondary = Color(0xFF6A675F);
  static const lightTextTertiary = Color(0xFF9A968C);

  // Module hues — muted, used only for small markers/left bars/icon tints
  static const moduleTasks = Color(0xFFE2725B);
  static const moduleCalendar = Color(0xFF6FA3C7);
  static const moduleNotes = Color(0xFFC9A86A);
  static const moduleHabits = Color(0xFF8DB596);
  static const moduleFinance = Color(0xFF7FB3AC);
  static const moduleWellness = Color(0xFFB592B8);

  // Semantic status colors
  static const success = Color(0xFF6FBF8E);
  static const warning = Color(0xFFE0B04F);
  static const error = Color(0xFFE5675F);
  static const info = Color(0xFF6FA3C7);

  // Backward-compatible aliases for legacy theme callers
  static const primary = accentTerracottaDark;
  static const secondary = Color(0xFF8B929A);
  static const lightSurfaceElevated = lightSurfaceRaised;
  static const lightBorder = lightHairline;
  static const lightText = lightTextPrimary;
  static const darkSurfaceElevated = darkSurfaceRaised;
  static const darkBorder = darkHairline;
  static const darkText = darkTextPrimary;
  static const errorDark = error;
}

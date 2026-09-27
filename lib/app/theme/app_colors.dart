import 'package:flutter/material.dart';

/// Centralized color roles.
///
/// Deliberately a calm slate-blue/graphite palette — no purple/violet
/// "AI" hues. Standard Material roles (primary, secondary, surface,
/// error, ...) are consumed via `Theme.of(context).colorScheme`, built
/// from these constants in [AppTheme]. Semantic roles Material doesn't
/// model (muted text, success/warning/info) live in [AppSemanticColors].
abstract final class AppColors {
  // Brand — a calm slate blue, not indigo/violet.
  static const primary = Color(0xFF2F5F86);
  static const secondary = Color(0xFF5C7A8A);

  // Light surfaces
  static const lightBackground = Color(0xFFF5F6F8);
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightSurfaceElevated = Color(0xFFEEF1F4);
  static const lightBorder = Color(0xFFDADFE3);
  static const lightText = Color(0xFF1B1F23);

  // Dark surfaces — near-black neutral graphite, not "black + accent".
  static const darkBackground = Color(0xFF15181C);
  static const darkSurface = Color(0xFF1D2126);
  static const darkSurfaceElevated = Color(0xFF262B32);
  static const darkBorder = Color(0xFF33383F);
  static const darkText = Color(0xFFE7EAED);

  static const error = Color(0xFFB3261E);
  static const errorDark = Color(0xFFE5867E);
}

import 'package:flutter/material.dart';

/// Centralized color palette. Widgets should read colors from the active
/// [ThemeData] (via `Theme.of(context)`), not from this class directly —
/// this is where the palette is *defined*, once.
abstract final class AppColors {
  static const Color primary = Color(0xFF3F51B5);
  static const Color secondary = Color(0xFF03A9F4);

  static const Color lightBackground = Color(0xFFF7F8FA);
  static const Color lightSurface = Colors.white;

  static const Color darkBackground = Color(0xFF121316);
  static const Color darkSurface = Color(0xFF1E1F23);

  static const Color error = Color(0xFFB3261E);
}

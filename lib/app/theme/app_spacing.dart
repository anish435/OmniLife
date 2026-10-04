import 'package:flutter/material.dart';

/// Centralized spacing scale based on a 4px rhythmic grid.
abstract final class AppSpacing {
  static const xxs = 2.0;
  static const xs = 4.0;
  static const sm = 8.0;
  static const smPlus = 12.0;
  static const md = 16.0;
  static const mdPlus = 20.0;
  static const lg = 24.0;
  static const xl = 32.0;
  static const xxl = 48.0;

  // Semantic layout distances
  static const sectionGap = 24.0;
  static const section = 32.0;
  static const minRowHeight = 48.0;

  // Responsive gutters
  static const gutterMobile = 16.0;
  static const gutterTablet = 24.0;
  static const gutterWeb = 32.0;
  static const screenPadding = 16.0;

  /// Helper to return responsive page gutter based on screen width
  static double responsiveGutter(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width >= 1000) return gutterWeb;
    if (width >= 600) return gutterTablet;
    return gutterMobile;
  }
}

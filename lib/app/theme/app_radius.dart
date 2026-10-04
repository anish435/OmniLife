import 'package:flutter/material.dart';

/// Centralized corner-radius scale for OmniLife.
///
/// Scale:
/// - 8 (chips, inputs, pill toggles)
/// - 12 (cards, dialogs, tiles)
/// - 20 (bottom sheets)
/// - Nothing above 20 except circular.
abstract final class AppRadius {
  static const small = 8.0;
  static const medium = 12.0;
  static const large = 20.0;

  static const smallRadius = BorderRadius.all(Radius.circular(small));
  static const mediumRadius = BorderRadius.all(Radius.circular(medium));
  static const largeRadius = BorderRadius.all(Radius.circular(large));

  static const chipRadius = BorderRadius.all(Radius.circular(small));
  static const inputRadius = BorderRadius.all(Radius.circular(small));
  static const cardRadius = BorderRadius.all(Radius.circular(medium));
  static const sheetRadius = BorderRadius.all(Radius.circular(large));
}

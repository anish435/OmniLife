import 'package:flutter/material.dart';

/// Centralized corner-radius scale. Deliberately restrained — OmniLife
/// avoids the heavily-rounded, "floating card" look common to AI/SaaS
/// product UIs.
abstract final class AppRadius {
  static const small = 6.0;
  static const medium = 10.0;
  static const large = 14.0;

  static const smallRadius = BorderRadius.all(Radius.circular(small));
  static const mediumRadius = BorderRadius.all(Radius.circular(medium));
  static const largeRadius = BorderRadius.all(Radius.circular(large));
}

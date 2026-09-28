import 'package:flutter/material.dart';

/// Color roles Material's [ColorScheme] doesn't model: muted/secondary
/// text, and status colors for success/warning/info. Read via
/// `Theme.of(context).extension<AppSemanticColors>()!` (or the
/// [BuildContext] extension below).
@immutable
class AppSemanticColors extends ThemeExtension<AppSemanticColors> {
  const AppSemanticColors({
    required this.mutedText,
    required this.success,
    required this.onSuccess,
    required this.warning,
    required this.onWarning,
    required this.info,
    required this.onInfo,
  });

  final Color mutedText;
  final Color success;
  final Color onSuccess;
  final Color warning;
  final Color onWarning;
  final Color info;
  final Color onInfo;

  static const light = AppSemanticColors(
    mutedText: Color(0xFF5B6570),
    success: Color(0xFF2E7D32),
    onSuccess: Colors.white,
    warning: Color(0xFF9A6B12),
    onWarning: Colors.white,
    info: Color(0xFF2F6690),
    onInfo: Colors.white,
  );

  static const dark = AppSemanticColors(
    mutedText: Color(0xFF9AA4AE),
    success: Color(0xFF6FBF73),
    onSuccess: Color(0xFF07240A),
    warning: Color(0xFFD9A441),
    onWarning: Color(0xFF2B1B00),
    info: Color(0xFF7FB2D8),
    onInfo: Color(0xFF00263A),
  );

  @override
  AppSemanticColors copyWith({
    Color? mutedText,
    Color? success,
    Color? onSuccess,
    Color? warning,
    Color? onWarning,
    Color? info,
    Color? onInfo,
  }) {
    return AppSemanticColors(
      mutedText: mutedText ?? this.mutedText,
      success: success ?? this.success,
      onSuccess: onSuccess ?? this.onSuccess,
      warning: warning ?? this.warning,
      onWarning: onWarning ?? this.onWarning,
      info: info ?? this.info,
      onInfo: onInfo ?? this.onInfo,
    );
  }

  @override
  AppSemanticColors lerp(ThemeExtension<AppSemanticColors>? other, double t) {
    if (other is! AppSemanticColors) return this;
    return AppSemanticColors(
      mutedText: Color.lerp(mutedText, other.mutedText, t)!,
      success: Color.lerp(success, other.success, t)!,
      onSuccess: Color.lerp(onSuccess, other.onSuccess, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      onWarning: Color.lerp(onWarning, other.onWarning, t)!,
      info: Color.lerp(info, other.info, t)!,
      onInfo: Color.lerp(onInfo, other.onInfo, t)!,
    );
  }
}

extension AppSemanticColorsX on BuildContext {
  AppSemanticColors get semanticColors =>
      Theme.of(this).extension<AppSemanticColors>()!;
}

import 'package:flutter/material.dart';

import '../../pages/auth/auth_theme_tokens.dart';
import '../google_sign_in_button.dart' show GoogleLogo;

/// Premium social authentication button (Google).
///
/// Features:
/// - Official 4-color Google logo
/// - Hover/press micro-interactions
/// - Integrated spinner state
/// - Polished border matching [AuthThemeTokens]
class SocialAuthButton extends StatelessWidget {
  const SocialAuthButton({
    super.key,
    required this.onPressed,
    this.isLoading = false,
    this.label = 'Continue with Google',
  });

  final VoidCallback? onPressed;
  final bool isLoading;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final borderColor = AuthThemeTokens.border(isDark);
    final surfaceColor = AuthThemeTokens.surface(isDark);
    final textColor = AuthThemeTokens.text(isDark);

    return SizedBox(
      width: double.infinity,
      height: 50,
      child: OutlinedButton(
        onPressed: isLoading ? null : onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: textColor,
          backgroundColor: isDark
              ? surfaceColor.withValues(alpha: 0.5)
              : Colors.white,
          side: BorderSide(
            color: borderColor.withValues(alpha: isDark ? 0.6 : 0.9),
            width: 1.1,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: isDark ? 0 : 0.5,
          padding: const EdgeInsets.symmetric(horizontal: 16),
        ),
        child: isLoading
            ? SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AuthThemeTokens.primary(isDark),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const GoogleLogo(size: 20),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      label,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: textColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 14.0,
                        letterSpacing: 0.1,
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

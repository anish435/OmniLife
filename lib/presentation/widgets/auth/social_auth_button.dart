import 'package:flutter/material.dart';

import '../../../app/theme/app_radius.dart';
import '../../pages/auth/auth_theme_tokens.dart';
import '../google_sign_in_button.dart' show GoogleLogo;

/// Clean social authentication button (Google).
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
      height: 48,
      child: OutlinedButton(
        onPressed: isLoading ? null : onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: textColor,
          backgroundColor: isDark ? surfaceColor : Colors.white,
          side: BorderSide(
            color: borderColor,
            width: 1.0,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: AppRadius.inputRadius,
          ),
          elevation: 0,
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
                  const GoogleLogo(size: 18),
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

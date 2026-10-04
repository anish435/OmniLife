import 'package:flutter/material.dart';

import '../../../app/theme/app_radius.dart';
import '../../pages/auth/auth_theme_tokens.dart';

enum AuthMode { signIn, signUp }

/// Animated segmented pill toggle between Sign In and Sign Up modes.
class AuthToggle extends StatelessWidget {
  const AuthToggle({
    super.key,
    required this.currentMode,
    required this.onChanged,
  });

  final AuthMode currentMode;
  final ValueChanged<AuthMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final primary = AuthThemeTokens.primary(isDark);
    final inputFill = AuthThemeTokens.inputFill(isDark);
    final textSecondary = AuthThemeTokens.textSecondary(isDark);
    final border = AuthThemeTokens.border(isDark);

    final isSignIn = currentMode == AuthMode.signIn;

    return Container(
      height: 42,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: inputFill,
        borderRadius: AppRadius.smallRadius,
        border: Border.all(color: border, width: 1),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final pillWidth = (constraints.maxWidth) / 2;

          return Stack(
            children: [
              // Animated sliding indicator
              AnimatedAlign(
                alignment: isSignIn ? Alignment.centerLeft : Alignment.centerRight,
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                child: Container(
                  width: pillWidth,
                  height: double.infinity,
                  decoration: BoxDecoration(
                    color: isDark ? AuthThemeTokens.surface(true) : Colors.white,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: border, width: 0.8),
                  ),
                ),
              ),

              // Labels row
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(6),
                      onTap: () => onChanged(AuthMode.signIn),
                      child: Center(
                        child: AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 180),
                          style: theme.textTheme.labelLarge!.copyWith(
                            fontWeight: isSignIn ? FontWeight.w700 : FontWeight.w500,
                            color: isSignIn ? primary : textSecondary,
                            fontSize: 13.5,
                          ),
                          child: const Text('Sign In'),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(6),
                      onTap: () => onChanged(AuthMode.signUp),
                      child: Center(
                        child: AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 180),
                          style: theme.textTheme.labelLarge!.copyWith(
                            fontWeight: !isSignIn ? FontWeight.w700 : FontWeight.w500,
                            color: !isSignIn ? primary : textSecondary,
                            fontSize: 13.5,
                          ),
                          child: const Text('Sign Up'),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

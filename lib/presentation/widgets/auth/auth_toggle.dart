import 'package:flutter/material.dart';

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

    final isSignIn = currentMode == AuthMode.signIn;

    return Container(
      height: 44,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: inputFill.withValues(alpha: isDark ? 0.8 : 0.7),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AuthThemeTokens.border(isDark).withValues(alpha: 0.5),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final pillWidth = (constraints.maxWidth) / 2;

          return Stack(
            children: [
              // Animated sliding indicator
              AnimatedAlign(
                alignment: isSignIn ? Alignment.centerLeft : Alignment.centerRight,
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOutCubic,
                child: Container(
                  width: pillWidth,
                  height: double.infinity,
                  decoration: BoxDecoration(
                    color: isDark ? AuthThemeTokens.surface(true) : Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ),

              // Labels row
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () => onChanged(AuthMode.signIn),
                      child: Center(
                        child: AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 200),
                          style: theme.textTheme.labelLarge!.copyWith(
                            fontWeight: isSignIn ? FontWeight.w700 : FontWeight.w500,
                            color: isSignIn ? primary : textSecondary,
                            fontSize: 14,
                          ),
                          child: const Text('Sign In'),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () => onChanged(AuthMode.signUp),
                      child: Center(
                        child: AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 200),
                          style: theme.textTheme.labelLarge!.copyWith(
                            fontWeight: !isSignIn ? FontWeight.w700 : FontWeight.w500,
                            color: !isSignIn ? primary : textSecondary,
                            fontSize: 14,
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

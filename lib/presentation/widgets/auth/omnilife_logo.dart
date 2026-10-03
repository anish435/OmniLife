import 'package:flutter/material.dart';

import '../../pages/auth/auth_theme_tokens.dart';

/// OmniLife branded emblem and typography.
///
/// Features:
/// - Interconnected gradient emblem (Indigo -> Teal -> AI Violet)
/// - "OmniLife" title
/// - "Your life, connected." tagline
class OmniLifeLogo extends StatelessWidget {
  const OmniLifeLogo({
    super.key,
    this.size = 56,
    this.showTagline = true,
  });

  final double size;
  final bool showTagline;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final primary = AuthThemeTokens.primary(isDark);
    final teal = AuthThemeTokens.teal(isDark);
    final ai = AuthThemeTokens.ai(isDark);
    final text = AuthThemeTokens.text(isDark);
    final textSecondary = AuthThemeTokens.textSecondary(isDark);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Glowing Gradient Emblem
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(size * 0.28),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [primary, teal, ai],
            ),
            boxShadow: [
              BoxShadow(
                color: primary.withValues(alpha: isDark ? 0.45 : 0.30),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
              BoxShadow(
                color: teal.withValues(alpha: isDark ? 0.35 : 0.20),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Center(
            child: Icon(
              Icons.all_inclusive_rounded,
              color: Colors.white,
              size: size * 0.58,
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Brand Name
        Text(
          'OmniLife',
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
            color: text,
          ),
        ),

        // Tagline
        if (showTagline) ...[
          const SizedBox(height: 4),
          Text(
            'Your life, connected.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: textSecondary,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.1,
            ),
          ),
        ],
      ],
    );
  }
}

import 'package:flutter/material.dart';

import '../../pages/auth/auth_theme_tokens.dart';

/// OmniLife handcrafted emblem and typography.
///
/// Strips out artificial SaaS gradient glow and replaces with a bold,
/// confident terracotta emblem and crisp editorial typography.
class OmniLifeLogo extends StatelessWidget {
  const OmniLifeLogo({
    super.key,
    this.size = 52,
    this.showTagline = true,
  });

  final double size;
  final bool showTagline;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final primary = AuthThemeTokens.primary(isDark);
    final text = AuthThemeTokens.text(isDark);
    final textSecondary = AuthThemeTokens.textSecondary(isDark);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Confident, Flat Terracotta Emblem
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: primary,
            borderRadius: BorderRadius.circular(size * 0.28),
            boxShadow: [
              BoxShadow(
                color: primary.withValues(alpha: 0.25),
                blurRadius: 12,
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
        const SizedBox(height: 14),

        // Brand Name
        Text(
          'OmniLife',
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w700,
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
              fontWeight: FontWeight.w400,
              letterSpacing: 0.1,
            ),
          ),
        ],
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../pages/auth/auth_theme_tokens.dart';

/// Refined authentication card with 20px radius, clean hairline border,
/// and subtle entrance animation.
class OmniLifeAuthCard extends StatefulWidget {
  const OmniLifeAuthCard({
    super.key,
    required this.child,
    this.maxWidth = 440,
  });

  final Widget child;
  final double maxWidth;

  @override
  State<OmniLifeAuthCard> createState() => _OmniLifeAuthCardState();
}

class _OmniLifeAuthCardState extends State<OmniLifeAuthCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _cardAnimController;
  late final Animation<double> _fadeAnimation;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _cardAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _cardAnimController,
      curve: Curves.easeOutCubic,
    );

    _scaleAnimation = Tween<double>(begin: 0.98, end: 1.0).animate(
      CurvedAnimation(
        parent: _cardAnimController,
        curve: Curves.easeOutCubic,
      ),
    );

    final binding = WidgetsBinding.instance.runtimeType.toString();
    if (Get.testMode || binding.contains('Test')) {
      _cardAnimController.value = 1.0;
    } else {
      _cardAnimController.forward();
    }
  }

  @override
  void dispose() {
    _cardAnimController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final surfaceColor = AuthThemeTokens.surface(isDark);
    final borderColor = AuthThemeTokens.border(isDark);

    return FadeTransition(
      opacity: _fadeAnimation,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: widget.maxWidth),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              decoration: BoxDecoration(
                color: surfaceColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: borderColor, width: 1),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.05),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 28,
                  ),
                  child: widget.child,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/utils/validators.dart';
import '../../controllers/auth_controller.dart';
import '../../widgets/auth/auth_toggle.dart';
import '../../widgets/auth/forgot_password_sheet.dart';
import '../../widgets/auth/omnilife_auth_background.dart';
import '../../widgets/auth/omnilife_auth_card.dart';
import '../../widgets/auth/omnilife_logo.dart';
import '../../widgets/auth/omnilife_text_field.dart';
import '../../widgets/auth/social_auth_button.dart';
import 'auth_theme_tokens.dart';

/// Redesigned premium animated OmniLife authentication experience.
///
/// Supports smooth animated transition between Sign In and Sign Up modes,
/// native particle dot-grid canvas background, glassmorphic card container,
/// and reactive integration with [AuthController].
class LoginPage extends StatefulWidget {
  const LoginPage({
    super.key,
    this.initialMode = AuthMode.signIn,
  });

  final AuthMode initialMode;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  late AuthMode _currentMode;
  late final AuthController _authController;

  @override
  void initState() {
    super.initState();
    _currentMode = widget.initialMode;
    _authController = Get.find<AuthController>();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _switchMode(AuthMode newMode) {
    if (_currentMode == newMode) return;
    _authController.clearError();
    setState(() {
      _currentMode = newMode;
    });
  }

  Future<void> _submit() async {
    _authController.clearError();
    if (!_formKey.currentState!.validate()) return;

    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (_currentMode == AuthMode.signIn) {
      await _authController.login(email: email, password: password);
    } else {
      await _authController.register(email: email, password: password);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final isSignIn = _currentMode == AuthMode.signIn;
    final primary = AuthThemeTokens.primary(isDark);
    final text = AuthThemeTokens.text(isDark);
    final textSecondary = AuthThemeTokens.textSecondary(isDark);
    final border = AuthThemeTokens.border(isDark);

    return Scaffold(
      body: OmniLifeAuthBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 20),
              child: OmniLifeAuthCard(
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // 1. Logo and branding
                      const Center(child: OmniLifeLogo(size: 46)),
                      const SizedBox(height: 18),

                      // 2. Auth Mode Segmented Pill Toggle
                      AuthToggle(
                        currentMode: _currentMode,
                        onChanged: _switchMode,
                      ),
                      const SizedBox(height: 18),

                      // 3. Animated Heading & Subtitle
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 250),
                        transitionBuilder: (child, animation) {
                          return FadeTransition(
                            opacity: animation,
                            child: SlideTransition(
                              position: Tween<Offset>(
                                begin: const Offset(0, 0.08),
                                end: Offset.zero,
                              ).animate(animation),
                              child: child,
                            ),
                          );
                        },
                        child: Column(
                          key: ValueKey(_currentMode),
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isSignIn ? 'Welcome back' : 'Create an account',
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w800,
                                fontSize: 21,
                                letterSpacing: -0.3,
                                color: text,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              isSignIn
                                  ? 'Sign in to continue'
                                  : 'Start organizing your tasks and life today.',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: textSecondary,
                                fontSize: 13.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // 4. Input Fields (with animated transition for Confirm Password)
                      OmniLifeTextField(
                        controller: _emailController,
                        labelText: 'Email',
                        hintText: 'name@example.com',
                        prefixIcon: Icons.mail_outline_rounded,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        validator: Validators.email,
                      ),
                      const SizedBox(height: 14),

                      OmniLifeTextField(
                        controller: _passwordController,
                        labelText: 'Password',
                        hintText: 'Enter your password',
                        prefixIcon: Icons.lock_outline_rounded,
                        isPassword: true,
                        textInputAction: isSignIn
                            ? TextInputAction.done
                            : TextInputAction.next,
                        validator: Validators.password,
                        onFieldSubmitted: isSignIn ? (_) => _submit() : null,
                      ),

                      // Smooth animated expansion for Confirm Password in Sign Up mode
                      AnimatedSize(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeInOutCubic,
                        child: isSignIn
                            ? const SizedBox.shrink()
                            : Padding(
                                padding: const EdgeInsets.only(top: 14),
                                child: OmniLifeTextField(
                                  controller: _confirmPasswordController,
                                  labelText: 'Confirm password',
                                  hintText: 'Re-enter your password',
                                  prefixIcon: Icons.shield_outlined,
                                  isPassword: true,
                                  textInputAction: TextInputAction.done,
                                  validator: (value) => Validators.confirmPassword(
                                    value,
                                    _passwordController.text,
                                  ),
                                  onFieldSubmitted: (_) => _submit(),
                                ),
                              ),
                      ),

                      // 5. "Forgot password?" link (for Sign In mode)
                      if (isSignIn) ...[
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () {
                              _authController.clearError();
                              ForgotPasswordSheet.show(
                                context,
                                initialEmail: _emailController.text.trim(),
                              );
                            },
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 4,
                              ),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: Text(
                              'Forgot password?',
                              style: TextStyle(
                                color: primary,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 18),

                      // 6. Error banner if any
                      Obx(() {
                        final error = _authController.errorMessage.value;
                        if (error == null) return const SizedBox.shrink();
                        return Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.error.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: theme.colorScheme.error.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.error_outline_rounded,
                                color: theme.colorScheme.error,
                                size: 18,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  error,
                                  style: TextStyle(
                                    color: theme.colorScheme.error,
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),

                      // 7. Primary Action Button ("Sign In" / "Create Account")
                      Obx(() {
                        final loading = _authController.isLoading.value;
                        final actionLabel = isSignIn ? 'Sign In' : 'Sign Up';

                        return SizedBox(
                          height: 48,
                          child: ElevatedButton(
                            onPressed: loading ? null : _submit,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primary,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: loading
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.0,
                                      color: Colors.white,
                                    ),
                                  )
                                : Text(
                                    actionLabel,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14.5,
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                          ),
                        );
                      }),
                      const SizedBox(height: 20),

                      // 8. Divider with "OR"
                      Row(
                        children: [
                          Expanded(
                            child: Divider(
                              color: border.withValues(alpha: 0.6),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            child: Text(
                              'OR',
                              style: TextStyle(
                                color: textSecondary,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Divider(
                              color: border.withValues(alpha: 0.6),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),

                      // 9. Google Sign-In Button
                      Obx(() {
                        final googleLoading =
                            _authController.isGoogleLoading.value;
                        return SocialAuthButton(
                          isLoading: googleLoading,
                          onPressed: _authController.isLoading.value
                              ? null
                              : () {
                                  _authController.clearError();
                                  _authController.signInWithGoogle();
                                },
                        );
                      }),
                      const SizedBox(height: 20),

                      // 10. Secondary mode switch link
                      Center(
                        child: TextButton(
                          onPressed: () {
                            _switchMode(
                              isSignIn ? AuthMode.signUp : AuthMode.signIn,
                            );
                          },
                          child: RichText(
                            text: TextSpan(
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: textSecondary,
                                fontSize: 13.5,
                              ),
                              children: [
                                TextSpan(
                                  text: isSignIn
                                      ? "Don't have an account? "
                                      : 'Already have an account? ',
                                ),
                                TextSpan(
                                  text: isSignIn ? 'Sign Up' : 'Sign In',
                                  style: TextStyle(
                                    color: primary,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

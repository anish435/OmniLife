import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/utils/validators.dart';
import '../../controllers/auth_controller.dart';
import '../../pages/auth/auth_theme_tokens.dart';
import 'omnilife_text_field.dart';

/// Modal bottom sheet for password recovery.
class ForgotPasswordSheet extends StatefulWidget {
  const ForgotPasswordSheet({
    super.key,
    this.initialEmail = '',
  });

  final String initialEmail;

  static Future<void> show(BuildContext context, {String initialEmail = ''}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ForgotPasswordSheet(initialEmail: initialEmail),
    );
  }

  @override
  State<ForgotPasswordSheet> createState() => _ForgotPasswordSheetState();
}

class _ForgotPasswordSheetState extends State<ForgotPasswordSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _emailController;
  late final AuthController _authController;
  bool _submitted = false;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.initialEmail);
    _authController = Get.find<AuthController>();
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _handleSendReset() async {
    _authController.clearError();
    if (!_formKey.currentState!.validate()) return;

    final success = await _authController.sendPasswordResetEmail(
      _emailController.text.trim(),
    );

    if (success && mounted) {
      setState(() {
        _submitted = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final surface = AuthThemeTokens.surface(isDark);
    final primary = AuthThemeTokens.primary(isDark);
    final text = AuthThemeTokens.text(isDark);
    final textSecondary = AuthThemeTokens.textSecondary(isDark);
    final border = AuthThemeTokens.border(isDark);

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Container(
            decoration: BoxDecoration(
              color: surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              border: Border.all(
                color: border.withValues(alpha: 0.6),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.1),
                  blurRadius: 30,
                  offset: const Offset(0, -6),
                ),
              ],
            ),
            padding: const EdgeInsets.fromLTRB(28, 16, 28, 36),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Drag Handle
                  Center(
                    child: Container(
                      width: 44,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 24),
                      decoration: BoxDecoration(
                        color: border,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),

                  if (_submitted) ...[
                    // Success View
                    Center(
                      child: Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: AuthThemeTokens.teal(isDark).withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.mark_email_read_outlined,
                          size: 32,
                          color: AuthThemeTokens.teal(isDark),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'Check your inbox',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: text,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'We have sent a password reset link to ${_emailController.text.trim()}.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: textSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: FilledButton.styleFrom(
                        backgroundColor: primary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text('Back to Sign In'),
                    ),
                  ] else ...[
                    // Input Form View
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.lock_reset_rounded,
                            color: primary,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Reset password',
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: text,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Enter your email to receive recovery instructions.',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    Form(
                      key: _formKey,
                      child: OmniLifeTextField(
                        controller: _emailController,
                        labelText: 'Email',
                        hintText: 'name@example.com',
                        prefixIcon: Icons.mail_outline_rounded,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.done,
                        validator: Validators.email,
                        onFieldSubmitted: (_) => _handleSendReset(),
                      ),
                    ),
                    const SizedBox(height: 16),

                    Obx(() {
                      final error = _authController.errorMessage.value;
                      if (error == null) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          error,
                          style: TextStyle(
                            color: theme.colorScheme.error,
                            fontSize: 13,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      );
                    }),

                    Obx(() {
                      final loading = _authController.isLoading.value;
                      return FilledButton(
                        onPressed: loading ? null : _handleSendReset,
                        style: FilledButton.styleFrom(
                          backgroundColor: primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: loading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                'Send Reset Link',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                ),
                              ),
                      );
                    }),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

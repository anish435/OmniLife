import 'package:flutter/material.dart';

import '../../../app/theme/app_radius.dart';
import '../../pages/auth/auth_theme_tokens.dart';

/// Reusable premium styled text input field for OmniLife authentication.
class OmniLifeTextField extends StatefulWidget {
  const OmniLifeTextField({
    super.key,
    required this.controller,
    required this.labelText,
    this.hintText,
    this.prefixIcon,
    this.validator,
    this.keyboardType,
    this.textInputAction,
    this.isPassword = false,
    this.enabled = true,
    this.onFieldSubmitted,
    this.focusNode,
  });

  final TextEditingController controller;
  final String labelText;
  final String? hintText;
  final IconData? prefixIcon;
  final FormFieldValidator<String>? validator;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final bool isPassword;
  final bool enabled;
  final ValueChanged<String>? onFieldSubmitted;
  final FocusNode? focusNode;

  @override
  State<OmniLifeTextField> createState() => _OmniLifeTextFieldState();
}

class _OmniLifeTextFieldState extends State<OmniLifeTextField> {
  bool _obscureText = true;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final primaryColor = AuthThemeTokens.primary(isDark);
    final borderColor = AuthThemeTokens.border(isDark);
    final inputFill = AuthThemeTokens.inputFill(isDark);
    final textColor = AuthThemeTokens.text(isDark);
    final textSecondary = AuthThemeTokens.textSecondary(isDark);

    return TextFormField(
      controller: widget.controller,
      focusNode: widget.focusNode,
      enabled: widget.enabled,
      obscureText: widget.isPassword ? _obscureText : false,
      keyboardType: widget.keyboardType,
      textInputAction: widget.textInputAction,
      onFieldSubmitted: widget.onFieldSubmitted,
      validator: widget.validator,
      style: theme.textTheme.bodyMedium?.copyWith(
        color: textColor,
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        labelText: widget.labelText,
        hintText: widget.hintText,
        hintStyle: TextStyle(
          color: textSecondary.withValues(alpha: 0.6),
          fontSize: 14,
        ),
        labelStyle: TextStyle(
          color: textSecondary,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        floatingLabelStyle: TextStyle(
          color: primaryColor,
          fontWeight: FontWeight.w600,
        ),
        filled: true,
        fillColor: inputFill,
        prefixIcon: widget.prefixIcon != null
            ? Icon(
                widget.prefixIcon,
                size: 20,
                color: textSecondary,
              )
            : null,
        suffixIcon: widget.isPassword
            ? IconButton(
                icon: Icon(
                  _obscureText
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  size: 20,
                  color: textSecondary,
                ),
                tooltip: _obscureText ? 'Show password' : 'Hide password',
                onPressed: () {
                  setState(() {
                    _obscureText = !_obscureText;
                  });
                },
              )
            : null,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: AppRadius.inputRadius,
          borderSide: BorderSide(color: borderColor, width: 1.0),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.inputRadius,
          borderSide: BorderSide(color: borderColor, width: 1.0),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.inputRadius,
          borderSide: BorderSide(color: primaryColor, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AppRadius.inputRadius,
          borderSide: BorderSide(color: theme.colorScheme.error, width: 1.0),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: AppRadius.inputRadius,
          borderSide: BorderSide(color: theme.colorScheme.error, width: 1.5),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mubtaath/core/theme/theme.dart';

/// [AuthTextField] — Reusable input field for all auth forms.
///
/// Matches the outlined input style from UI PDF (brand spec page 10).
/// Supports: email, password (with toggle), phone, text.
///
/// Usage:
/// ```dart
/// AuthTextField(
///   controller: _emailController,
///   hintText: 'البريد الإلكتروني',
///   keyboardType: TextInputType.emailAddress,
/// )
///
/// AuthTextField(
///   controller: _passwordController,
///   hintText: 'كلمة المرور',
///   isPassword: true,
/// )
/// ```
class AuthTextField extends StatefulWidget {
  const AuthTextField({
    super.key,
    required this.controller,
    required this.hintText,
    this.keyboardType = TextInputType.text,
    this.isPassword = false,
    this.textInputAction = TextInputAction.next,
    this.onSubmitted,
    this.validator,
    this.prefixIcon,
    this.inputFormatters,
    this.maxLength,
    this.enabled = true,
    this.autofillHints,
    this.focusNode,
  });

  final TextEditingController controller;
  final String hintText;
  final TextInputType keyboardType;

  /// When true, shows a password visibility toggle icon on the left
  final bool isPassword;

  final TextInputAction textInputAction;
  final ValueChanged<String>? onSubmitted;
  final FormFieldValidator<String>? validator;

  /// Custom prefix icon — overrides default password eye icon
  final Widget? prefixIcon;

  final List<TextInputFormatter>? inputFormatters;
  final int? maxLength;
  final bool enabled;
  final Iterable<String>? autofillHints;
  final FocusNode? focusNode;

  @override
  State<AuthTextField> createState() => _AuthTextFieldState();
}

class _AuthTextFieldState extends State<AuthTextField> {
  // Tracks password visibility toggle state
  bool _obscureText = true;

  @override
  Widget build(BuildContext context) {
    final bool showEye = widget.isPassword;

    return TextFormField(
      controller: widget.controller,
      focusNode: widget.focusNode,
      keyboardType: widget.keyboardType,
      obscureText: widget.isPassword && _obscureText,
      // Password fields: no keyboard caching / suggestions for credentials.
      enableSuggestions: !widget.isPassword,
      autocorrect: !widget.isPassword,
      textInputAction: widget.textInputAction,
      onFieldSubmitted: widget.onSubmitted,
      validator: widget.validator,
      inputFormatters: widget.inputFormatters,
      maxLength: widget.maxLength,
      enabled: widget.enabled,
      autofillHints: widget.autofillHints,
      textAlign: TextAlign.start,

      style: AppTextStyles.inputText,
      cursorColor: AppColors.primary,

      decoration: InputDecoration(
        hintText: widget.hintText,
        hintStyle: AppTextStyles.inputHint,
        counterText: '', // hides maxLength counter

        // ── Container styling ─────────────────────────
        filled: true,
        fillColor: AppColors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.base,
          vertical: AppDimensions.base,
        ),

        // ── Password eye toggle (left side — RTL) ─────
        prefixIcon: showEye
            ? _PasswordToggle(
                isVisible: !_obscureText,
                onTap: () =>
                    setState(() => _obscureText = !_obscureText),
              )
            : widget.prefixIcon,

        // ── Borders ───────────────────────────────────
        border: _buildBorder(AppColors.divider),
        enabledBorder: _buildBorder(AppColors.divider),
        focusedBorder: _buildBorder(AppColors.primary, width: 1.5),
        errorBorder: _buildBorder(AppColors.error),
        focusedErrorBorder:
            _buildBorder(AppColors.error, width: 1.5),
        disabledBorder: _buildBorder(AppColors.disabled),

        errorStyle: AppTextStyles.caption.copyWith(
          color: AppColors.error,
        ),
      ),
    );
  }

  OutlineInputBorder _buildBorder(Color color, {double width = 1.0}) {
    return OutlineInputBorder(
      borderRadius:
          BorderRadius.circular(AppDimensions.radiusSm),
      borderSide: BorderSide(color: color, width: width),
    );
  }
}

/// Eye icon for password visibility toggle
/// Matches the outlined eye-slash icon from UI PDF
class _PasswordToggle extends StatelessWidget {
  const _PasswordToggle({
    required this.isVisible,
    required this.onTap,
  });

  final bool isVisible;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.base,
        ),
        child: Icon(
          isVisible
              ? Icons.visibility_outlined
              : Icons.visibility_off_outlined,
          color: AppColors.secondary,
          size: AppDimensions.iconMd,
        ),
      ),
    );
  }
}

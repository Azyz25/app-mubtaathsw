import 'package:flutter/material.dart';
import 'package:mubtaath/core/theme/theme.dart';

// ─────────────────────────────────────────────────────────────
// MAIN BUTTON (Primary — filled green)
// Used for: "تسجيل الدخول", "إنشاء الحساب", "تحقق"
// ─────────────────────────────────────────────────────────────

/// Full-width primary CTA button.
/// Matches the filled dark-green button from UI PDF (brand spec page 10).
class MainButton extends StatelessWidget {
  const MainButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.isEnabled = true,
    this.width,
    this.height = AppDimensions.buttonHeight,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool isEnabled;
  final double? width;
  final double height;

  /// Optional leading icon (e.g. for special CTAs)
  final Widget? icon;

  @override
  Widget build(BuildContext context) {
    final effectiveCallback = (isEnabled && !isLoading) ? onPressed : null;

    return SizedBox(
      width: width ?? double.infinity,
      height: height,
      child: ElevatedButton(
        onPressed: effectiveCallback,
        style: ElevatedButton.styleFrom(
          backgroundColor:
              isEnabled ? AppColors.primary : AppColors.disabled,
          foregroundColor: AppColors.white,
          shape: RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(AppDimensions.radiusButton),
          ),
          elevation: AppDimensions.elevationNone,
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.xl,
          ),
        ),
        child: isLoading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor:
                      AlwaysStoppedAnimation<Color>(AppColors.white),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    icon!,
                    const SizedBox(width: AppDimensions.sm),
                  ],
                  Text(
                    label,
                    style: AppTextStyles.buttonLarge,
                  ),
                ],
              ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// SECONDARY BUTTON (Outlined — white with green border)
// Used for: "إنشاء حساب" (outline variant)
// ─────────────────────────────────────────────────────────────

/// Full-width outlined secondary button.
/// Matches the outlined button from brand spec page 10.
class SecondaryButton extends StatelessWidget {
  const SecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.height = AppDimensions.buttonHeight,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final double height;
  final Widget? icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: height,
      child: OutlinedButton(
        onPressed: isLoading ? null : onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(
            color: AppColors.primary,
            width: 1.5,
          ),
          shape: RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(AppDimensions.radiusButton),
          ),
          backgroundColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.xl,
          ),
        ),
        child: isLoading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(
                      AppColors.primary),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    icon!,
                    const SizedBox(width: AppDimensions.sm),
                  ],
                  Text(
                    label,
                    style: AppTextStyles.buttonMedium,
                  ),
                ],
              ),
      ),
    );
  }
}

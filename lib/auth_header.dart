import 'package:flutter/material.dart';
import 'package:mubtaath/core/theme/theme.dart';

/// [AuthHeader] — Reusable heading block for all auth screens.
///
/// Usage:
/// ```dart
/// AuthHeader(
///   title: 'مرحباً بعودتك',
///   subtitle: 'سجّل دخولك لاستمرار استعمال التطبيق',
/// )
/// ```
class AuthHeader extends StatelessWidget {
  const AuthHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.topSpacing,
  });

  final String title;
  final String? subtitle;

  /// Override top spacing if needed (default: 10% of screen height)
  final double? topSpacing;

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.sizeOf(context).height;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(height: topSpacing ?? screenHeight * 0.10),

        // ── Main title ────────────────────────────────
        Text(
          title,
          style: AppTextStyles.headlineLarge.copyWith(
            fontSize: _responsiveFontSize(context, 30),
            fontWeight: FontWeight.w700,
            color: AppColors.primary,
          ),
          textAlign: TextAlign.center,
        ),

        if (subtitle != null) ...[
          const SizedBox(height: AppDimensions.sm),

          // ── Subtitle ───────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.xxl,
            ),
            child: Text(
              subtitle!,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.secondary,
                height: 1.6,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ],
    );
  }

  /// Scales font size based on screen width for tablet support
  double _responsiveFontSize(BuildContext context, double base) {
    final width = MediaQuery.sizeOf(context).width;
    if (width >= 600) return base * 1.2; // tablet
    return base;
  }
}

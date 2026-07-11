import 'package:flutter/material.dart';
import 'package:mubtaath/core/l10n/app_localizations.dart';
import 'package:mubtaath/core/theme/theme.dart';

// ─────────────────────────────────────────────────────────────
// GOOGLE SIGN-IN BUTTON
// ─────────────────────────────────────────────────────────────

/// Outlined Google sign-in button matching the UI PDF.
/// Shows the Google "G" logo on the left (RTL layout),
/// text centered: "تسجيل الدخول عبر قوقل"
class GoogleSignInButton extends StatelessWidget {
  const GoogleSignInButton({
    super.key,
    required this.onPressed,
    this.isLoading = false,
  });

  final VoidCallback? onPressed;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: AppDimensions.buttonHeight,
      child: OutlinedButton(
        onPressed: isLoading ? null : onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.deepDark,
          backgroundColor: AppColors.white,
          side: const BorderSide(color: AppColors.divider, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(AppDimensions.radiusButton),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.base,
          ),
        ),
        child: isLoading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              )
            : Stack(
                alignment: Alignment.center,
                children: [
                  // ── Google "G" logo (left side) ──────
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: _GoogleLogo(size: 26),
                  ),

                  // ── Button text (centered) ────────────
                  Text(
                    AppLocalizations.of(context)!.signInWithGoogle,
                    style: AppTextStyles.buttonMedium.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.deepDark,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

/// Painted Google "G" logo using the official brand colors
class _GoogleLogo extends StatelessWidget {
  const _GoogleLogo({required this.size});
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _GoogleLogoPainter()),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Background circle
    canvas.drawCircle(
      center,
      radius,
      Paint()..color = Colors.white,
    );

    // Google G segments (simplified but recognizable)
    const segments = [
      // [startAngle, sweepAngle, color]
      [-0.1, 1.65, Color(0xFF4285F4)], // Blue
      [1.55, 1.65, Color(0xFF34A853)], // Green
      [3.2, 1.65, Color(0xFFFBBC05)],  // Yellow
      [4.85, 1.65, Color(0xFFEA4335)], // Red
    ];

    for (final seg in segments) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius * 0.85),
        seg[0] as double,
        seg[1] as double,
        true,
        Paint()..color = seg[2] as Color,
      );
    }

    // White center (creates the arc shape)
    canvas.drawCircle(
      center,
      radius * 0.55,
      Paint()..color = Colors.white,
    );

    // Right horizontal bar of "G"
    canvas.drawRect(
      Rect.fromLTWH(
        center.dx - radius * 0.02,
        center.dy - radius * 0.18,
        radius * 0.9,
        radius * 0.36,
      ),
      Paint()..color = const Color(0xFF4285F4),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─────────────────────────────────────────────────────────────
// OR DIVIDER  ( ──────── أو ──────── )
// ─────────────────────────────────────────────────────────────

/// Horizontal divider with centered Arabic "أو" label.
/// Matches the separator between login button and Google button in PDF.
class OrDivider extends StatelessWidget {
  const OrDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Left line
        Expanded(
          child: Container(
            height: 1,
            color: AppColors.divider,
          ),
        ),

        // "أو" label
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.base,
          ),
          child: Text(
            AppLocalizations.of(context)!.or,
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.secondary,
              height: 1,
            ),
          ),
        ),

        // Right line
        Expanded(
          child: Container(
            height: 1,
            color: AppColors.divider,
          ),
        ),
      ],
    );
  }
}

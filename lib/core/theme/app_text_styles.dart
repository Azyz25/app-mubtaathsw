import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// Mubtaath Typography System
/// Primary font:   Cairo   — Headlines, buttons, bold labels
/// Secondary font: Tajawal — Body text, captions, regular labels
///
/// All text is RTL-aware by default (Arabic app).
abstract final class AppTextStyles {
  // ─────────────────────────────────────────────
  // CAIRO — Primary Font (Headlines & Bold)
  // ─────────────────────────────────────────────

  /// App name / splash screen display text
  static TextStyle displayLarge = GoogleFonts.cairo(
    fontSize: 32,
    fontWeight: FontWeight.w700,
    color: AppColors.deepDark,
    height: 1.3,
  );

  /// Section hero titles
  static TextStyle displayMedium = GoogleFonts.cairo(
    fontSize: 28,
    fontWeight: FontWeight.w700,
    color: AppColors.deepDark,
    height: 1.3,
  );

  /// Room title, page titles
  static TextStyle headlineLarge = GoogleFonts.cairo(
    fontSize: 24,
    fontWeight: FontWeight.w700,
    color: AppColors.deepDark,
    height: 1.4,
  );

  /// Card section titles
  static TextStyle headlineMedium = GoogleFonts.cairo(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: AppColors.deepDark,
    height: 1.4,
  );

  /// AppBar title, dialog title
  static TextStyle headlineSmall = GoogleFonts.cairo(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: AppColors.deepDark,
    height: 1.4,
  );

  /// Primary button text
  static TextStyle buttonLarge = GoogleFonts.cairo(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: AppColors.white,
    height: 1.0,
    letterSpacing: 0.3,
  );

  /// Secondary button text
  static TextStyle buttonMedium = GoogleFonts.cairo(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: AppColors.primary,
    height: 1.0,
    letterSpacing: 0.3,
  );

  // ─────────────────────────────────────────────
  // TAJAWAL — Secondary Font (Body & Captions)
  // ─────────────────────────────────────────────

  /// Default body text — room descriptions, chat messages
  static TextStyle bodyLarge = GoogleFonts.tajawal(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    color: AppColors.deepDark,
    height: 1.6,
  );

  /// Secondary body — list items, descriptions
  static TextStyle bodyMedium = GoogleFonts.tajawal(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.deepDark,
    height: 1.6,
  );

  /// Small body — timestamps, helper text
  static TextStyle bodySmall = GoogleFonts.tajawal(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: AppColors.secondary,
    height: 1.5,
  );

  /// Input field text
  static TextStyle inputText = GoogleFonts.tajawal(
    fontSize: 15,
    fontWeight: FontWeight.w400,
    color: AppColors.deepDark,
    height: 1.4,
  );

  /// Input hint text
  static TextStyle inputHint = GoogleFonts.tajawal(
    fontSize: 15,
    fontWeight: FontWeight.w400,
    color: AppColors.disabled,
    height: 1.4,
  );

  /// Label for bottom nav + form labels
  static TextStyle labelMedium = GoogleFonts.tajawal(
    fontSize: 11,
    fontWeight: FontWeight.w500,
    color: AppColors.secondary,
    height: 1.2,
  );

  /// Caption — listener count, timestamps in rooms
  static TextStyle caption = GoogleFonts.tajawal(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: AppColors.secondary,
    height: 1.2,
  );

  // ─────────────────────────────────────────────
  // SEMANTIC VARIANTS (color overrides)
  // ─────────────────────────────────────────────

  static TextStyle bodyLargeOnDark = bodyLarge.copyWith(color: AppColors.white);
  static TextStyle bodyMediumOnDark = bodyMedium.copyWith(color: AppColors.white);
  static TextStyle captionOnDark = caption.copyWith(color: AppColors.accent);
  static TextStyle headlineLargeOnDark = headlineLarge.copyWith(color: AppColors.white);
  static TextStyle headlineSmallPrimary = headlineSmall.copyWith(color: AppColors.primary);
}

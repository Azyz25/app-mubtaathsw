import 'package:flutter/material.dart';

/// Mubtaath Brand Color System
/// Source: BrandGuideLines.pdf — Pages 06 & 07
/// All colors are final constants — never use raw hex elsewhere in the app.
abstract final class AppColors {
  // ─────────────────────────────────────────────
  // PRIMARY PALETTE
  // ─────────────────────────────────────────────

  static const Color primary      = Color(0xFF305544); // main brand green
  static const Color primaryDark  = Color(0xFF1E3A2D); // darkened primary (iOS nav)
  static const Color primaryLight = Color(0xFF3D6B56); // lightened primary

  static const Color secondary    = Color(0xFFB19369); // gold / tan accent
  static const Color accent       = Color(0xFFCEB189); // sand accent (= accentLight)
  static const Color accentLight  = Color(0xFFCEB189); // alias kept for migration

  // ─────────────────────────────────────────────
  // SURFACE & BACKGROUND
  // ─────────────────────────────────────────────

  /// Main scaffold background — all feature pages
  static const Color background   = Color(0xFFF9F7F5);

  /// Auth/notification scaffold — slightly cooler off-white
  static const Color scaffoldAlt  = Color(0xFFF8F9FA);

  /// Card / input surface — pure white
  static const Color surface      = Color(0xFFFFFFFF);

  /// Alias kept for readability alongside surface
  static const Color white        = Color(0xFFFFFFFF);

  static const Color black        = Color(0xFF000000);

  /// Avatar / icon placeholder — warm beige (former brand background)
  static const Color avatarBg     = Color(0xFFEFE8E0);

  // ─────────────────────────────────────────────
  // TEXT
  // ─────────────────────────────────────────────

  /// Deep dark green — primary text on light surfaces
  static const Color deepDark      = Color(0xFF051C16);

  /// Alias used in layout pages
  static const Color darkText      = Color(0xFF051C16);

  /// Alias used in auth pages
  static const Color textPrimary   = Color(0xFF051C16);

  /// Grey secondary / supporting text
  static const Color textSecondary = Color(0xFF9E9E9E);

  /// Placeholder / hint text
  static const Color textHint      = Color(0xFFBBBBBB);

  /// Body text — medium grey
  static const Color body          = Color(0xFF707070);

  /// Light body / nav inactive
  static const Color bodyLight     = Color(0xFFAAAAAA);

  // ─────────────────────────────────────────────
  // BORDERS & DIVIDERS
  // ─────────────────────────────────────────────

  static const Color cardBorder    = Color(0xFFE2E2E2); // card border
  static const Color fieldBorder   = Color(0xFFCECECE); // text field enabled border
  static const Color divider       = Color(0xFFD9D0C7); // list dividers

  // ─────────────────────────────────────────────
  // NAVIGATION
  // ─────────────────────────────────────────────

  static const Color navInactive   = Color(0xFFAAAAAA); // nav bar inactive tab

  // ─────────────────────────────────────────────
  // INTERACTIVE / DISABLED
  // ─────────────────────────────────────────────

  static const Color disabled      = Color(0xFFBDB5AC); // brand-palette disabled
  static const Color disabledBtn   = Color(0xFF9E9E9E); // button disabled state

  // ─────────────────────────────────────────────
  // SEMANTIC COLORS
  // ─────────────────────────────────────────────

  static const Color success       = Color(0xFF2E7D52);
  static const Color whatsapp      = Color(0xFF25D366); // WhatsApp brand green
  static const Color error         = Color(0xFFB00020); // snackbar / brand error
  static const Color inputError    = Color(0xFFD32F2F); // form field validation error
  static const Color logoutRed     = Color(0xFFD32F2F); // destructive action
  static const Color warning       = Color(0xFFF5A623);
  static const Color info          = Color(0xFF1565C0);

  // ─────────────────────────────────────────────
  // OVERLAY / SCRIM
  // ─────────────────────────────────────────────

  static const Color scrim         = Color(0x1F305544); // primary @ 12%
  static const Color roomOverlay   = Color(0xCC051C16); // deepDark @ 80%

  // ─────────────────────────────────────────────
  // LIVE ROOM CHAT — soft-tinted palette (matches the support/report chat's
  // bordered-badge look: light tinted fill + visible border, not solid).
  // ─────────────────────────────────────────────

  /// Current user's bubble — soft brand-green tint (primary @ 8%)
  static const Color chatBubbleSelf  = Color(0x14305544);

  /// Current user's bubble border — brand green @ 28%, always visible
  static const Color chatBorderSelf  = Color(0x47305544);

  /// Current user's bubble text — dark, readable on the light tint
  static const Color chatTextSelf    = Color(0xFF1A1A1A);

  /// Other users' bubble — clean light surface
  static const Color chatBubbleOther = Color(0xFFF2F3F2);

  /// Other users' bubble border — neutral hairline, always visible
  static const Color chatBorderOther = cardBorder;

  /// Other users' bubble text — near-black, high contrast on light
  static const Color chatTextOther   = Color(0xFF1A1A1A);

  /// Timestamp on own bubble — muted brand green, readable on the light tint
  static const Color chatTimeSelf    = Color(0xFF5C7268);

  /// Timestamp on other (light) bubble — muted grey
  static const Color chatTimeOther   = Color(0xFF8A8A8A);

  /// Deleted-message bubble — light neutral (chat sheet is white)
  static const Color chatBubbleDeleted = Color(0x0F000000); // black @ 6%

  /// Deleted-message text — soft grey italic
  static const Color chatTextDeleted = Color(0xFF9AA0A6);

  /// Sender username label above bubbles — mid grey, readable on the white sheet
  static const Color chatSenderName  = Color(0xFF8A8A8A);

  // ── Chat input bar ──
  /// Input field surface — clean white pill (fixes white-on-white text bug)
  static const Color chatInputBg     = Color(0xFFFFFFFF);

  /// Input field text — dark, clearly legible
  static const Color chatInputText   = Color(0xFF1A1A1A);

  /// Input field hint / placeholder — muted grey
  static const Color chatInputHint   = Color(0xFF9E9E9E);

  /// Input field border — subtle light grey hairline
  static const Color chatInputBorder = Color(0xFFE2E2E2);

  /// Live-pulse indicator dot — alert red
  static const Color livePulse       = Color(0xFFFF3B30);

  // ─────────────────────────────────────────────
  // NOTIFICATION CARDS
  // ─────────────────────────────────────────────

  /// Notification card box-shadow: black @ 3%
  static const Color notifCardShadow = Color(0x08000000);

  /// Notification card border: black @ 5%
  static const Color notifCardBorder = Color(0x0D000000);

  // ─────────────────────────────────────────────
  // SPLASH SCREEN
  // ─────────────────────────────────────────────

  static const Color splashWavePrimary  = Color(0xFF305544);
  static const Color splashWaveAccent   = Color(0xFFCEB189);
  static const Color splashSkylineTint  = Color(0xFFCEB189);
}

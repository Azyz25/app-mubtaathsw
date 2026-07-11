/// Mubtaath Design Tokens — Spacing, Radius, Elevation, Sizing
/// Use these constants throughout the app. Never use raw numbers for layout.
abstract final class AppDimensions {
  // ─────────────────────────────────────────────
  // SPACING SCALE (8px base grid)
  // ─────────────────────────────────────────────
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double base = 16.0;
  static const double lg = 20.0;
  static const double xl = 24.0;
  static const double xxl = 32.0;
  static const double xxxl = 48.0;
  static const double huge = 64.0;

  // ─────────────────────────────────────────────
  // BORDER RADIUS
  // ─────────────────────────────────────────────

  /// Used for chips, tags, small badges
  static const double radiusXs = 4.0;

  /// Used for text fields, small cards
  static const double radiusSm = 8.0;

  /// Default card radius — matches brand rounded style
  static const double radiusMd = 12.0;

  /// Large cards, bottom sheets, modals
  static const double radiusLg = 16.0;

  /// Buttons (full-width primary/secondary)
  static const double radiusButton = 12.0;

  /// Pill shape — search bar, live badge
  static const double radiusPill = 100.0;

  // ─────────────────────────────────────────────
  // ICON SIZES
  // ─────────────────────────────────────────────
  static const double iconXs = 16.0;
  static const double iconSm = 20.0;
  static const double iconMd = 24.0;
  static const double iconLg = 32.0;
  static const double iconXl = 48.0;

  // ─────────────────────────────────────────────
  // COMPONENT HEIGHTS
  // ─────────────────────────────────────────────
  static const double buttonHeight = 52.0;
  static const double inputHeight = 52.0;
  static const double bottomNavHeight = 64.0;
  static const double appBarHeight = 56.0;
  static const double roomCardHeight = 88.0;
  static const double speakerAvatarSize = 72.0;

  // ─────────────────────────────────────────────
  // ELEVATION
  // ─────────────────────────────────────────────
  static const double elevationNone = 0.0;
  static const double elevationLow = 2.0;
  static const double elevationMid = 4.0;
  static const double elevationHigh = 8.0;

  // ─────────────────────────────────────────────
  // PAGE PADDING
  // ─────────────────────────────────────────────
  static const double pageHorizontalPadding = 20.0;
  static const double pageVerticalPadding = 24.0;
}

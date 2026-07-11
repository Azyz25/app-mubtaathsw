// ─────────────────────────────────────────────────────────────────────────────
// Agora Configuration
// ─────────────────────────────────────────────────────────────────────────────
// App ID is read from a compile-time env var — NEVER hardcode it here.
//
//   flutter run --dart-define=AGORA_APP_ID=<your-32-char-app-id>
//
// For production: your backend must generate short-lived tokens (RTC Token
// Builder v2) and return them via an authenticated API call.  The app should
// request a fresh token from YOUR server before calling joinChannel() and
// never embed a permanent certificate token in the binary.
// ─────────────────────────────────────────────────────────────────────────────

/// Agora App ID injected at build time via --dart-define.
/// Falls back to the dev App ID so the app works without the flag during local development.
/// In CI / production always supply the flag to avoid baking the key into the binary.
const agoraAppId = String.fromEnvironment(
  'AGORA_APP_ID',
  defaultValue: '434451efb1204e16a9787d3b05c44fb5',
);

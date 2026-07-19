// lib/core/services/safe_url_launcher.dart
//
// Single choke-point for opening external links. Everything that reaches here
// is SERVER-authored (dashboard legal-page links, directory items), so the URL
// scheme is never trusted blindly: only https / mailto / tel are launched.
// A bare string with no scheme is treated as https; cleartext http is upgraded
// to https; anything else (javascript:, file:, intent:, sms:, market:, data:,
// content: …) is rejected. This stops a hostile/misconfigured link from
// invoking an arbitrary OS handler.

import 'package:url_launcher/url_launcher.dart';

const _allowedSchemes = {'https', 'mailto', 'tel'};

/// Launches a pre-built [uri] if its scheme is allowlisted. http is upgraded
/// to https. Returns true only if a handler actually opened it.
Future<bool> launchExternalUri(Uri uri) async {
  var u = uri;
  if (u.scheme == 'http') {
    u = u.replace(scheme: 'https');
  }
  if (!_allowedSchemes.contains(u.scheme)) return false;
  try {
    return await launchUrl(u, mode: LaunchMode.externalApplication);
  } catch (_) {
    // No handler app installed / launch failed — silently ignore.
    return false;
  }
}

/// Returns [url] only if it is safe to load as a remote image — an https URL
/// or a bundled `assets/` path; otherwise null so the caller can show a
/// placeholder. The OS transport layer already refuses cleartext http on both
/// platforms (Android network_security_config + iOS ATS); this is
/// defense-in-depth plus a graceful fallback instead of a broken-image error.
String? sanitizeImageUrl(String? url) {
  if (url == null) return null;
  final u = url.trim();
  if (u.isEmpty) return null;
  if (u.startsWith('assets/')) return u;
  final parsed = Uri.tryParse(u);
  if (parsed == null) return null;
  return parsed.scheme == 'https' ? u : null;
}

/// Normalizes a raw string (adds https:// when no scheme is present) and
/// launches it through [launchExternalUri]'s scheme allowlist.
Future<bool> launchExternalUrl(String raw) async {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return false;

  var uri = Uri.tryParse(trimmed);
  if (uri == null) return false;

  if (!uri.hasScheme) {
    final withScheme = Uri.tryParse('https://$trimmed');
    if (withScheme == null) return false;
    uri = withScheme;
  }

  return launchExternalUri(uri);
}

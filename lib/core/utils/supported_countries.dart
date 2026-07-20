// lib/core/utils/supported_countries.dart
//
// Canonical bilingual names + flags for the countries Mubtaath supports, keyed
// by ISO-3166 alpha-2 code. Country labels are resolved through here so they
// ALWAYS render in the app's current language regardless of what a given
// payload happened to store — previously a label showed whichever single
// language was saved (usually Arabic), so English users saw Arabic names.

const Map<String, ({String ar, String en, String flag})> kSupportedCountries = {
  'GB': (ar: 'بريطانيا', en: 'United Kingdom', flag: '🇬🇧'),
  'AU': (ar: 'أستراليا', en: 'Australia', flag: '🇦🇺'),
  'US': (ar: 'أمريكا', en: 'United States', flag: '🇺🇸'),
  'CA': (ar: 'كندا', en: 'Canada', flag: '🇨🇦'),
};

/// Localized display name for a country [code] in [lang] ('ar' | 'en').
///
/// For a supported code the canonical name always wins. For any other code it
/// falls back to the supplied [ar]/[en] labels (e.g. API- or DB-provided), and
/// to the other language when the requested one is missing — so it never
/// renders empty.
String countryDisplayName(
  String code,
  String lang, {
  String ar = '',
  String en = '',
}) {
  final known = kSupportedCountries[code.toUpperCase()];
  if (known != null) {
    ar = known.ar;
    en = known.en;
  }
  if (lang == 'ar') return ar.isNotEmpty ? ar : en;
  return en.isNotEmpty ? en : ar;
}

import 'dart:async';

import 'package:dio/dio.dart';
import 'package:geocoding/geocoding.dart' as geo;

final _dio = Dio(BaseOptions(
  connectTimeout: const Duration(seconds: 8),
  receiveTimeout: const Duration(seconds: 8),
  headers: {'User-Agent': 'MubtaathApp/1.0 (Saudi Students Abroad)'},
));

String _pick(Map<String, dynamic> address, List<String> keys) {
  for (final key in keys) {
    final val = (address[key] as String?)?.trim();
    if (val != null && val.isNotEmpty) return val;
  }
  return '';
}

Future<String> _fetch(double lat, double lon, String lang) async {
  try {
    final resp = await _dio.get<dynamic>(
      'https://nominatim.openstreetmap.org/reverse',
      queryParameters: {
        'format': 'json',
        'lat': lat,
        'lon': lon,
        'accept-language': lang,
        'zoom': 10,
      },
    );
    final raw = resp.data;
    if (raw is! Map<String, dynamic>) return '';
    final address = raw['address'];
    if (address is! Map<String, dynamic>) return '';

    final place = _pick(address, [
      'city', 'town', 'village', 'county', 'municipality', 'state',
    ]);
    final country = (address['country'] as String?)?.trim() ?? '';

    if (place.isEmpty && country.isEmpty) return '';
    if (place.isEmpty) return country;
    if (country.isEmpty) return place;
    return lang == 'ar' ? '$place، $country' : '$place, $country';
  } catch (_) {
    return '';
  }
}

/// Queries Nominatim for both Arabic and English city+country labels in
/// parallel. Either field may be empty if the request fails or times out.
Future<({String ar, String en})> nominatimReverse(
  double lat,
  double lon,
) async {
  final results = await Future.wait([
    _fetch(lat, lon, 'ar'),
    _fetch(lat, lon, 'en'),
  ]);
  return (ar: results[0], en: results[1]);
}

String _placemarkCity(geo.Placemark p) {
  if (p.locality?.isNotEmpty == true) return p.locality!;
  if (p.subAdministrativeArea?.isNotEmpty == true) return p.subAdministrativeArea!;
  if (p.administrativeArea?.isNotEmpty == true) return p.administrativeArea!;
  return '';
}

// geocoding's locale is GLOBAL plugin state set via setLocaleIdentifier(),
// not a per-call parameter — so two resolvePlace() calls racing (e.g. Prayer
// Times and Qibla both cold-starting near-simultaneously) could interleave
// and tag one call's results with the other's language. This chain-based
// lock serializes every resolvePlace() call so that never happens.
Future<void> _geocodeLock = Future.value();

Future<T> _withGeocodeLock<T>(Future<T> Function() action) async {
  final previous = _geocodeLock;
  final completer = Completer<void>();
  _geocodeLock = completer.future;
  await previous;
  try {
    return await action();
  } finally {
    completer.complete();
  }
}

/// Resolves a coordinate into bilingual city labels (Arabic + English) plus the
/// ISO country code. Queries the on-device geocoder ONCE PER LANGUAGE via
/// setLocaleIdentifier(), so the label follows the APP's language — not the
/// device's or the location's own language. (The previous single-call approach
/// returned only one language and copied it into both fields, which is why the
/// city was "always Arabic or always English" depending on the country.) Falls
/// back to Nominatim for any language the device geocoder can't supply (web,
/// simulators, or a device that ignores the locale hint).
Future<({String ar, String en, String iso})> resolvePlace(
  double lat,
  double lon,
) {
  return _withGeocodeLock(() async {
    String ar = '';
    String en = '';
    String iso = '';

    Future<String> device(String locale) async {
      try {
        await geo.setLocaleIdentifier(locale);
        final places = await geo.placemarkFromCoordinates(lat, lon);
        if (places.isEmpty) return '';
        final p = places.first;
        if (iso.isEmpty && (p.isoCountryCode?.isNotEmpty ?? false)) {
          iso = p.isoCountryCode!;
        }
        return _placemarkCity(p);
      } catch (_) {
        return '';
      }
    }

    en = await device('en');
    ar = await device('ar');

    // Fill gaps — or repair the case where the device ignored the locale hint
    // and returned the SAME string for both languages — from Nominatim's
    // explicit per-language query.
    if (ar.isEmpty || en.isEmpty || ar == en) {
      final n = await nominatimReverse(lat, lon);
      if (en.isEmpty && n.en.isNotEmpty) en = n.en;
      if (ar.isEmpty && n.ar.isNotEmpty) ar = n.ar;
      if (ar == en && n.ar.isNotEmpty && n.en.isNotEmpty && n.ar != n.en) {
        ar = n.ar;
        en = n.en;
      }
    }

    return (ar: ar, en: en, iso: iso);
  });
}

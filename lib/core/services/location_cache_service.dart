// lib/core/services/location_cache_service.dart
//
// Persists the last known device location + resolved city label so the
// Prayer Times and Qibla pages can render INSTANTLY on open instead of
// blocking on a fresh GPS fix + reverse-geocode every single visit.
// Shared between both pages/cubits — whichever fetches first warms the
// cache for the other.

import 'package:shared_preferences/shared_preferences.dart';

class CachedLocation {
  final double lat;
  final double lng;
  final String isoCode;
  final String cityAr;
  final String cityEn;

  const CachedLocation({
    required this.lat,
    required this.lng,
    required this.isoCode,
    required this.cityAr,
    required this.cityEn,
  });
}

class LocationCacheService {
  LocationCacheService._();
  static final LocationCacheService instance = LocationCacheService._();

  static const _kLat     = 'loc_cache_lat';
  static const _kLng     = 'loc_cache_lng';
  static const _kIso     = 'loc_cache_iso';
  static const _kCityAr  = 'loc_cache_city_ar';
  static const _kCityEn  = 'loc_cache_city_en';

  /// A location fix this far (or more) from the cached one is treated as a
  /// real move (new city/country) worth re-geocoding — not just GPS jitter.
  static const double significantMoveMeters = 5000;

  Future<CachedLocation?> read() async {
    final prefs = await SharedPreferences.getInstance();
    final lat = prefs.getDouble(_kLat);
    final lng = prefs.getDouble(_kLng);
    if (lat == null || lng == null) return null;
    return CachedLocation(
      lat:     lat,
      lng:     lng,
      isoCode: prefs.getString(_kIso)    ?? 'GB',
      cityAr:  prefs.getString(_kCityAr) ?? '',
      cityEn:  prefs.getString(_kCityEn) ?? '',
    );
  }

  Future<void> write(CachedLocation loc) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_kLat, loc.lat);
    await prefs.setDouble(_kLng, loc.lng);
    await prefs.setString(_kIso, loc.isoCode);
    await prefs.setString(_kCityAr, loc.cityAr);
    await prefs.setString(_kCityEn, loc.cityEn);
  }
}

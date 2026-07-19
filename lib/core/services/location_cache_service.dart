// lib/core/services/location_cache_service.dart
//
// Persists the last known device location + resolved city label so the
// Prayer Times and Qibla pages can render INSTANTLY on open instead of
// blocking on a fresh GPS fix + reverse-geocode every single visit.
// Shared between both pages/cubits — whichever fetches first warms the
// cache for the other.
//
// SECURITY: the precise GPS coordinates + city are user PII, so they are
// stored ENCRYPTED AT REST via SecureStorageService (Android Keystore /
// iOS Keychain), NOT in plaintext SharedPreferences. Older builds wrote
// these to SharedPreferences; read() transparently migrates and purges
// that plaintext on first run after upgrade.

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:mubtaath/core/services/secure_storage_service.dart';

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

  Map<String, dynamic> toJson() => {
        'lat': lat,
        'lng': lng,
        'iso': isoCode,
        'cityAr': cityAr,
        'cityEn': cityEn,
      };

  static CachedLocation? fromJson(Map<String, dynamic> j) {
    final lat = (j['lat'] as num?)?.toDouble();
    final lng = (j['lng'] as num?)?.toDouble();
    if (lat == null || lng == null) return null;
    return CachedLocation(
      lat: lat,
      lng: lng,
      isoCode: j['iso'] as String? ?? 'GB',
      cityAr: j['cityAr'] as String? ?? '',
      cityEn: j['cityEn'] as String? ?? '',
    );
  }
}

class LocationCacheService {
  LocationCacheService._();
  static final LocationCacheService instance = LocationCacheService._();

  // Legacy plaintext SharedPreferences keys — only referenced now to migrate
  // OFF of them and delete them. Nothing writes these anymore.
  static const _kLegacyLat    = 'loc_cache_lat';
  static const _kLegacyLng    = 'loc_cache_lng';
  static const _kLegacyIso    = 'loc_cache_iso';
  static const _kLegacyCityAr = 'loc_cache_city_ar';
  static const _kLegacyCityEn = 'loc_cache_city_en';

  /// A location fix this far (or more) from the cached one is treated as a
  /// real move (new city/country) worth re-geocoding — not just GPS jitter.
  static const double significantMoveMeters = 5000;

  // Same-process, synchronous copy of the last read/written value. Prayer
  // Times and Qibla are separate pushed routes, each building a fresh Cubit
  // on every visit — even a fast storage read is still awaited (at least one
  // microtask tick), which is enough for the first frame to render a loading
  // state before it resolves. Whichever page warms this first lets the other
  // start straight from `loaded`, no flash, no matter how many times the user
  // re-opens the page within the same app session.
  static CachedLocation? _memory;

  /// Synchronous — use only to skip a redundant loading flash when a fresh
  /// value is already known to be in memory. Never a substitute for read().
  CachedLocation? get memorySync => _memory;

  Future<CachedLocation?> read() async {
    // Preferred path: encrypted store.
    final raw = await SecureStorageService.readLocationCache();
    if (raw != null && raw.isNotEmpty) {
      try {
        final loc = CachedLocation.fromJson(
          jsonDecode(raw) as Map<String, dynamic>,
        );
        if (loc != null) {
          _memory = loc;
          return loc;
        }
      } catch (_) {
        // Corrupt entry — fall through and try a legacy migration/clear.
      }
    }

    // One-time migration from the old plaintext SharedPreferences location.
    return _migrateFromPlaintext();
  }

  Future<void> write(CachedLocation loc) async {
    _memory = loc;
    await SecureStorageService.saveLocationCache(jsonEncode(loc.toJson()));
    // Defensive: make sure no stale plaintext copy lingers.
    await _purgeLegacyPlaintext();
  }

  /// Reads any legacy plaintext location, re-saves it encrypted, deletes the
  /// plaintext, and returns it. Returns null when there's nothing to migrate.
  Future<CachedLocation?> _migrateFromPlaintext() async {
    final prefs = await SharedPreferences.getInstance();
    final lat = prefs.getDouble(_kLegacyLat);
    final lng = prefs.getDouble(_kLegacyLng);
    if (lat == null || lng == null) {
      // Nothing to migrate — but still clear any partial leftovers.
      await _purgeLegacyPlaintext();
      return null;
    }

    final loc = CachedLocation(
      lat: lat,
      lng: lng,
      isoCode: prefs.getString(_kLegacyIso)    ?? 'GB',
      cityAr:  prefs.getString(_kLegacyCityAr) ?? '',
      cityEn:  prefs.getString(_kLegacyCityEn) ?? '',
    );

    _memory = loc;
    await SecureStorageService.saveLocationCache(jsonEncode(loc.toJson()));
    await _purgeLegacyPlaintext();
    return loc;
  }

  Future<void> _purgeLegacyPlaintext() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kLegacyLat);
    await prefs.remove(_kLegacyLng);
    await prefs.remove(_kLegacyIso);
    await prefs.remove(_kLegacyCityAr);
    await prefs.remove(_kLegacyCityEn);
  }
}

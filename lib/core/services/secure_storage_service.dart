import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Centralised wrapper around flutter_secure_storage.
/// All auth credentials MUST be read/written through this class —
/// never via SharedPreferences, which stores data as plaintext.
///
/// Android: uses EncryptedSharedPreferences backed by Android Keystore.
/// iOS:     uses Keychain with first-unlock-this-device accessibility
///          (token survives reboot but is NOT backed up to iCloud).
class SecureStorageService {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  static const _keyAuthToken     = 'auth_token';
  static const _keyRefreshToken  = 'refresh_token';
  // Cached device location (precise GPS lat/lng + resolved city) — PII, so it
  // lives here encrypted at rest (Keystore/Keychain) rather than in plaintext
  // SharedPreferences. Stored as a single JSON string.
  static const _keyLocationCache = 'location_cache';

  static Future<void>    saveAuthToken(String token) =>
      _storage.write(key: _keyAuthToken, value: token);

  static Future<String?> readAuthToken() =>
      _storage.read(key: _keyAuthToken);

  static Future<void>    saveRefreshToken(String token) =>
      _storage.write(key: _keyRefreshToken, value: token);

  static Future<String?> readRefreshToken() =>
      _storage.read(key: _keyRefreshToken);

  static Future<void>    saveLocationCache(String json) =>
      _storage.write(key: _keyLocationCache, value: json);

  static Future<String?> readLocationCache() =>
      _storage.read(key: _keyLocationCache);

  static Future<void>    deleteLocationCache() =>
      _storage.delete(key: _keyLocationCache);

  /// Clears ALL secure storage — call on logout.
  static Future<void> clearAll() => _storage.deleteAll();
}

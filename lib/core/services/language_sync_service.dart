import 'package:mubtaath/core/services/dio_client.dart';
import 'package:mubtaath/core/utils/debug_log.dart';
import 'package:mubtaath/core/services/secure_storage_service.dart';

/// Pushes the user's preferred locale to the backend so push notifications
/// are delivered in their chosen language.
///
/// Endpoint: POST /api/user/update-language  →  {"locale": "ar" | "en"}
///
/// No-ops when the user isn't authenticated yet (e.g. the language toggle on
/// the login screen) — the locale is re-synced on the next successful login.
class LanguageSyncService {
  const LanguageSyncService._();

  static Future<void> syncLocale(String locale) async {
    final token = await SecureStorageService.readAuthToken();
    if (token == null) return; // not logged in — sync deferred to next login

    try {
      await appDio.post('/user/update-language', data: {'locale': locale});
    } catch (e) {
      // Non-fatal — the locale is persisted locally and retried on next sync.
      logDebug('[LanguageSync] failed to update server locale: $e');
    }
  }
}

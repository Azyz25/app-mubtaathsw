import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mubtaath/core/services/fcm_topic_service.dart';
import 'package:mubtaath/core/services/language_sync_service.dart';

// Persists the selected locale across app restarts using SharedPreferences.
// Falls back to Arabic if the preference hasn't been set or storage fails.
class LanguageCubit extends Cubit<Locale> {
  // Also read by main.dart's FCM bootstrap (before this Cubit exists) to
  // pick the initial topic-subscription language.
  static const kLangKey = 'selected_language';
  static const _kLangKey = kLangKey;

  LanguageCubit() : super(const Locale('ar')) {
    _restoreLocale();
  }

  Future<void> _restoreLocale() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final code  = prefs.getString(_kLangKey) ?? 'ar';
      emit(Locale(code));
    } catch (_) {
      // Storage unavailable — remain on default Arabic
    }
  }

  Future<void> changeLanguage(String langCode) async {
    final oldLangCode = state.languageCode;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kLangKey, langCode);
    } catch (_) {
      // Persist best-effort — still switch in-memory
    }
    emit(Locale(langCode));

    // Sync the preference to the backend for localized push notifications.
    // No-ops when unauthenticated (e.g. login-screen toggle).
    await LanguageSyncService.syncLocale(langCode);

    // Move the FCM topic subscription too, so admin-broadcast pushes
    // (topics "all_ar" / "all_en") arrive in the newly-selected language.
    await FcmTopicService.switchLocale(oldLangCode, langCode);
  }

  bool get isArabic => state.languageCode == 'ar';
}

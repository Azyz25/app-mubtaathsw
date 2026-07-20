import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:mubtaath/core/utils/debug_log.dart';

/// Keeps the device's FCM topic subscription in sync with the app's
/// language so admin-broadcast pushes (topics "all_ar" / "all_en") are only
/// delivered in the language the user actually reads.
class FcmTopicService {
  const FcmTopicService._();

  static const _base = 'all';

  static Future<void> subscribeForLocale(String locale) async {
    try {
      await FirebaseMessaging.instance.subscribeToTopic('${_base}_$locale');
    } catch (e) {
      logDebug('[FcmTopic] subscribe failed: $e');
    }
  }

  static Future<void> switchLocale(String oldLocale, String newLocale) async {
    if (oldLocale == newLocale) return;
    try {
      await FirebaseMessaging.instance
          .unsubscribeFromTopic('${_base}_$oldLocale');
    } catch (e) {
      logDebug('[FcmTopic] unsubscribe failed: $e');
    }
    await subscribeForLocale(newLocale);
  }
}

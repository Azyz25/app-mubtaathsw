import 'package:shared_preferences/shared_preferences.dart';

/// User preference: show incoming chat messages as floating bubbles over the
/// live room. Moved out of the in-room chat sheet into app Settings. Default ON.
class FloatingMessagesSetting {
  static const _key = 'floating_messages_enabled';

  static Future<bool> get() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_key) ?? true;
    } catch (_) {
      return true;
    }
  }

  static Future<void> set(bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_key, value);
    } catch (_) {
      // Non-fatal.
    }
  }
}

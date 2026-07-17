import 'package:shared_preferences/shared_preferences.dart';

/// User preference: which bottom-navigation style to render on iOS.
/// 'liquid'  — the floating frosted-glass pill (default).
/// 'classic' — the same flat white bar used on Android.
/// Android always uses the classic bar regardless of this setting.
class NavStyleSetting {
  static const _key = 'ios_nav_style';
  static const liquid = 'liquid';
  static const classic = 'classic';

  static Future<String> get() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_key) ?? liquid;
    } catch (_) {
      return liquid;
    }
  }

  static Future<void> set(String value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, value);
    } catch (_) {
      // Non-fatal.
    }
  }
}

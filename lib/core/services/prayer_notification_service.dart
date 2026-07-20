// lib/core/services/prayer_notification_service.dart
//
// Schedules local notifications at each prayer's adhan time.
//
//   • On/off preference persisted in SharedPreferences.
//   • Uses the OS alarm scheduler (zonedSchedule) so notifications fire even
//     when the app is closed — several days are scheduled ahead each time the
//     prayer page loads, then refreshed on the next open / new day.
//   • Timezone-aware (TZDateTime) so times stay correct across DST.

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:permission_handler/permission_handler.dart' as ph;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'package:mubtaath/core/utils/debug_log.dart';

/// One scheduled prayer notification (title/body already localised).
class PrayerNotif {
  final int      id;
  final DateTime dateTime;
  final String   title;
  final String   body;

  const PrayerNotif({
    required this.id,
    required this.dateTime,
    required this.title,
    required this.body,
  });
}

class PrayerNotificationService {
  PrayerNotificationService._();
  static final PrayerNotificationService instance = PrayerNotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _inited = false;

  static const String _prefsKey  = 'prayer_notifications_enabled';
  // v2: bumped from 'prayer_times_channel'. Android/OEM notification channels
  // are permanently stuck once a user (or Samsung's own adaptive "notification
  // categories" heuristic) downgrades them — heads-up, sound, and visibility
  // can all get silently suppressed on the OLD channel with no way for the
  // app to reset it in code. A fresh channel id starts with a clean slate.
  // v3: routes the adhan alert through the ALARM audio stream (see _details),
  // so it's heard even when the phone's NOTIFICATION volume is low/0 (very
  // common on Samsung, where notification volume is a separate slider). The
  // alarm audio attributes are immutable once a channel exists, so a fresh id.
  static const String _channelId = 'prayer_times_alarm_v3';

  // ── Init: timezone database + plugin ────────────────────────────────────────
  Future<void> init() async {
    if (_inited) return;

    tzdata.initializeTimeZones();
    try {
      final localName = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(localName));
    } catch (_) {
      // Falls back to UTC — scheduling still works, just without DST niceties.
    }

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinInit  = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _plugin.initialize(
      const InitializationSettings(android: androidInit, iOS: darwinInit),
    );
    _inited = true;
  }

  // ── Preference ──────────────────────────────────────────────────────────────
  Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_prefsKey) ?? false;
  }

  // Current OS-level permission state, WITHOUT prompting — used to catch the
  // case where the user revoked notifications from system settings after
  // enabling in-app. The reschedule paths (page load, prayer-times refresh)
  // call zonedSchedule() unconditionally; Android accepts the call and just
  // silently drops delivery when the permission is gone, so nothing else
  // would ever surface this to the user.
  Future<bool> hasNotificationPermission() async {
    await init();
    if (kIsWeb) return true;
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      final enabled = await android.areNotificationsEnabled();
      return enabled ?? true;
    }
    return true;
  }

  Future<void> _setEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsKey, value);
  }

  // ── Permissions (Android 13+ POST_NOTIFICATIONS + exact alarms, iOS) ────────
  Future<bool> requestPermissions() async {
    await init();
    var granted = true;

    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      // Only the runtime POST_NOTIFICATIONS prompt is needed (Android 13+).
      // Exact-alarm scheduling is covered by the USE_EXACT_ALARM manifest
      // permission (auto-granted for alarm/reminder apps), so we deliberately
      // do NOT call requestExactAlarmsPermission() — it would bounce the user
      // to a system settings screen. schedule() falls back to inexact if exact
      // alarms are ever unavailable.
      final notif = await android.requestNotificationsPermission();
      granted = notif ?? true;

      // Samsung (and stock Android's Doze) aggressively defer/drop exact
      // alarms for apps it decides are "asleep". Exempting from battery
      // optimization is the standard fix for alarm-style apps (clocks,
      // reminders, adhan) so scheduled prayer notifications keep firing even
      // after the app hasn't been opened for a while. This shows a one-time
      // system dialog; declining it does not block notifications from being
      // enabled, it only makes background delivery less reliable.
      if (!kIsWeb) {
        try {
          final status = await ph.Permission.ignoreBatteryOptimizations.status;
          if (!status.isGranted) {
            await ph.Permission.ignoreBatteryOptimizations.request();
          }
        } catch (_) {
          // Not fatal — exact-alarm scheduling still works without it.
        }
      }
    }

    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    if (ios != null) {
      final ok = await ios.requestPermissions(alert: true, badge: true, sound: true);
      granted = ok ?? granted;
    }
    return granted;
  }

  // ── Enable: persist + (re)schedule ──────────────────────────────────────────
  Future<bool> enable(List<PrayerNotif> items) async {
    final granted = await requestPermissions();
    if (!granted) return false;
    await _setEnabled(true);
    await schedule(items);
    return true;
  }

  // ── Disable: persist + clear ────────────────────────────────────────────────
  Future<void> disable() async {
    await _setEnabled(false);
    await cancelAll();
  }

  // ── (Re)schedule — cancels everything then queues future prayers ────────────
  Future<void> schedule(List<PrayerNotif> items) async {
    await init();
    await _plugin.cancelAll();

    final now = tz.TZDateTime.now(tz.local);

    const details = _details;

    for (final item in items) {
      final when = tz.TZDateTime.from(item.dateTime, tz.local);
      if (!when.isAfter(now)) continue;
      try {
        await _plugin.zonedSchedule(
          item.id,
          item.title,
          item.body,
          when,
          details,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
        );
      } catch (e) {
        // Exact alarms may be blocked — fall back to an inexact schedule so
        // the notification still fires (a few minutes late at worst).
        logDebug('zonedSchedule failed, retrying inexact: $e');
        await _plugin.zonedSchedule(
          item.id,
          item.title,
          item.body,
          when,
          details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
        );
      }
    }
  }

  Future<void> cancelAll() async {
    await init();
    await _plugin.cancelAll();
  }

  // Shared presentation for every prayer notification.
  static const NotificationDetails _details = NotificationDetails(
    android: AndroidNotificationDetails(
      _channelId,
      'مواقيت الصلاة',
      channelDescription: 'إشعارات دخول وقت الصلاة',
      importance: Importance.max,
      priority:   Priority.high,
      playSound:  true,
      enableVibration: true,
      // Play on the ALARM stream so the adhan alert is heard even when the
      // phone's notification volume is turned down.
      audioAttributesUsage: AudioAttributesUsage.alarm,
    ),
    iOS: DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    ),
  );

  /// Fires an immediate test notification, plus one 12 seconds out so the user
  /// can background the app and confirm background delivery. Requests
  /// permission first; returns false if it was denied.
  Future<bool> sendTest(String title, String body) async {
    final granted = await requestPermissions();
    if (!granted) return false;

    // Immediate (foreground) test.
    await _plugin.show(990001, title, body, _details);

    // Background test — fired ~12 s out. Content MUST differ from the immediate
    // one (a unique time suffix), otherwise Samsung/One-UI de-duplicates it and
    // it silently never appears. Falls back to an inexact schedule if needed.
    final now    = tz.TZDateTime.now(tz.local);
    final bgBody = '$body (${now.hour.toString().padLeft(2, '0')}:'
        '${now.minute.toString().padLeft(2, '0')}:'
        '${now.second.toString().padLeft(2, '0')})';
    final when   = now.add(const Duration(seconds: 12));
    try {
      await _plugin.zonedSchedule(
        990002, title, bgBody, when, _details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (_) {
      await _plugin.zonedSchedule(
        990002, title, bgBody, when, _details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    }
    return true;
  }
}

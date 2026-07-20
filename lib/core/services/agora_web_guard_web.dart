import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:mubtaath/core/utils/debug_log.dart';

/// Polls [globalContext] until `createIrisApiEngine` is defined.
///
/// Timeline on web:
///   1. flutter_bootstrap.js starts → Flutter engine boots.
///   2. Plugin registrant runs → injects iris_web_rtc.js via a <script> tag.
///      This injection is async; the JS file must download before the function
///      is defined on window.
///   3. This guard polls every 100 ms so Dart never calls createAgoraRtcEngine()
///      before step 2 completes.
///
/// Throws [StateError] if the function is still absent after 4 seconds, which
/// means iris_web_rtc.js never loaded (bad build, blocked CDN, or missing
/// AgoraRTC_N script in index.html).
Future<void> waitForAgoraWebSdk() async {
  const checkInterval = Duration(milliseconds: 100);
  const maxAttempts   = 40; // 4 000 ms total

  for (var i = 0; i < maxAttempts; i++) {
    final fn = globalContext.getProperty<JSAny?>('createIrisApiEngine'.toJS);
    if (fn != null) {
      logDebug('[AgoraWebGuard] createIrisApiEngine ready after ${i * 100} ms.');
      return;
    }
    await Future.delayed(checkInterval);
  }

  throw StateError(
    '[Agora] iris_web_rtc.js did not expose createIrisApiEngine within 4 s.\n'
    'Check that:\n'
    '  • AgoraRTC_N-4.21.0.js is present in web/index.html <head> '
    'without async/defer.\n'
    '  • The Flutter build output includes the Agora web assets '
    '(run flutter build web and inspect build/web/).',
  );
}

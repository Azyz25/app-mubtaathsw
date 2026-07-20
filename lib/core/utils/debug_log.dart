// lib/core/utils/debug_log.dart
//
// Flutter's debugPrint() is NOT stripped from release builds — bare
// debugPrint() calls still write to the device's system log (logcat /
// Console.app) in production. Route internal trace logging through this
// instead so it's a true no-op in release: nothing written to the OS log,
// no perf cost, and no chance of leaking request/response internals.

import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;

void logDebug(String message) {
  if (kDebugMode) debugPrint(message);
}

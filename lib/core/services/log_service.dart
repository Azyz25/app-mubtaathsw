// lib/core/services/log_service.dart
//
// Best-effort crash/error reporting to the backend (POST /api/logs), which
// surfaces on the admin dashboard for triage. Captures device + build metadata
// once and attaches it to every report. Uploads only in non-debug builds so a
// developer's console errors don't flood production logs.
//
// Levels: 'fatal'   — an uncaught crash (global handlers below),
//         'error'   — a handled exception worth knowing about,
//         'warning' — a minor/recoverable issue.

import 'dart:io' show Platform;

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:mubtaath/core/services/dio_client.dart';

class LogService {
  LogService._();
  static final LogService instance = LogService._();

  Map<String, String?>? _device;

  Future<Map<String, String?>> _deviceInfo() async {
    if (_device != null) return _device!;

    final info = <String, String?>{
      'platform': Platform.isIOS
          ? 'ios'
          : Platform.isAndroid
              ? 'android'
              : Platform.operatingSystem,
      'app_version':         null,
      'device_model':        null,
      'device_manufacturer': null,
      'os_version':          null,
    };

    try {
      final pkg = await PackageInfo.fromPlatform();
      info['app_version'] = '${pkg.version}+${pkg.buildNumber}';
    } catch (_) {/* best-effort */}

    try {
      final di = DeviceInfoPlugin();
      if (Platform.isIOS) {
        final ios = await di.iosInfo;
        info['device_model']        = ios.utsname.machine;         // iPhone15,2
        info['device_manufacturer'] = 'Apple';
        info['os_version']          = '${ios.systemName} ${ios.systemVersion}';
      } else if (Platform.isAndroid) {
        final a = await di.androidInfo;
        info['device_model']        = a.model;
        info['device_manufacturer'] = a.manufacturer;
        info['os_version']          = 'Android ${a.version.release} (SDK ${a.version.sdkInt})';
      }
    } catch (_) {/* best-effort */}

    _device = info;
    return info;
  }

  /// Fire-and-forget — never throws, never blocks the UI, silent in debug.
  Future<void> report({
    required String level,
    required String message,
    String? exceptionType,
    String? stackTrace,
    String? route,
  }) async {
    if (kDebugMode) return; // don't ship dev-console noise to production logs
    try {
      final device = await _deviceInfo();
      await appDio.post('/logs', data: {
        'level':   level,
        'message': message,
        if (exceptionType != null) 'exception_type': exceptionType,
        if (stackTrace != null)    'stack_trace':    stackTrace,
        if (route != null)         'route':          route,
        ...device,
      });
    } catch (_) {
      // Reporting is best-effort; a logging failure must never surface.
    }
  }
}

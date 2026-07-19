import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter/foundation.dart';
import 'package:mubtaath/core/auth_notifier.dart';
import 'package:mubtaath/core/services/api_trust_roots.dart';
import 'package:mubtaath/core/services/secure_storage_service.dart';

// BASE_URL is injected at compile time via --dart-define=BASE_URL=...
// When omitted (e.g. a plain `flutter build apk`), the PRODUCTION API is used.
//
// Local development override examples:
//   Android emulator → --dart-define=BASE_URL=http://10.0.2.2:8000/api
//   Web / iOS sim    → --dart-define=BASE_URL=http://localhost:8000/api
const _definedUrl = String.fromEnvironment('BASE_URL', defaultValue: '');

/// Production API base — the live server. Used for release builds and any
/// build that does not override BASE_URL via --dart-define.
const _productionBaseUrl = 'https://api.mubtaathub.com/api';

String _resolveBaseUrl() {
  if (_definedUrl.isNotEmpty) return _definedUrl;
  return _productionBaseUrl;
}

Dio createDioClient() {
  final baseUrl = _resolveBaseUrl();

  if (kDebugMode && _definedUrl.isEmpty) {
    debugPrint(
      '[DioClient] BASE_URL not set via --dart-define. '
      'Using fallback: $baseUrl',
    );
  }

  final dio = Dio(
    BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 15),
      sendTimeout:    const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
      headers: {
        'Accept':        'application/json',
        'Content-Type':  'application/json',
        'X-Client':      'flutter',
        'X-Device-Name': 'flutter-app',
      },
    ),
  );

  // ── TLS pinning (production only) ─────────────────────────────────────────
  // Give the production client a trust store containing ONLY the roots the real
  // API certificate chains to (ISRG Root X1/X2 — see api_trust_roots.dart). A
  // man-in-the-middle using a rogue/corporate/malware CA is rejected: its chain
  // doesn't terminate at those roots, so validation fails and the request never
  // leaves the device. Skipped for --dart-define BASE_URL dev overrides so a
  // local http / self-signed dev server still works.
  if (_definedUrl.isEmpty) {
    dio.httpClientAdapter = IOHttpClientAdapter(
      createHttpClient: () {
        final context = SecurityContext(withTrustedRoots: false);
        try {
          context.setTrustedCertificatesBytes(utf8.encode(kApiTrustRootsPem));
        } catch (_) {
          // Certs already present on a reused context — safe to ignore.
        }
        return HttpClient(context: context);
      },
    );
  }

  // Auth interceptor — injects Bearer token from SecureStorage on every request.
  // On 401 it clears the stored token so the app re-routes to login.
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) async {
        try {
          final token = await SecureStorageService.readAuthToken();
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
        } catch (e) {
          // SecureStorage failure must never block the request on web
          debugPrint('[DioClient] SecureStorage read failed: $e');
        }
        return handler.next(options);
      },
      onError: (error, handler) {
        final status = error.response?.statusCode;

        if (status == 401) {
          SecureStorageService.clearAll().ignore();
          authNotifier.value = false;
        } else if (status == 403) {
          final code = error.response?.data?['code'] as String?;
          if (code == 'account_suspended') {
            // Sign the user out and flag the suspended state so GoRouter
            // redirects to /suspended instead of /login.
            SecureStorageService.clearAll().ignore();
            suspendedNotifier.value = true;
            authNotifier.value = false;
          }
        }
        return handler.next(error);
      },
    ),
  );

  // Request/response logging — debug builds only.
  if (kDebugMode) {
    dio.interceptors.add(
      LogInterceptor(
        requestBody:   true,
        responseBody:  true,
        requestHeader: true,
        logPrint: (o) => debugPrint('[DIO] $o'),
      ),
    );
  }

  return dio;
}

/// App-wide Dio instance.
final appDio = createDioClient();
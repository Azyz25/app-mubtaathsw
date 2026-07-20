// lib/core/security/tamper_guard_service.dart
//
// D2/D3 — runtime environment checks: root/jailbreak, debugger attached,
// hooking frameworks (Frida/Xposed), emulator/simulator, Android developer
// mode, ADB enabled. WARN-only, never blocks — false positives on a
// legitimate power-user's rooted-but-trusted device are a real risk, so this
// shows a single dismissible one-time banner rather than locking anyone out.
//
// App-integrity (signing-certificate match) and Dart-obfuscation checks are
// DELIBERATELY left as no-ops below. freerasp needs the real production
// signing certificate's SHA-256 hash (Android) and Apple Team ID (iOS) to
// evaluate those correctly; the app currently ships signed with the Android
// DEBUG keystore (see windows-android-build-fixes notes), so there is no
// real release hash yet to configure. Wiring onAppIntegrity now — even in
// warn-only mode — would show every single legitimate user a "this app has
// been tampered with" warning on every launch, since the placeholder hash
// below can never match a real signer by construction. See the runbook at
// the bottom of this file for how to switch it on once a real release
// keystore exists.

import 'package:flutter/foundation.dart';
import 'package:freerasp/freerasp.dart';
import 'package:mubtaath/core/utils/debug_log.dart';

enum TamperThreat { root, debug, hooks, emulator, devMode, adb }

typedef ThreatHandler = void Function(TamperThreat threat);

class TamperGuardService {
  TamperGuardService._();
  static final TamperGuardService instance = TamperGuardService._();

  bool _started = false;

  /// Starts listening. [onThreat] is called at most once per threat type per
  /// app session — callers should show a single dismissible warning, not a
  /// repeated dialog. No-ops in debug builds (every one of these fires
  /// constantly under `flutter run`) and if called twice.
  Future<void> start(ThreatHandler onThreat) async {
    if (kDebugMode || _started) return;
    _started = true;

    final seen = <TamperThreat>{};
    void notifyOnce(TamperThreat threat) {
      if (seen.add(threat)) onThreat(threat);
    }

    final callback = ThreatCallback(
      onPrivilegedAccess: () => notifyOnce(TamperThreat.root),
      onDebug: () => notifyOnce(TamperThreat.debug),
      onHooks: () => notifyOnce(TamperThreat.hooks),
      onSimulator: () => notifyOnce(TamperThreat.emulator),
      onDevMode: () => notifyOnce(TamperThreat.devMode),
      onADBEnabled: () => notifyOnce(TamperThreat.adb),
      // Intentional no-ops — see file header.
      onAppIntegrity: () {},
      onObfuscationIssues: () {},
      // Checks not relevant to this app's threat model — left unhandled.
      onPasscode: null,
      onDeviceID: null,
      onDeviceBinding: null,
      onUnofficialStore: null,
      onSecureHardwareNotAvailable: null,
      onSystemVPN: null,
      onScreenshot: null,
      onScreenRecording: null,
    );

    try {
      Talsec.instance.attachListener(callback);
      await Talsec.instance.start(_config);
    } catch (e) {
      logDebug('[TamperGuardService] start failed: $e');
    }
  }

  // Placeholder — 32 zero bytes, base64-encoded. Syntactically valid (so
  // AndroidConfig's constructor doesn't throw at startup) but can never
  // match a real signing certificate, which is exactly why onAppIntegrity
  // is a no-op above rather than wired to the warning banner.
  static const _placeholderSigningHash =
      'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=';

  static final _config = TalsecConfig(
    watcherMail: 'noreply@mubtaathub.com',
    androidConfig: AndroidConfig(
      packageName: 'com.mubtaathub.app',
      signingCertHashes: [_placeholderSigningHash],
    ),
    iosConfig: IOSConfig(
      bundleIds: ['com.mubtaathub.app'],
      teamId: '<<<APPLE_TEAM_ID>>>',
    ),
  );

  // ── Runbook: activating app-integrity checking later ─────────────────────
  // 1. Android: once the app is signed with a REAL release keystore (not the
  //    debug key it ships with today), get that keystore's signing
  //    certificate SHA-256 fingerprint and re-encode it as base64:
  //      keytool -list -v -keystore <release>.jks -alias <alias>
  //        | grep 'SHA256:' | cut -d' ' -f3 | tr -d ':' \
  //        | xxd -r -p | base64
  //    Replace _placeholderSigningHash above with that value. If enrolled in
  //    Google Play App Signing, use the certificate Play Console shows under
  //    Setup → App signing (Play re-signs the APK with its own key before
  //    distribution — that key's hash is the one devices actually see).
  // 2. iOS: Apple Developer → Membership → Team ID, put it in `teamId` above.
  // 3. Move onAppIntegrity (and onObfuscationIssues, once C1's --obfuscate
  //    flag is confirmed active in the build that ships) from the no-op
  //    block into notifyOnce(...) like the others.
}

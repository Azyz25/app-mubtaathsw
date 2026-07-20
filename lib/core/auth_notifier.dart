import 'package:flutter/foundation.dart';
import 'package:mubtaath/core/security/tamper_guard_service.dart';

/// Global auth state for GoRouter redirect guard.
/// Set to true after login/OTP success; false on logout.
final ValueNotifier<bool> authNotifier = ValueNotifier<bool>(false);

/// Set to true when the server returns 403 + code:account_suspended.
/// The GoRouter redirect checks this to route to /suspended instead of /login.
/// Reset to false after navigating to the suspended screen so back-navigation works.
final ValueNotifier<bool> suspendedNotifier = ValueNotifier<bool>(false);

/// D2/D3 — set by TamperGuardService the first time a runtime-environment
/// threat (root, debugger, hooking, emulator, dev mode, ADB) is detected.
/// HomePage listens and shows a single dismissible warning, then leaves this
/// non-null for the rest of the session so it never re-prompts.
final ValueNotifier<TamperThreat?> tamperThreatNotifier =
    ValueNotifier<TamperThreat?>(null);

import 'package:flutter/foundation.dart';

/// Global auth state for GoRouter redirect guard.
/// Set to true after login/OTP success; false on logout.
final ValueNotifier<bool> authNotifier = ValueNotifier<bool>(false);

/// Set to true when the server returns 403 + code:account_suspended.
/// The GoRouter redirect checks this to route to /suspended instead of /login.
/// Reset to false after navigating to the suspended screen so back-navigation works.
final ValueNotifier<bool> suspendedNotifier = ValueNotifier<bool>(false);

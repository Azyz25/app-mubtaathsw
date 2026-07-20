// lib/core/security/screenshot_blocker_mixin.dart
//
// D1 — blocks screenshots/screen-recording and hides the app-switcher
// preview while a credential screen is on screen: Android gets FLAG_SECURE
// (the screenshot comes out black, screen recording is refused outright);
// iOS can't block screenshots (no such API exists for third-party apps) but
// gets a blur placed over the view the instant it's recorded or backgrounded,
// so a screen-recording or the app-switcher thumbnail never shows real
// content. Scoped per-screen via mixin — protection turns off the moment the
// user navigates away, it is never left on app-wide.

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:screen_protector/screen_protector.dart';

mixin ScreenshotBlockerMixin<T extends StatefulWidget> on State<T> {
  @override
  void initState() {
    super.initState();
    unawaited(ScreenProtector.preventScreenshotOn());
    unawaited(ScreenProtector.protectDataLeakageWithBlur());
  }

  @override
  void dispose() {
    unawaited(ScreenProtector.preventScreenshotOff());
    unawaited(ScreenProtector.protectDataLeakageOff());
    super.dispose();
  }
}

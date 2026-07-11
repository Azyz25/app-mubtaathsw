// Native stub — on iOS/Android the Agora SDK is loaded via native FFI and is
// always ready before Dart code can call it. Nothing to wait for.
Future<void> waitForAgoraWebSdk() async {}

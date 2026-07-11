/// Reverb WebSocket configuration.
///
/// Defaults to the PRODUCTION Reverb endpoint (proxied behind the API domain
/// over TLS on 443). Override at build time for local development, e.g.:
///   --dart-define=REVERB_SCHEME=ws --dart-define=REVERB_HOST=10.0.2.2 --dart-define=REVERB_PORT=8090
class ReverbConfig {
  ReverbConfig._();

  static const String _definedKey    = String.fromEnvironment('REVERB_KEY',    defaultValue: '');
  static const String _definedHost   = String.fromEnvironment('REVERB_HOST',   defaultValue: '');
  static const int    _definedPort   = int.fromEnvironment('REVERB_PORT',      defaultValue: 0);
  static const String _definedScheme = String.fromEnvironment('REVERB_SCHEME', defaultValue: '');

  // Production Reverb — same host as the API, secure WebSocket on 443.
  static const String _prodHost   = 'api.mubtaathub.com';
  static const String _prodScheme = 'wss';

  static String get appKey => _definedKey.isNotEmpty ? _definedKey : 'mubtaath-key';

  static String get host => _definedHost.isNotEmpty ? _definedHost : _prodHost;

  static String get scheme => _definedScheme.isNotEmpty ? _definedScheme : _prodScheme;

  // Port is only appended for insecure/local connections. On wss (443) the
  // reverse proxy terminates TLS and forwards /app to Reverb, so no port.
  static int get wsPort => _definedPort > 0 ? _definedPort : 8090;

  static String get wsUrl {
    final secure = scheme == 'wss';
    final authority = secure ? host : '$host:$wsPort';
    return '$scheme://$authority/app/$appKey'
        '?protocol=7&client=flutter&version=1.0.0&flash=false';
  }
}

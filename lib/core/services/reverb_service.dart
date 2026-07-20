import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:mubtaath/core/config/reverb_config.dart';
import 'package:mubtaath/core/utils/debug_log.dart';

typedef NotificationPayloadCallback = void Function(Map<String, dynamic> payload);

/// Minimal Laravel Reverb client using the Pusher WebSocket protocol v7.
///
/// Lifecycle:
///   1. Call [connect] once — opens the socket and subscribes to [_channelName].
///   2. Assign [onNotification] to receive parsed event payloads.
///   3. Call [dispose] in the cubit's close() method to release all resources.
///
/// The service reconnects automatically 5 seconds after any disconnect or
/// error, making it resilient to temporary network drops and Reverb restarts.
///
/// Protocol details:
///   • After the TCP handshake the server sends `pusher:connection_established`.
///     We immediately send `pusher:subscribe` for the public channel.
///   • Every ~30 s the server sends `pusher:ping`; we reply with `pusher:pong`
///     to keep the connection alive.
///   • Event data is double-encoded: the outer envelope is JSON, and the
///     `data` field inside is itself a JSON string that must be decoded again.
class ReverbService {
  static const _channelName = 'admin-notifications';
  static const _eventName   = 'NotificationSent';

  WebSocketChannel?            _ws;
  StreamSubscription<dynamic>? _sub;
  Timer?                       _reconnectTimer;
  bool                         _disposed = false;

  /// Set this before calling [connect].
  /// Called on the cubit's isolate for every incoming [_eventName] payload.
  NotificationPayloadCallback? onNotification;

  /// Opens the WebSocket connection using the URL built by [ReverbConfig].
  void connect() {
    if (_disposed) return;
    try {
      _ws = WebSocketChannel.connect(Uri.parse(ReverbConfig.wsUrl));
      _sub = _ws!.stream.listen(
        _onMessage,
        onError: (_) => _scheduleReconnect(),
        onDone:  ()  => _scheduleReconnect(),
        cancelOnError: true,
      );
    } catch (e) {
      logDebug('[ReverbService] connect error: $e');
      _scheduleReconnect();
    }
  }

  void _onMessage(dynamic raw) {
    try {
      final envelope = jsonDecode(raw as String) as Map<String, dynamic>;
      final event    = envelope['event'] as String? ?? '';

      // Reply to server keep-alive ping so the connection is not dropped.
      if (event == 'pusher:ping') {
        _ws?.sink.add(jsonEncode({'event': 'pusher:pong', 'data': {}}));
        return;
      }

      // Once connected, subscribe to the public channel immediately.
      if (event == 'pusher:connection_established') {
        _ws?.sink.add(jsonEncode({
          'event': 'pusher:subscribe',
          'data':  {'channel': _channelName},
        }));
        return;
      }

      if (event != _eventName) return;

      // Pusher protocol wraps the payload as a JSON string inside the envelope —
      // decode it a second time to get the actual notification fields.
      final dataRaw = envelope['data'];
      final data    = dataRaw is String
          ? jsonDecode(dataRaw) as Map<String, dynamic>
          : dataRaw as Map<String, dynamic>;

      onNotification?.call(data);
    } catch (e) {
      logDebug('[ReverbService] message parse error: $e');
    }
  }

  void _scheduleReconnect() {
    if (_disposed) return;
    _sub?.cancel();
    _ws?.sink.close();
    _ws  = null;
    _sub = null;
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 5), connect);
  }

  void dispose() {
    _disposed = true;
    _reconnectTimer?.cancel();
    _sub?.cancel();
    _ws?.sink.close();
  }
}

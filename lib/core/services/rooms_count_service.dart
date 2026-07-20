import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:mubtaath/core/config/reverb_config.dart';
import 'package:mubtaath/core/utils/debug_log.dart';

typedef RoomCountCallback = void Function(String roomId, int count);

/// Lightweight Reverb client for the PUBLIC `rooms` channel.
///
/// The backend broadcasts UserJoined / UserLeft / ParticipantUpdated on this
/// channel (in addition to each room's private channel) with `{roomId, count}`.
/// Subscribing here lets the home & community room cards keep their headcount
/// live without joining every room's private channel.
///
/// Owned by [RoomStatusCubit] for the whole session; reconnects automatically
/// 5 s after any drop, mirroring [ReverbService].
class RoomsCountService {
  static const _channelName = 'rooms';
  static const _countEvents = {'UserJoined', 'UserLeft', 'ParticipantUpdated'};

  WebSocketChannel?            _ws;
  StreamSubscription<dynamic>? _sub;
  Timer?                       _reconnectTimer;
  bool                         _disposed = false;

  /// Called on every count event with the room id and its fresh headcount.
  RoomCountCallback? onCount;

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
      logDebug('[RoomsCountService] connect error: $e');
      _scheduleReconnect();
    }
  }

  void _onMessage(dynamic raw) {
    try {
      final envelope = jsonDecode(raw as String) as Map<String, dynamic>;
      final event    = envelope['event'] as String? ?? '';

      if (event == 'pusher:ping') {
        _ws?.sink.add(jsonEncode({'event': 'pusher:pong', 'data': {}}));
        return;
      }

      if (event == 'pusher:connection_established') {
        _ws?.sink.add(jsonEncode({
          'event': 'pusher:subscribe',
          'data':  {'channel': _channelName},
        }));
        return;
      }

      // Pusher prefixes app events with nothing (broadcastAs sets a clean name),
      // but tolerate the fully-qualified 'App\Events\...' form too.
      final shortName = event.contains('\\') ? event.split('\\').last : event;
      if (!_countEvents.contains(shortName)) return;

      final dataRaw = envelope['data'];
      final data    = dataRaw is String
          ? jsonDecode(dataRaw) as Map<String, dynamic>
          : dataRaw as Map<String, dynamic>;

      final roomId = data['roomId']?.toString() ?? '';
      final count  = (data['count'] as num?)?.toInt();
      if (roomId.isNotEmpty && count != null) {
        onCount?.call(roomId, count);
      }
    } catch (e) {
      logDebug('[RoomsCountService] parse error: $e');
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

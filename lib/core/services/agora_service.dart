import 'dart:async';

import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/foundation.dart';
import 'package:mubtaath/core/config/agora_config.dart';
import 'package:mubtaath/core/utils/debug_log.dart';
import 'agora_web_guard_stub.dart'
    if (dart.library.html) 'agora_web_guard_web.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Agora domain events — the cubit subscribes to this stream.
// ─────────────────────────────────────────────────────────────────────────────

sealed class AgoraEvent {}

class AgoraJoinSuccess extends AgoraEvent {
  final int uid;
  AgoraJoinSuccess(this.uid);
}

class AgoraUserJoined extends AgoraEvent {
  final int uid;
  AgoraUserJoined(this.uid);
}

class AgoraUserOffline extends AgoraEvent {
  final int uid;
  AgoraUserOffline(this.uid);
}

class AgoraLeftChannel extends AgoraEvent {
  AgoraLeftChannel();
}

class AgoraError extends AgoraEvent {
  final ErrorCodeType code;
  AgoraError(this.code);
}

/// Periodic snapshot of who is actively talking, derived from Agora's
/// `onAudioVolumeIndication`. Carries the Agora UIDs whose instantaneous
/// volume crossed the speaking threshold. UID `0` represents the local user.
/// A remote participant muted/unmuted their microphone. Drives the live
/// mic-on/off badge in the grid without any backend round-trip.
class AgoraMuteUpdate extends AgoraEvent {
  final int uid;
  final bool muted;
  AgoraMuteUpdate(this.uid, this.muted);
}

class AgoraSpeakingUpdate extends AgoraEvent {
  final Set<int> speakingUids;
  AgoraSpeakingUpdate(this.speakingUids);
}

// ─────────────────────────────────────────────────────────────────────────────
// AgoraService — singleton managing the RtcEngine lifecycle.
//
// Usage pattern:
//   await AgoraService.instance.initialize();
//   AgoraService.instance.events.listen(_handleEvent);
//   await AgoraService.instance.joinChannel(channelId: 'my-room', token: '');
//   ...
//   await AgoraService.instance.releaseEngine();
// ─────────────────────────────────────────────────────────────────────────────

class AgoraService {
  AgoraService._();

  static final AgoraService instance = AgoraService._();

  RtcEngine? _engine;

  // Speaking state from onAudioVolumeIndication. Agora fires that callback
  // twice per interval — once for the local user (reported as uid 0) and once
  // for the loudest remote users (their real uids). The two reports are tracked
  // separately and merged so neither overwrites the other.
  final Set<int> _localSpeaking = {};
  final Set<int> _remoteSpeaking = {};

  // Agora reports volume on a 0–255 scale; at/above this counts as "talking".
  static const int _speakingThreshold = 20;

  // Broadcast so multiple cubits / widgets can listen without conflicts.
  final _eventCtrl = StreamController<AgoraEvent>.broadcast();

  Stream<AgoraEvent> get events => _eventCtrl.stream;

  bool get isInitialized => _engine != null;

  /// Initialises the Agora RTC engine.
  /// Safe to call multiple times — subsequent calls are no-ops.
  Future<void> initialize() async {
    if (_engine != null) {
      logDebug('[AgoraService] initialize() — engine already running, skipping.');
      return;
    }

    logDebug(
      '[AgoraService] initialize() — START. '
      'appId=${agoraAppId.isNotEmpty ? "${agoraAppId.substring(0, 8)}..." : "EMPTY ⚠️"}',
    );

    // On web, iris_web_rtc.js is injected by the plugin registrant asynchronously
    // after Flutter boots. Poll until createIrisApiEngine is on window before
    // calling createAgoraRtcEngine() — otherwise the JS interop throws a TypeError
    // that escapes Dart's try-catch and crashes the app.
    if (kIsWeb) {
      await waitForAgoraWebSdk();
    }

    if (agoraAppId.isEmpty) {
      throw StateError(
        'AGORA_APP_ID is not configured. '
        'Pass --dart-define=AGORA_APP_ID=<id> at build time.',
      );
    }

    _engine = createAgoraRtcEngine();
    logDebug('[AgoraService] initialize() — RtcEngine instance created.');

    await _engine!.initialize(
      const RtcEngineContext(
        appId: agoraAppId,
        channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
      ),
    );
    logDebug('[AgoraService] initialize() — RtcEngine.initialize() succeeded.');

    _engine!.registerEventHandler(
      RtcEngineEventHandler(
        onJoinChannelSuccess: (connection, elapsed) {
          logDebug('[AgoraService] ✅ onJoinChannelSuccess — uid=${connection.localUid} elapsed=${elapsed}ms');
          _eventCtrl.add(AgoraJoinSuccess(connection.localUid ?? 0));
        },
        onUserJoined: (connection, remoteUid, elapsed) {
          logDebug('[AgoraService] onUserJoined — remoteUid=$remoteUid');
          _eventCtrl.add(AgoraUserJoined(remoteUid));
        },
        onUserOffline: (connection, remoteUid, reason) {
          logDebug('[AgoraService] onUserOffline — remoteUid=$remoteUid reason=$reason');
          _eventCtrl.add(AgoraUserOffline(remoteUid));
        },
        // Live mic on/off for remote users → updates the grid badge instantly.
        onUserMuteAudio: (connection, remoteUid, muted) {
          logDebug('[AgoraService] onUserMuteAudio — uid=$remoteUid muted=$muted');
          _eventCtrl.add(AgoraMuteUpdate(remoteUid, muted));
        },
        onLeaveChannel: (connection, stats) {
          logDebug('[AgoraService] onLeaveChannel — txBytes=${stats.txBytes}');
          _eventCtrl.add(AgoraLeftChannel());
        },
        onError: (code, msg) {
          logDebug('[AgoraService] ❌ onError — code=${code.name} msg=$msg');
          _eventCtrl.add(AgoraError(code));
        },
        onAudioVolumeIndication: (connection, speakers, speakerNumber, totalVolume) {
          // The local report always carries a single entry with uid == 0;
          // the remote report carries the real uids of the loudest speakers.
          // Update only the matching set, then emit the merged union so the
          // two independent callbacks never clobber each other.
          final isLocalReport = speakers.any((s) => (s.uid ?? -1) == 0);
          final target = isLocalReport ? _localSpeaking : _remoteSpeaking;
          target.clear();
          for (final s in speakers) {
            if ((s.volume ?? 0) >= _speakingThreshold) {
              target.add(s.uid ?? 0);
            }
          }
          _eventCtrl.add(
            AgoraSpeakingUpdate({..._localSpeaking, ..._remoteSpeaking}),
          );
        },
      ),
    );
    logDebug('[AgoraService] initialize() — event handler registered.');

    await _engine!.setClientRole(role: ClientRoleType.clientRoleBroadcaster);
    await _engine!.enableAudio();

    // Emit periodic per-speaker volume so the UI can ring the avatar of whoever
    // is actually talking (see onAudioVolumeIndication above). reportVad lets
    // Agora apply voice-activity detection for steadier indication.
    await _engine!.enableAudioVolumeIndication(
      interval: 250,
      smooth: 3,
      reportVad: true,
    );

    // ── DEBUG ONLY: in-ear monitoring ──────────────────────────────────────────
    // Plays your own mic back through your earphones so you can confirm the mic
    // and Agora engine are alive without needing a second device. Gated behind
    // kDebugMode below, so this never activates in a release build.
    //
    // ⚠️  REQUIRES EARPHONES — on speaker you will get loud audio feedback.
    // ⚠️  enableLoopbackRecording() is Windows/macOS desktop only and does NOT
    //     exist on Android/iOS. enableInEarMonitoring is the correct mobile API.
    if (kDebugMode) {
      await _engine!.enableInEarMonitoring(
        enabled: true,
        includeAudioFilters:
            EarMonitoringFilterType.earMonitoringFilterNone,
      );
      logDebug('[AgoraService] initialize() — ⚠️  IN-EAR MONITORING ON (debug only). '
          'Plug in earphones to hear your own mic.');
    }

    logDebug('[AgoraService] initialize() — COMPLETE. Role=Broadcaster, Audio=enabled.');
  }

  /// Joins an Agora channel.
  ///
  /// [token] — pass an empty string when App Certificate is disabled (dev/test).
  ///           In production, always supply a token generated by your backend.
  /// [uid]   — 0 lets Agora assign a UID automatically.
  Future<void> joinChannel({
    required String channelId,
    required String token,
    int uid = 0,
  }) async {
    logDebug(
      '[AgoraService] joinChannel() — START. '
      'channelId=$channelId, uid=$uid, '
      'tokenPrefix=${token.isEmpty ? "EMPTY (no-cert mode)" : "${token.substring(0, token.length.clamp(0, 12))}..."}',
    );
    if (!isInitialized) {
      throw StateError('Call initialize() before joinChannel().');
    }
    await _engine!.joinChannel(
      token: token.isEmpty ? '' : token,
      channelId: channelId,
      uid: uid,
      options: const ChannelMediaOptions(
        channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
        clientRoleType: ClientRoleType.clientRoleBroadcaster,
        publishMicrophoneTrack: true,
        autoSubscribeAudio: true,
      ),
    );
    logDebug('[AgoraService] joinChannel() — native joinChannel() dispatched. '
        'Awaiting onJoinChannelSuccess callback...');
  }

  /// Leaves the current channel without destroying the engine.
  Future<void> leaveChannel() async {
    _localSpeaking.clear();
    _remoteSpeaking.clear();
    await _engine?.leaveChannel();
  }

  /// Mutes or unmutes the local microphone track.
  Future<void> muteLocalAudio({required bool mute}) async {
    logDebug(
      '[AgoraService] muteLocalAudio(mute=$mute) — '
      'engine=${_engine != null ? "ready" : "NULL — call will be skipped ⚠️"}',
    );
    await _engine?.muteLocalAudioStream(mute);
    logDebug('[AgoraService] muteLocalAudio(mute=$mute) — native call completed.');
  }

  /// Routes audio output to the speakerphone (true) or earpiece (false).
  Future<void> toggleSpeakerphone(bool enabled) async {
    await _engine?.setEnableSpeakerphone(enabled);
  }

  /// Releases the engine and frees native resources.
  /// Call this when the user permanently exits the audio room feature —
  /// not just when leaving a channel.
  Future<void> releaseEngine() async {
    await leaveChannel();
    _engine?.unregisterEventHandler(const RtcEngineEventHandler());
    await _engine?.release();
    _engine = null;
  }
}

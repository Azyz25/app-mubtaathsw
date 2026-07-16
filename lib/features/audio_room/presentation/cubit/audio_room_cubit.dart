import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mubtaath/core/services/agora_service.dart';
import 'package:mubtaath/core/services/dio_client.dart';
import 'audio_room_state.dart';

class AudioRoomCubit extends Cubit<AudioRoomState> {
  AudioRoomCubit() : super(const AudioRoomState());

  StreamSubscription<AgoraEvent>? _sub;
  final _agora = AgoraService.instance;

  // Stored so leaveRoom() can call POST /rooms/{id}/leave without re-navigation.
  String? _channelId;

  /// Full join flow:
  ///   1. POST /api/rooms/{channelId}/join    → registers user as participant
  ///   2. POST /api/agora/token               → fetches a signed RTC token
  ///   3. AgoraService.joinChannel()          → enters the live audio channel
  Future<void> joinRoom({required String channelId}) async {
    if (state.status == AudioRoomStatus.connecting ||
        state.status == AudioRoomStatus.connected) {
      return;
    }

    _channelId = channelId;
    emit(state.copyWith(status: AudioRoomStatus.connecting, clearError: true));

    try {
      // ── Step 1: register participant in the database ───────────────────────
      await appDio.post('/rooms/$channelId/join');

      // ── Step 2: fetch a signed Agora RTC token from the backend ───────────
      final tokenResp = await appDio.post('/agora/token', data: {
        'channel_id': channelId,
      });
      // ── UID TRACE ──────────────────────────────────────────────────────────
      debugPrint('[UID_TRACE][AudioRoomCubit] STEP1 tokenResp.data = ${tokenResp.data}');
      debugPrint('[UID_TRACE][AudioRoomCubit] STEP1 tokenResp.data runtimeType = ${tokenResp.data?.runtimeType}');

      final tokenData = tokenResp.data['data'] as Map<String, dynamic>;
      debugPrint('[UID_TRACE][AudioRoomCubit] STEP2 tokenData = $tokenData');
      debugPrint('[UID_TRACE][AudioRoomCubit] STEP2 tokenData[uid] = ${tokenData['uid']} (type=${tokenData['uid']?.runtimeType})');

      final token = tokenData['token'] as String;
      // The token is generated for this specific uid — joinChannel MUST use
      // the same uid or Agora returns errInvalidToken.
      final uid = (tokenData['uid'] as num?)?.toInt() ?? 0;
      debugPrint('[UID_TRACE][AudioRoomCubit] STEP3 extracted uid = $uid');
      // ── END UID TRACE ──────────────────────────────────────────────────────

      // ── Step 3: initialise Agora engine and enter the channel ─────────────
      // StateError here means the SDK did not load (web race) or the App ID is
      // missing. Treat it as a soft connectivity warning — the room page stays
      // open so the user can retry or leave gracefully.
      try {
        await _agora.initialize();
      } on StateError catch (e) {
        debugPrint('[AudioRoomCubit] Agora init failed: $e');
        emit(state.copyWith(
          status: AudioRoomStatus.warning,
          errorMessage: e.toString(),
        ));
        return;
      }

      _sub ??= _agora.events.listen(_onEvent);
      debugPrint('[UID_TRACE][AudioRoomCubit] STEP4 passing uid=$uid to _agora.joinChannel()');
      await _agora.joinChannel(channelId: channelId, token: token, uid: uid);
      // Apply mic / speaker preferences immediately after joining.
      await _agora.muteLocalAudio(mute: state.isMuted);
      await _agora.toggleSpeakerphone(state.isSpeakerPhoneEnabled);
    } on DioException catch (e) {
      final msg = e.response?.data?['message'] as String? ?? e.message;
      emit(state.copyWith(
        status: AudioRoomStatus.error,
        errorMessage: msg,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: AudioRoomStatus.error,
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> leaveRoom() async {
    final id = _channelId;
    _channelId = null;
    // Notify the backend — fire-and-forget, don't block UI on failure.
    if (id != null) {
      appDio.post('/rooms/$id/leave').ignore();
    }
    await _agora.leaveChannel();
    await _sub?.cancel();
    _sub = null;
    emit(const AudioRoomState());
  }

  Future<void> toggleMic() async {
    final newMuted = !state.isMuted;
    await _agora.muteLocalAudio(mute: newMuted);
    emit(state.copyWith(isMuted: newMuted));
  }

  /// Switches audio output between speakerphone and earpiece.
  /// No-op if already in the requested mode.
  Future<void> setSpeakerphone(bool enabled) async {
    if (state.isSpeakerPhoneEnabled == enabled) return;
    await _agora.toggleSpeakerphone(enabled);
    emit(state.copyWith(isSpeakerPhoneEnabled: enabled));
  }

  void _onEvent(AgoraEvent event) {
    switch (event) {
      case AgoraJoinSuccess(:final uid):
        emit(state.copyWith(
          status: AudioRoomStatus.connected,
          localUid: uid,
        ));
      case AgoraUserJoined(:final uid):
        if (!state.remoteUids.contains(uid)) {
          emit(state.copyWith(remoteUids: [...state.remoteUids, uid]));
        }
      case AgoraUserOffline(:final uid):
        emit(state.copyWith(
          remoteUids: state.remoteUids.where((u) => u != uid).toList(),
        ));
      case AgoraLeftChannel():
        emit(const AudioRoomState());
      case AgoraError(:final code):
        emit(state.copyWith(
          status: AudioRoomStatus.error,
          errorMessage: code.name,
        ));
      case AgoraSpeakingUpdate():
        // Volume-indication speaking state is consumed by the live room view
        // (room_details_page.dart); this lightweight cubit ignores it.
        break;
      case AgoraMuteUpdate():
        // Remote mute state is consumed by the live room grid; not used here.
        break;
    }
  }

  @override
  Future<void> close() async {
    // Guard: if the page is disposed without an explicit leaveRoom() call
    // (e.g. OS kills the activity), still release the channel so Agora
    // billing stops and the remote participants see us as offline.
    if (state.status == AudioRoomStatus.connected ||
        state.status == AudioRoomStatus.connecting) {
      await _agora.leaveChannel();
    }
    await _sub?.cancel();
    await super.close();
  }
}

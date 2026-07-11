enum AudioRoomStatus { idle, connecting, connected, error, warning }

class AudioRoomState {
  final AudioRoomStatus status;
  final bool isMuted;
  final bool isSpeakerPhoneEnabled;
  final List<int> remoteUids;
  final int localUid;
  final String? errorMessage;

  const AudioRoomState({
    this.status = AudioRoomStatus.idle,
    this.isMuted = true,
    this.isSpeakerPhoneEnabled = true, // default: loud speaker for group rooms
    this.remoteUids = const [],
    this.localUid = 0,
    this.errorMessage,
  });

  AudioRoomState copyWith({
    AudioRoomStatus? status,
    bool? isMuted,
    bool? isSpeakerPhoneEnabled,
    List<int>? remoteUids,
    int? localUid,
    String? errorMessage,
    bool clearError = false,
  }) =>
      AudioRoomState(
        status: status ?? this.status,
        isMuted: isMuted ?? this.isMuted,
        isSpeakerPhoneEnabled:
            isSpeakerPhoneEnabled ?? this.isSpeakerPhoneEnabled,
        remoteUids: remoteUids ?? this.remoteUids,
        localUid: localUid ?? this.localUid,
        errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      );
}

// =============================================================================
// MUBTAATH — ROOM DETAILS PAGE  (v5 — unified grid, ghost mode, audio routing)
// =============================================================================
// Changes v5:
//   • Unified live grid shows everyone; moderators carry a "مشرف" badge.
//   • Ghost mode: eye toggle (moderators only) hides them from every grid via
//     POST /rooms/{id}/visibility + UserVisibilityChanged WS event.
//   • Grid tiles are tappable → dark options sheet (view profile / report).
//   • Audio route selector in the header (start-aligned: right in AR, left
//     in EN) switches Agora output between loudspeaker and earpiece.
//   • Attendees list now refreshes on join/leave WS events so the grid is
//     live, not a snapshot of the initial fetch.
// Changes v4:
//   • sendMessage payload now includes userId, username, role, timestamp.
//   • WS handler: ping/pong keepalive, MessageDeleted, UserKicked, UserBanned.
//   • RoomState: floatingEnabled toggle + pendingModeration side-effect field.
//   • _FloatingMessagePreview: listener-driven incoming message bubble.
//   • _ModerationDialog: kick/ban dialog that forces room exit on dismiss.
//   • _TikTokChatOverlay: floating-messages toggle row added above input.
// =============================================================================

import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:just_audio/just_audio.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mubtaath/core/bloc/room_status_cubit.dart';
import 'package:mubtaath/core/config/reverb_config.dart';
import 'package:mubtaath/core/l10n/app_localizations.dart';
import 'package:mubtaath/core/utils/debug_log.dart';
import 'package:mubtaath/core/services/floating_messages_setting.dart';
import 'package:mubtaath/core/services/dio_client.dart';
import 'package:mubtaath/core/theme/app_colors.dart';
import 'package:mubtaath/core/utils/avatar_utils.dart';
import 'package:mubtaath/core/widgets/mubtaath_loader.dart';
import 'package:mubtaath/features/reports/presentation/widgets/report_sheet.dart';
import 'package:mubtaath/features/reports/presentation/widgets/user_profile_sheet.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:mubtaath/core/services/agora_service.dart';

const _joiningRoomMessage = 'جاري الانضمام للغرفة، يرجى الانتظار...';
const _adminDeletedMessageText = 'تم حذف هذه الرسالة بواسطة الإدارة';
const _chatMutedByAdminMessage =
    'لقد تم حظرك من الكتابة في الشات بواسطة الإدارة';

/// Renders an avatar from either a bundled asset path (`assets/...`) or a remote
/// URL, falling back to [fallback] on an empty path or any load error.
/// Avatar ids resolve to local assets via [getAvatarPath]; using `Image.network`
/// on those paths fails, so the source must be detected before loading.
Widget _roomAvatarImage(
  String path, {
  required Widget fallback,
  BoxFit fit = BoxFit.cover,
}) {
  if (path.isEmpty) return fallback;
  if (path.startsWith('assets/')) {
    return Image.asset(path, fit: fit, errorBuilder: (_, __, ___) => fallback);
  }
  return Image.network(path, fit: fit, errorBuilder: (_, __, ___) => fallback);
}

/// First two letters for an avatar fallback: two initials from a two-word name,
/// otherwise the first two characters of a single word. Used for admins (who
/// have no photo) and any user whose avatar fails to load.
String avatarInitials(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((s) => s.isNotEmpty).toList();
  if (parts.isEmpty) return '؟';
  if (parts.length == 1) {
    final w = parts.first.characters;
    return w.take(2).toString();
  }
  return parts[0].characters.first + parts[1].characters.first;
}

/// Circular initials chip shown when a participant has no (loadable) photo.
Widget _initialsAvatar(
  String name, {
  required double diameter,
  required double fontSize,
  Color bg = const Color(0x1A305544), // primary @ 10%
  Color fg = AppColors.primary,
}) {
  return Container(
    width: diameter,
    height: diameter,
    alignment: Alignment.center,
    color: bg,
    child: Text(
      avatarInitials(name),
      style: TextStyle(
        fontFamily: 'Cairo',
        fontSize: fontSize,
        fontWeight: FontWeight.w800,
        color: fg,
      ),
    ),
  );
}

/// Avatar image that falls back to initials on an empty path or a load error
/// (remote URL or bundled asset), so admins and photo-less users still read as
/// a named circle instead of a generic glyph.
Widget _avatarWithInitials(
  String path,
  String name, {
  required double diameter,
  required double fontSize,
  Color bg = const Color(0x1A305544),
  Color fg = AppColors.primary,
}) {
  final fallback = _initialsAvatar(
    name,
    diameter: diameter,
    fontSize: fontSize,
    bg: bg,
    fg: fg,
  );
  if (path.isEmpty) return fallback;
  if (path.startsWith('assets/')) {
    return Image.asset(path,
        width: diameter,
        height: diameter,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => fallback);
  }
  return Image.network(path,
      width: diameter,
      height: diameter,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => fallback);
}

// =============================================================================
// SECTION 1 — DATA MODELS
// =============================================================================
enum ParticipantRole { host, speaker, listener }

class ParticipantModel {
  final String id;
  final String name;
  final String avatarUrl;
  final ParticipantRole role;
  final bool isSpeaking;
  final bool isMuted;

  /// Admin/Moderator flag — these users carry the "مشرف" badge on their
  /// grid tile. Derived from the raw backend role string so every elevated
  /// role variant (host / admin / moderator / supervisor) is covered.
  final bool isModerator;

  /// Server-side invisibility flag (`is_invisible` / `is_hidden`) for elevated
  /// users. Invisible admins/moderators are removed from grids and visible
  /// listener counts without leaving the audio channel.
  final bool isInvisible;

  const ParticipantModel({
    required this.id,
    required this.name,
    required this.avatarUrl,
    required this.role,
    this.isSpeaking = false,
    this.isMuted = false,
    this.isModerator = false,
    this.isInvisible = false,
  });

  /// True when the user holds active publishing privileges (host/speaker).
  /// The UI shows a subtle mic badge for these users; everyone else renders
  /// identically — there is no separate "listeners" section anymore.
  bool get isBroadcaster =>
      role == ParticipantRole.host || role == ParticipantRole.speaker;

  ParticipantModel copyWith({bool? isMuted, bool? isInvisible, bool? isSpeaking}) =>
      ParticipantModel(
        id: id,
        name: name,
        avatarUrl: avatarUrl,
        role: role,
        isSpeaking: isSpeaking ?? this.isSpeaking,
        isMuted: isMuted ?? this.isMuted,
        isModerator: isModerator,
        isInvisible: isInvisible ?? this.isInvisible,
      );

  factory ParticipantModel.fromJson(Map<String, dynamic> j) {
    final rawRole = j['role'] as String?;
    return ParticipantModel(
      id: j['id'] as String? ?? '',
      name: j['name'] as String? ?? '',
      avatarUrl: j['avatarUrl'] as String? ?? '',
      role: _parseRole(rawRole),
      isSpeaking: j['isSpeaking'] as bool? ?? false,
      isMuted: j['isMuted'] as bool? ?? false,
      isModerator: _isElevated(rawRole),
      isInvisible: j['is_invisible'] as bool? ??
          j['isInvisible'] as bool? ??
          j['is_hidden'] as bool? ??
          j['isHidden'] as bool? ??
          false,
    );
  }

  static ParticipantRole _parseRole(String? raw) => switch (raw) {
        'host' ||
        'admin' ||
        'moderator' ||
        'supervisor' =>
          ParticipantRole.host,
        'speaker' => ParticipantRole.speaker,
        _ => ParticipantRole.listener,
      };

  static bool _isElevated(String? raw) =>
      raw == 'host' ||
      raw == 'admin' ||
      raw == 'moderator' ||
      raw == 'supervisor';
}

class ChatMessage {
  final String id;
  final String userId;
  final String senderName;
  final String senderAvatar;
  final String senderRole; // 'admin' | 'supervisor' | 'user'
  final String text;
  final DateTime sentAt;
  final bool isSending; // true while waiting for server confirmation
  final bool isDeleted;

  const ChatMessage({
    required this.id,
    required this.userId,
    required this.senderName,
    required this.senderAvatar,
    required this.senderRole,
    required this.text,
    required this.sentAt,
    this.isSending = false,
    this.isDeleted = false,
  });

  ChatMessage copyWith({
    String? text,
    bool? isSending,
    bool? isDeleted,
  }) =>
      ChatMessage(
        id: id,
        userId: userId,
        senderName: senderName,
        senderAvatar: senderAvatar,
        senderRole: senderRole,
        text: text ?? this.text,
        sentAt: sentAt,
        isSending: isSending ?? this.isSending,
        isDeleted: isDeleted ?? this.isDeleted,
      );

  factory ChatMessage.fromJson(Map<String, dynamic> j) {
    final avatarUrl = j['avatarUrl'] as String? ?? '';
    final avatarId = (j['avatarId'] as num?)?.toInt() ?? 1;
    final isDeleted = j['isDeleted'] as bool? ??
        j['is_deleted'] as bool? ??
        (j['deletedAt'] != null);
    return ChatMessage(
      id: j['id'] as String? ?? '',
      userId: j['userId'] as String? ?? '',
      senderName: j['senderName'] as String? ?? '',
      senderAvatar: avatarUrl.isNotEmpty ? avatarUrl : getAvatarPath(avatarId),
      senderRole: (j['isAdminMessage'] as bool? ?? false)
          ? 'admin'
          : (j['role'] as String? ?? 'user'),
      text: isDeleted
          ? _adminDeletedMessageText
          : (j['message'] as String? ?? ''),
      sentAt: DateTime.tryParse(j['sentAt'] as String? ?? '') ?? DateTime.now(),
      isDeleted: isDeleted,
    );
  }
}

class RoomDetailModel {
  final String id;
  final String title;
  final String description;
  final String coverImageUrl;
  final int listenerCount;

  /// Unified attendees list — hosts, speakers AND listeners together.
  /// The backend keeps the JSON key 'speakers' for backward compatibility,
  /// but it now carries every active participant with their role intact.
  final List<ParticipantModel> attendees;

  /// Moderators currently in ghost mode (server-persisted). Seeds the local
  /// hidden set so clients that join AFTER the toggle still hide them;
  /// live changes arrive via the UserVisibilityChanged WS event.
  final Set<String> hiddenUserIds;
  final List<String> tags;
  final String category;

  /// Live in-room background. type ∈ {none, url, file}; backgroundUrl is the
  /// resolved source (empty when type == 'none'). Rendered ONLY inside the live
  /// room — kept strictly separate from the external banner/cover below.
  final String backgroundType;
  final String backgroundUrl;

  /// External banner / cover image — the room's header/cover art. The backend
  /// already folds it into [coverImageUrl] for backward compatibility, but the
  /// raw fields are exposed here too for explicit use.
  final String bannerType;
  final String bannerUrl;

  const RoomDetailModel({
    required this.id,
    required this.title,
    required this.description,
    required this.coverImageUrl,
    required this.listenerCount,
    required this.attendees,
    this.hiddenUserIds = const {},
    this.tags = const [],
    this.category = '',
    this.backgroundType = 'none',
    this.backgroundUrl = '',
    this.bannerType = 'none',
    this.bannerUrl = '',
  });

  /// True when a live in-room background image should be rendered (url/file with
  /// a non-empty source). 'none' — or a missing source — falls back to the flat
  /// brand-green backdrop.
  bool get hasBackgroundImage =>
      backgroundType != 'none' && backgroundUrl.isNotEmpty;

  /// The header/cover image to show pre-join: the dedicated banner when set,
  /// otherwise the legacy cover image url.
  String get headerImageUrl => bannerUrl.isNotEmpty ? bannerUrl : coverImageUrl;

  factory RoomDetailModel.fromJson(Map<String, dynamic> j) => RoomDetailModel(
        id: j['id'] as String? ?? '',
        title: j['title'] as String? ?? j['titleEn'] as String? ?? '',
        description: j['description'] as String? ?? '',
        coverImageUrl: j['coverImageUrl'] as String? ?? '',
        listenerCount: j['listenerCount'] as int? ?? 0,
        attendees: (j['speakers'] as List<dynamic>? ?? [])
            .map((e) => ParticipantModel.fromJson(e as Map<String, dynamic>))
            .toList(),
        hiddenUserIds: (j['hiddenUserIds'] as List<dynamic>? ?? [])
            .map((e) => e.toString())
            .toSet(),
        tags: (j['tags'] as List<dynamic>? ?? []).cast<String>(),
        category: j['category'] as String? ?? '',
        backgroundType: j['backgroundType'] as String? ?? 'none',
        backgroundUrl: j['backgroundUrl'] as String? ?? '',
        bannerType: j['bannerType'] as String? ?? 'none',
        bannerUrl: j['bannerUrl'] as String? ?? '',
      );
}

// ── Moderation side-effect events ──────────────────────────────────────────
// Carried on RoomState.pendingModeration; cleared immediately after the
// BlocListener consumes them so the dialog is never shown more than once.
sealed class ModerationEvent {
  const ModerationEvent();
}

final class KickEvent extends ModerationEvent {
  final String reason;
  const KickEvent({this.reason = ''});
}

final class TempBanEvent extends ModerationEvent {
  final String reason;
  final int durationMinutes;
  const TempBanEvent({this.reason = '', this.durationMinutes = 60});
}

final class GlobalBanEvent extends ModerationEvent {
  final String reason;
  const GlobalBanEvent({this.reason = ''});
}

/// The whole room was closed by an admin — every client is evicted, not just
/// one moderated user.
final class RoomClosedEvent extends ModerationEvent {
  const RoomClosedEvent();
}

// =============================================================================
// SECTION 2 — STATE
// =============================================================================
enum RoomView { detail, live }

class RoomState {
  final RoomView view;
  final bool isMuted;
  final bool chatVisible;
  final bool floatingEnabled;
  final List<ChatMessage> messages;

  /// Unread chat messages received while the chat sheet was closed.
  /// Reset to 0 the moment the sheet opens. Badge renders ONLY when > 0.
  final int unreadCount;
  final List<ParticipantModel> attendees;
  final RoomDetailModel? roomDetail;
  final bool isLoading;
  final bool hasError;
  final ModerationEvent? pendingModeration;
  final int participantCount;
  final bool isConnectingAudio;
  final String? audioErrorMessage;

  /// Moderator "ghost mode" — when ON the local moderator's tile is removed
  /// from the grid (here and, via the WS broadcast, on every other client)
  /// while they stay connected to the audio channel.
  final bool isGhostMode;

  /// User IDs hidden from the grid because their owners enabled ghost mode
  /// (received via the UserVisibilityChanged WS event).
  final Set<String> hiddenUserIds;

  /// Audio output route — true = loudspeaker, false = earpiece.
  /// Live-broadcast channels default to the loudspeaker on mobile.
  final bool isSpeakerphoneOn;

  /// One-shot signal: set when a room-entry attempt was rejected (e.g. the
  /// room is full). The root BlocListener shows a toast and pops back to the
  /// dashboard, then clears it via [RoomCubit.clearEntryDenied].
  final String? entryDeniedMessage;

  /// Whether this client is currently blocked from sending room chat messages.
  final bool isChatMuted;

  /// One-shot chat/moderation notice rendered as a snackbar by the root page.
  final String? chatNoticeMessage;

  const RoomState({
    this.view = RoomView.detail,
    this.isMuted = true,
    this.chatVisible = false,
    // Default ON: incoming messages surface as auto-dismissing preview
    // bubbles whenever the chat sheet is closed. The in-sheet switch lets
    // users opt out.
    this.floatingEnabled = true,
    this.messages = const [],
    this.unreadCount = 0,
    this.attendees = const [],
    this.roomDetail,
    this.isLoading = true,
    this.hasError = false,
    this.pendingModeration,
    this.participantCount = 0,
    this.isConnectingAudio = false,
    this.audioErrorMessage,
    this.isGhostMode = false,
    this.hiddenUserIds = const {},
    this.isSpeakerphoneOn = true,
    this.entryDeniedMessage,
    this.isChatMuted = false,
    this.chatNoticeMessage,
  });

  RoomState copyWith({
    RoomView? view,
    bool? isMuted,
    bool? chatVisible,
    bool? floatingEnabled,
    List<ChatMessage>? messages,
    int? unreadCount,
    List<ParticipantModel>? attendees,
    RoomDetailModel? roomDetail,
    bool? isLoading,
    bool? hasError,
    int? participantCount,
    bool? isConnectingAudio,
    String? audioErrorMessage,
    bool? isGhostMode,
    Set<String>? hiddenUserIds,
    bool? isSpeakerphoneOn,
    bool? isChatMuted,
    // Use Object? sentinel so callers can explicitly set these to null.
    Object? pendingModeration = _keep,
    Object? entryDeniedMessage = _keep,
    Object? chatNoticeMessage = _keep,
  }) =>
      RoomState(
        view: view ?? this.view,
        isMuted: isMuted ?? this.isMuted,
        chatVisible: chatVisible ?? this.chatVisible,
        floatingEnabled: floatingEnabled ?? this.floatingEnabled,
        messages: messages ?? this.messages,
        unreadCount: unreadCount ?? this.unreadCount,
        attendees: attendees ?? this.attendees,
        roomDetail: roomDetail ?? this.roomDetail,
        isLoading: isLoading ?? this.isLoading,
        hasError: hasError ?? this.hasError,
        participantCount: participantCount ?? this.participantCount,
        isConnectingAudio: isConnectingAudio ?? this.isConnectingAudio,
        audioErrorMessage: audioErrorMessage ?? this.audioErrorMessage,
        isGhostMode: isGhostMode ?? this.isGhostMode,
        hiddenUserIds: hiddenUserIds ?? this.hiddenUserIds,
        isSpeakerphoneOn: isSpeakerphoneOn ?? this.isSpeakerphoneOn,
        isChatMuted: isChatMuted ?? this.isChatMuted,
        pendingModeration: pendingModeration == _keep
            ? this.pendingModeration
            : pendingModeration as ModerationEvent?,
        entryDeniedMessage: entryDeniedMessage == _keep
            ? this.entryDeniedMessage
            : entryDeniedMessage as String?,
        chatNoticeMessage: chatNoticeMessage == _keep
            ? this.chatNoticeMessage
            : chatNoticeMessage as String?,
      );

  /// Attendees actually rendered in the grid — strips everyone whose ghost
  /// mode is ON. [currentUserId] removes the local moderator's own tile
  /// immediately (optimistic), without waiting for the WS round-trip.
  List<ParticipantModel> visibleAttendees(String currentUserId) =>
      attendees.where((p) {
        if (hiddenUserIds.contains(p.id)) return false;
        if (isGhostMode && p.id == currentUserId) return false;
        if (p.isInvisible) return false;
        return true;
      }).toList();

  /// Number of ghost-moded users to subtract from the displayed headcount,
  /// so a hidden moderator reads as having left the room entirely.
  ///
  /// A Set merges the local optimistic flag with the WS-broadcast id (the
  /// moderator's own UserVisibilityChanged echoes back), so the same person
  /// is never subtracted twice. When the attendee list is loaded, only ids
  /// actually present in the room are counted — a stale hidden id from
  /// someone who already left can't drag the count negative.
  int hiddenPresenceCount(String currentUserId) {
    final hidden = Set<String>.from(hiddenUserIds);
    if (isGhostMode) hidden.add(currentUserId);
    hidden.addAll(attendees.where((p) => p.isInvisible).map((p) => p.id));
    if (hidden.isEmpty) return 0;
    if (attendees.isNotEmpty) {
      final present = attendees.map((p) => p.id).toSet();
      hidden.retainAll(present);
    }
    return hidden.length;
  }

  /// Headcount shown in the live room: live WS count minus hidden moderators.
  int displayCount(int baseCount, String currentUserId) =>
      (baseCount - hiddenPresenceCount(currentUserId)).clamp(0, 999999);
}

// Sentinel value so copyWith can distinguish "not passed" from "pass null".
const _keep = Object();

// =============================================================================
// SECTION 3 — CUBIT
// =============================================================================
class RoomCubit extends Cubit<RoomState> {
  final String _roomId;
  final RoomStatusCubit? _statusCubit;
  WebSocketChannel? _ws;
  StreamSubscription<dynamic>? _wsSub;
  StreamSubscription<AgoraEvent>? _agoraSub;
  Timer? _reconnectTimer;
  String? _socketId;
  Timer? _heartbeatTimer;
  Timer? _attendeeRefreshTimer;
  // Set to true by _onWsDone/_onWsError when we drop from live view,
  // so pusher:subscription_succeeded knows to re-announce presence.
  bool _wasLiveOnDisconnect = false;

  // Short mute/unmute confirmation tones — fire-and-forget, never blocks
  // the actual mic toggle if playback fails.
  final AudioPlayer _sfxPlayer = AudioPlayer();

  // Current-user identity — fetched from GET /auth/me during _init().
  // Drives own-message alignment, self-detection in profile sheets, and the
  // moderator-only ghost-mode toggle.
  String _userId = '';
  String _username = '';
  String _userRole = 'user';

  RoomCubit({required String roomId, RoomStatusCubit? statusCubit})
      : _roomId = roomId,
        _statusCubit = statusCubit,
        super(const RoomState()) {
    _init();
  }

  Future<void> _init() async {
    // Floating-messages preference now lives in app Settings, not the chat sheet.
    final floating = await FloatingMessagesSetting.get();
    if (!isClosed) emit(state.copyWith(floatingEnabled: floating));
    await _readCurrentUser();
    await _loadRoom();
    await _loadMessages(); // history first — WS appends only newer events
    _connectWs();
  }

  // ── Read authenticated user info from GET /auth/me ─────────────────────────
  // The login flow persists only the auth token, so the live room resolves the
  // current user's id/role from the API. Without this, own messages never align
  // correctly, tapping your own tile opens the report sheet, and the moderator
  // ghost-mode toggle never appears.
  Future<void> _readCurrentUser() async {
    try {
      final resp = await appDio.get('/auth/me');
      final user = resp.data['data'] as Map<String, dynamic>;
      _userId = user['id']?.toString() ?? '';
      final username = (user['username'] as String?)?.trim() ?? '';
      _userRole = (user['role'] as String?)?.trim().isNotEmpty == true
          ? user['role'] as String
          : 'user';
      _username =
          username.isNotEmpty ? username : (user['fullName'] as String? ?? '');
    } catch (e) {
      logDebug('[RoomCubit] readCurrentUser error: $e');
    }
  }

  // ── Fetch room details ─────────────────────────────────────────────────────
  Future<void> _loadRoom() async {
    try {
      final resp = await appDio.get('/rooms/$_roomId');
      final data = resp.data['data'] as Map<String, dynamic>;
      final room = RoomDetailModel.fromJson(data);
      final rawCount = _rawParticipantCount(room);
      final next = state.copyWith(
        roomDetail: room,
        attendees: room.attendees,
        hiddenUserIds: room.hiddenUserIds,
        participantCount: rawCount,
        isLoading: false,
      );
      emit(next);
      _publishVisibleCount(next, rawCount);
    } catch (e) {
      logDebug('[RoomCubit] loadRoom error: $e');
      emit(state.copyWith(isLoading: false, hasError: true));
    }
  }

  int _rawParticipantCount(RoomDetailModel room) {
    final hiddenPresent = <String>{
      ...room.hiddenUserIds,
      ...room.attendees.where((p) => p.isInvisible).map((p) => p.id),
    }..retainAll(room.attendees.map((p) => p.id).toSet());

    return room.listenerCount + hiddenPresent.length;
  }

  void _publishVisibleCount(RoomState next, int rawCount) {
    _statusCubit?.updateCount(
      _roomId,
      next.displayCount(rawCount, _userId),
    );
  }

  // ── Fetch message history ──────────────────────────────────────────────────
  // Called once before the WS connects so the chat is populated immediately,
  // and again after every WS reconnect to back-fill messages broadcast while
  // the socket was down. The server list is authoritative; locally-optimistic
  // (still-sending) messages are re-appended so they don't vanish mid-flight.
  Future<void> _loadMessages() async {
    try {
      final resp = await appDio.get('/rooms/$_roomId/messages');
      final raw = resp.data['data'];
      final list = raw is List ? raw : <dynamic>[];
      final fetched = list
          .map((e) => ChatMessage.fromJson(e as Map<String, dynamic>))
          .toList();
      if (isClosed) return;
      final pending = state.messages.where((m) => m.isSending).toList();
      emit(state.copyWith(messages: [...fetched, ...pending]));
    } catch (e) {
      logDebug('[RoomCubit] loadMessages error: $e');
    }
  }

  // ── Open Pusher-protocol WebSocket to Reverb ───────────────────────────────
  void _connectWs() {
    try {
      _ws = WebSocketChannel.connect(Uri.parse(ReverbConfig.wsUrl));
      _wsSub = _ws!.stream.listen(
        _onWsMessage,
        onError: _onWsError,
        onDone: _onWsDone,
        cancelOnError: false,
      );
    } catch (e) {
      logDebug('[RoomCubit] WS connect error: $e');
      _scheduleReconnect();
    }
  }

  void _onWsDone() {
    if (!isClosed) {
      logDebug('[RoomCubit] WS connection closed — reconnecting');
      // Remember we were live so pusher:subscription_succeeded re-announces
      // presence once the socket is back. Do NOT tell the backend we left: a
      // transient WebSocket drop must never mark a still-connected user as gone
      // while they remain in the Agora channel. That auto-leave is the ghost-
      // disconnection bug, and it evicts the long-lived host first (turning the
      // moderator into an "eternal ghost"). Presence is kept alive by the
      // periodic heartbeat; only an explicit Leave/Back tap ends the session.
      _wasLiveOnDisconnect = state.view == RoomView.live;
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 4), () {
      if (isClosed) return;
      _wsSub?.cancel();
      _ws?.sink.close();
      _socketId = null;
      _connectWs();
    });
  }

  void _onWsMessage(dynamic raw) async {
    Map<String, dynamic> payload;
    try {
      payload = jsonDecode(raw as String) as Map<String, dynamic>;
    } catch (_) {
      return;
    }

    final event = payload['event'] as String? ?? '';

    switch (event) {
      // ── Protocol ───────────────────────────────────────────────────────────
      case 'pusher:connection_established':
        final inner =
            jsonDecode(payload['data'] as String) as Map<String, dynamic>;
        _socketId = inner['socket_id'] as String?;
        if (_socketId != null) await _subscribeToChannel();

      // Keep-alive: server pings every ~30 s; we must reply or get dropped.
      case 'pusher:ping':
        _ws?.sink.add(jsonEncode({'event': 'pusher:pong', 'data': {}}));

      // ── Chat messages ──────────────────────────────────────────────────────
      // Handles both custom broadcastAs() name and the Laravel default
      // full-class-name format (App\Events\MessageSent).
      case 'MessageSent':
      case 'App\\Events\\MessageSent':
        if (payload['channel'] != 'private-rooms.$_roomId' || isClosed) return;
        final data = _decodeData(payload['data']);
        final confirmed = ChatMessage.fromJson(data);
        // Skip if the confirmed message is already in the list by ID
        // (prevents doubles after a WS reconnect that replays recent events).
        if (state.messages.any((m) => !m.isSending && m.id == confirmed.id)) {
          return;
        }
        // Remove optimistic placeholder (same sender + text, isSending == true).
        final deduped = state.messages
            .where((m) => !(m.isSending &&
                m.userId == confirmed.userId &&
                m.text == confirmed.text))
            .toList();
        // Unread tracking: messages from OTHERS arriving while the chat sheet
        // is closed bump the badge. Own messages and open-sheet arrivals don't.
        final isUnread = !state.chatVisible && confirmed.userId != _userId;
        emit(state.copyWith(
          messages: [...deduped, confirmed],
          unreadCount: isUnread ? state.unreadCount + 1 : state.unreadCount,
        ));

      // ── Participant count ──────────────────────────────────────────────────
      case 'ParticipantUpdated':
      case 'App\\Events\\ParticipantUpdated':
        if (payload['channel'] != 'private-rooms.$_roomId' || isClosed) return;
        final data = _decodeData(payload['data']);
        final count = (data['count'] as num?)?.toInt();
        if (count != null) {
          final next = state.copyWith(participantCount: count);
          emit(next);
          _publishVisibleCount(next, count);
        }
        _scheduleAttendeeRefresh();

      // ── Moderator ghost-mode visibility ────────────────────────────────────
      case 'UserVisibilityChanged':
      case 'App\\Events\\UserVisibilityChanged':
        if (payload['channel'] != 'private-rooms.$_roomId' || isClosed) return;
        final vData = _decodeData(payload['data']);
        final vUserId = vData['userId']?.toString() ?? '';
        final vHidden = vData['hidden'] as bool? ?? false;
        if (vUserId.isEmpty) return;
        final hidden = Set<String>.from(state.hiddenUserIds);
        vHidden ? hidden.add(vUserId) : hidden.remove(vUserId);
        final next = state.copyWith(hiddenUserIds: hidden);
        emit(next);
        _publishVisibleCount(next, next.participantCount);

      // ── Moderation: message deletion ───────────────────────────────────────
      case 'MessageDeleted':
      case 'App\\Events\\MessageDeleted':
        if (payload['channel'] != 'private-rooms.$_roomId' || isClosed) return;
        final data = _decodeData(payload['data']);
        final deletedId =
            data['id'] as String? ?? data['messageId'] as String? ?? '';
        if (deletedId.isEmpty) return;
        _markMessageDeleted(deletedId);

      // ── Moderation: chat mute notice ─────────────────────────────────────
      case 'UserChatMuted':
      case 'App\\Events\\UserChatMuted':
        if (payload['channel'] != 'private-rooms.$_roomId' || isClosed) return;
        final data = _decodeData(payload['data']);
        final targetId = data['userId']?.toString() ?? '';
        // Act ONLY when the event explicitly targets THIS client. Never fall
        // through on an empty/absent id — that would evict/mute EVERYONE in the
        // room instead of just the moderated user.
        if (targetId != _userId) return;
        emit(state.copyWith(
          isChatMuted: true,
          chatNoticeMessage:
              data['message'] as String? ?? _chatMutedByAdminMessage,
        ));

      // ── Moderation: user kick ──────────────────────────────────────────────
      case 'UserKicked':
      case 'kick':
        if (payload['channel'] != 'private-rooms.$_roomId' || isClosed) return;
        final data = _decodeData(payload['data']);
        final targetId = data['userId'] as String? ?? '';
        // Act ONLY when the event explicitly targets THIS client. Never fall
        // through on an empty/absent id — that would evict/mute EVERYONE in the
        // room instead of just the moderated user.
        if (targetId != _userId) return; // not for us
        await _evictFromRoom();
        if (isClosed) return;
        emit(state.copyWith(
          pendingModeration: KickEvent(
            reason: data['reason'] as String? ?? '',
          ),
        ));

      // ── Moderation: temporary ban ──────────────────────────────────────────
      case 'UserBanned':
      case 'temporary_ban':
        if (payload['channel'] != 'private-rooms.$_roomId' || isClosed) return;
        final data = _decodeData(payload['data']);
        final targetId = data['userId'] as String? ?? '';
        // Act ONLY when the event explicitly targets THIS client. Never fall
        // through on an empty/absent id — that would evict/mute EVERYONE in the
        // room instead of just the moderated user.
        if (targetId != _userId) return;
        await _evictFromRoom();
        if (isClosed) return;
        emit(state.copyWith(
          pendingModeration: TempBanEvent(
            reason: data['reason'] as String? ?? '',
            durationMinutes: (data['duration_minutes'] as num?)?.toInt() ?? 60,
          ),
        ));

      case 'GlobalBan':
      case 'App\\Events\\UserGloballyBanned':
        if (payload['channel'] != 'private-rooms.$_roomId' || isClosed) return;
        final data = _decodeData(payload['data']);
        final targetId = data['userId']?.toString() ?? '';
        // Act ONLY when the event explicitly targets THIS client. Never fall
        // through on an empty/absent id — that would evict/mute EVERYONE in the
        // room instead of just the moderated user.
        if (targetId != _userId) return;
        await _evictFromRoom();
        if (isClosed) return;
        emit(state.copyWith(
          pendingModeration: GlobalBanEvent(
            reason: data['message'] as String? ?? '',
          ),
        ));

      // ── Room closed by admin — evict EVERYONE (no per-user target) ─────────
      case 'RoomClosed':
      case 'App\\Events\\RoomClosed':
        if (payload['channel'] != 'private-rooms.$_roomId' || isClosed) return;
        await _evictFromRoom();
        if (isClosed) return;
        emit(state.copyWith(pendingModeration: const RoomClosedEvent()));

      // ── Participant join / leave (incremental) ─────────────────────────────
      // Backend can broadcast either the new absolute count in `count`, or we
      // fall back to ±1 so the UI is never stale even without a count field.
      case 'UserJoined':
      case 'App\\Events\\UserJoined':
        if (payload['channel'] != 'private-rooms.$_roomId' || isClosed) return;
        final jData = _decodeData(payload['data']);
        final jCount =
            (jData['count'] as num?)?.toInt() ?? (state.participantCount + 1);
        final next = state.copyWith(participantCount: jCount);
        emit(next);
        _publishVisibleCount(next, jCount);
        _scheduleAttendeeRefresh();

      case 'UserLeft':
      case 'App\\Events\\UserLeft':
        if (payload['channel'] != 'private-rooms.$_roomId' || isClosed) return;
        final lData = _decodeData(payload['data']);
        final lCount = (lData['count'] as num?)?.toInt() ??
            (state.participantCount - 1).clamp(0, 999999);
        final next = state.copyWith(participantCount: lCount);
        emit(next);
        _publishVisibleCount(next, lCount);
        _scheduleAttendeeRefresh();

      // ── Subscription lifecycle ─────────────────────────────────────────────
      case 'pusher:subscription_succeeded':
        final succCh = payload['channel'] as String? ?? '';
        if (succCh != 'private-rooms.$_roomId') return;
        logDebug('[RoomCubit] ✓ Subscribed to $succCh');
        // Only re-announce presence after a reconnect drop, not on first load.
        if (_wasLiveOnDisconnect) {
          _wasLiveOnDisconnect = false;
          _notifyJoin();
          // Back-fill anything broadcast while the socket was down.
          _loadMessages();
          _scheduleAttendeeRefresh();
        }

      case 'pusher:subscription_error':
        logDebug('[RoomCubit] Subscription error: ${payload['data']}');
        // Back-off 3 s and retry — socket_id is still valid after auth failure.
        Timer(const Duration(seconds: 3), () {
          if (!isClosed && _socketId != null) _subscribeToChannel();
        });
    }
  }

  // Pusher double-encodes the inner data as a JSON string — decode it once more.
  Map<String, dynamic> _decodeData(dynamic raw) {
    if (raw is String) {
      return jsonDecode(raw) as Map<String, dynamic>;
    }
    return raw as Map<String, dynamic>? ?? {};
  }

  // ── Subscribe to private-rooms.{roomId} ───────────────────────────────────
  Future<void> _subscribeToChannel() async {
    final ch = 'private-rooms.$_roomId';
    try {
      final baseUrl = appDio.options.baseUrl;
      final rootUrl = baseUrl.endsWith('/api')
          ? baseUrl.substring(0, baseUrl.length - 4)
          : baseUrl;
      final resp = await appDio.post(
        '$rootUrl/broadcasting/auth',
        data: {'socket_id': _socketId, 'channel_name': ch},
      );
      final auth = resp.data['auth'] as String;
      _ws!.sink.add(jsonEncode({
        'event': 'pusher:subscribe',
        'data': {'auth': auth, 'channel': ch},
      }));
    } catch (e) {
      logDebug('[RoomCubit] WS subscribe error: $e');
    }
  }

  void _onWsError(dynamic error) {
    logDebug('[RoomCubit] WS error: $error');
    // See _onWsDone: a transient socket error must never auto-leave the room
    // while the user is still in the Agora channel. Flag for presence
    // re-announce and reconnect — never notify the backend of a leave here.
    _wasLiveOnDisconnect = state.view == RoomView.live;
    _scheduleReconnect();
  }

  // ── Heartbeat ──────────────────────────────────────────────────────────────
  // Pings /rooms/{id}/heartbeat every 8 s while in live view.
  // Backend must expire users whose last heartbeat is >10 s old and broadcast
  // ParticipantUpdated — this is the server-side half of ghost-presence fix.
  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 8), (_) async {
      if (isClosed || state.view != RoomView.live) return;
      try {
        // appDio injects the Sanctum bearer token on every request, so a
        // healthy session returns 200 and keeps last_seen_at fresh (which is
        // what prevents another client's heartbeat sweep from evicting us).
        await appDio.post('/rooms/$_roomId/heartbeat');
      } on DioException catch (e) {
        // A 401 means the backend genuinely invalidated the session. Tear down
        // the Agora channel immediately so the user is never left as a silent
        // audio ghost; the global Dio 401 handler clears the token and routes
        // back out of the room. Every other failure (timeout / 5xx / the
        // controller's 422) is transient — never auto-leave on those; the next
        // tick simply retries and the user stays in the room.
        if (e.response?.statusCode == 401) {
          _stopHeartbeat();
          await AgoraService.instance.leaveChannel();
        }
      } catch (_) {
        // Heartbeat must never crash the room.
      }
    });
  }

  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  // ── Live attendee-list refresh ─────────────────────────────────────────────
  // Join/leave WS events only carry counts, so the grid re-fetches the room to
  // get the actual participant list. Debounced 800 ms — a burst of events
  // (e.g. heartbeat evictions) triggers a single request.
  void _scheduleAttendeeRefresh() {
    _attendeeRefreshTimer?.cancel();
    _attendeeRefreshTimer = Timer(const Duration(milliseconds: 800), () async {
      if (isClosed) return;
      try {
        final resp = await appDio.get('/rooms/$_roomId');
        final data = resp.data['data'] as Map<String, dynamic>;
        final room = RoomDetailModel.fromJson(data);
        if (!isClosed) {
          // Server-persisted hidden set is authoritative on refresh; the
          // local moderator's own toggle stays covered by isGhostMode.
          final rawCount = _rawParticipantCount(room);
          final next = state.copyWith(
            attendees: room.attendees,
            hiddenUserIds: room.hiddenUserIds,
            participantCount: rawCount,
          );
          emit(next);
          _publishVisibleCount(next, rawCount);
        }
      } catch (e) {
        logDebug('[RoomCubit] attendee refresh error: $e');
      }
    });
  }

  // ── Optimistic-message safety net ─────────────────────────────────────────
  // If the WS confirmation never arrives (lost packet / broken subscription),
  // drop the isSending spinner after 5 s so the message never appears frozen.
  void _scheduleOptimisticTimeout(String tempId) {
    Timer(const Duration(seconds: 5), () {
      if (isClosed) return;
      final idx =
          state.messages.indexWhere((m) => m.id == tempId && m.isSending);
      if (idx == -1) return; // already confirmed or rolled back
      final updated = List<ChatMessage>.from(state.messages);
      final m = updated[idx];
      updated[idx] = ChatMessage(
        id: m.id,
        userId: m.userId,
        senderName: m.senderName,
        senderAvatar: m.senderAvatar,
        senderRole: m.senderRole,
        text: m.text,
        sentAt: m.sentAt,
        isSending: false,
      );
      emit(state.copyWith(messages: updated));
    });
  }

  void _markMessageDeleted(String messageId) {
    final updated = state.messages.map((m) {
      if (m.id != messageId) return m;
      return m.copyWith(
        text: _adminDeletedMessageText,
        isDeleted: true,
        isSending: false,
      );
    }).toList();
    emit(state.copyWith(messages: updated));
  }

  bool _isIgnorableAgoraCode(int code) => code == 0 || code == 3 || code == -3;

  bool _isIgnorableAgoraErrorCode(ErrorCodeType code) {
    return code == ErrorCodeType.errOk ||
        code == ErrorCodeType.errNotReady ||
        _isIgnorableAgoraCode(code.value());
  }

  bool _isIgnorableAgoraJoinIssue(Object error) {
    if (error is AgoraRtcException) {
      return _isIgnorableAgoraCode(error.code);
    }

    final text = error.toString();
    final match = RegExp(r'AgoraRtcException\((-?\d+)').firstMatch(text) ??
        RegExp(r'(?:code|errCode|errorCode)\D*(-?\d+)').firstMatch(text);
    final parsedCode = match == null ? null : int.tryParse(match.group(1)!);

    return parsedCode != null && _isIgnorableAgoraCode(parsedCode);
  }

  void _finishRoomEntry({String? debugReason}) {
    if (debugReason != null) {
      logDebug('[RoomCubit] joinRoom() — continuing after $debugReason.');
    }

    emit(state.copyWith(
      view: RoomView.live,
      isConnectingAudio: false,
      audioErrorMessage: null,
    ));

    _startHeartbeat();
    _scheduleAttendeeRefresh();
  }

  // ── Public actions ─────────────────────────────────────────────────────────
  Future<void> joinRoom() async {
    logDebug('[RoomCubit] joinRoom() — START. roomId=$_roomId');

    // 1. Request microphone permission
    final permStatus = await Permission.microphone.request();
    logDebug('[RoomCubit] joinRoom() — mic permission: ${permStatus.name}');
    if (!permStatus.isGranted) {
      emit(state.copyWith(
        audioErrorMessage: 'Microphone permission denied',
      ));
      return;
    }

    // 2. Emit connecting state → root UI shows the global joining dialog.
    // Keep the detail view underneath until audio entry succeeds.
    emit(state.copyWith(
      isConnectingAudio: true,
      audioErrorMessage: null,
    ));

    try {
      // 3. Notify backend FIRST and let a rejection throw — the capacity guard
      //    lives here, so a full room 403s before any Agora resources spin up.
      await _notifyJoinOrThrow();

      // 4. Fetch Agora token from backend.
      //    role:1 = broadcaster. This is an "everyone can talk" room model —
      //    every participant joins as a broadcaster (publishMicrophoneTrack)
      //    and their mute state controls whether they actually transmit. If we
      //    let the backend auto-detect the role, a freshly-joined listener gets
      //    an AUDIENCE (role 2) token with NO publish-audio privilege, so the
      //    moment they unmute Agora silently rejects the mic publish and nobody
      //    hears them. Always request publish privileges up front.
      logDebug('[RoomCubit] joinRoom() — fetching Agora token...');
      final tokenResp = await appDio.post('/agora/token', data: {
        'channel_id': _roomId,
        'role': 1,
      });

      final tokenData = tokenResp.data['data'] as Map<String, dynamic>;
      final token = tokenData['token'] as String;
      // The backend mints the token for a specific uid — Agora rejects the token
      // if joinChannel is called with a different uid (including the default 0).
      final uid = (tokenData['uid'] as num?)?.toInt() ?? 0;

      logDebug(
        '[RoomCubit] joinRoom() — token received. '
        'prefix=${token.length > 12 ? "${token.substring(0, 12)}..." : token}, '
        'uid=$uid',
      );

      try {
        // 5. Initialize Agora engine (singleton, safe to call multiple times)
        logDebug(
            '[RoomCubit] joinRoom() — calling AgoraService.initialize()...');
        await AgoraService.instance.initialize();
        logDebug(
            '[RoomCubit] joinRoom() — AgoraService.initialize() completed.');

        // 6. Subscribe to Agora events (update UI on user joined/left)
        if (_agoraSub == null) {
          _agoraSub = AgoraService.instance.events.listen(_onAgoraEvent);
          logDebug(
              '[RoomCubit] joinRoom() — subscribed to Agora event stream.');
        }

        // 7. Join the Agora channel
        logDebug(
            '[RoomCubit] joinRoom() — calling AgoraService.joinChannel() with uid=$uid...');
        await AgoraService.instance.joinChannel(
          channelId: _roomId,
          token: token,
          uid: uid,
        );
        logDebug(
            '[RoomCubit] joinRoom() — AgoraService.joinChannel() call returned. '
            'Waiting for onJoinChannelSuccess...');

        // 8. Sync initial mute state with native engine.
        // The state starts as isMuted=true but Agora defaults to unmuted — align them.
        await AgoraService.instance.muteLocalAudio(mute: state.isMuted);
        logDebug(
            '[RoomCubit] joinRoom() — initial mute synced (isMuted=${state.isMuted}).');

        // 8b. Sync the audio output route so the engine matches our state
        // (live-broadcast channels default to loudspeaker, but make it explicit).
        await AgoraService.instance.toggleSpeakerphone(state.isSpeakerphoneOn);
      } catch (e, st) {
        if (!_isIgnorableAgoraJoinIssue(e)) {
          logDebug('[RoomCubit] joinRoom() — Agora setup failed: $e\n$st');
          rethrow;
        }
        logDebug(
            '[RoomCubit] joinRoom() — ignored non-blocking Agora warning: $e');
      }

      // 9. Emit success state: dialog closes, then live layout is revealed.
      // 10. Start heartbeat.
      // 11. Refresh attendees so the local user appears in the grid right away.
      _finishRoomEntry();
      logDebug('[RoomCubit] joinRoom() — DONE. Heartbeat started.');
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      final data = e.response?.data;
      final msg = data is Map<String, dynamic>
          ? (data['message'] as String? ?? '')
          : '';

      // A 403 during entry means the room rejected us — almost always because
      // it is full (capacity guard) or no longer available. Abort the Agora
      // sequence, leave live view, and hand a one-shot signal to the UI so it
      // pops back to the dashboard and shows a "room full" toast. Fire a leave
      // too: harmless if we were never added, cleans up if we were.
      if (status == 403) {
        appDio.post('/rooms/$_roomId/leave').ignore();
        emit(state.copyWith(
          view: RoomView.detail,
          isConnectingAudio: false,
          entryDeniedMessage: msg,
        ));
        return;
      }

      logDebug('[RoomCubit] joinRoom() — DioException: $msg');
      emit(state.copyWith(
        isConnectingAudio: false,
        audioErrorMessage: msg.isNotEmpty ? msg : 'Token fetch failed',
      ));
    } catch (e, st) {
      logDebug('[RoomCubit] joinRoom() — unexpected error: $e\n$st');
      emit(state.copyWith(
        isConnectingAudio: false,
        audioErrorMessage: e.toString(),
      ));
    }
  }

  Future<void> _notifyJoin() async {
    try {
      await appDio.post('/rooms/$_roomId/join');
    } catch (e) {
      logDebug('[RoomCubit] join notify error: $e');
    }
  }

  // Throwing variant used by the initial entry sequence so a capacity /
  // availability rejection (403) propagates and aborts the whole join before
  // any Agora setup. The silent _notifyJoin() above is still used for the
  // fire-and-forget re-announce after a WS reconnect.
  Future<void> _notifyJoinOrThrow() async {
    await appDio.post('/rooms/$_roomId/join');
  }

  /// Cleared by the root BlocListener right after it shows the "room full"
  /// toast and pops, so the one-shot signal never fires twice.
  void clearEntryDenied() => emit(state.copyWith(entryDeniedMessage: null));
  void clearChatNotice() => emit(state.copyWith(chatNoticeMessage: null));

  Future<void> leaveRoom() async {
    logDebug(
        '[RoomCubit] leaveRoom() — leaving channel and notifying backend.');
    _stopHeartbeat();
    emit(state.copyWith(view: RoomView.detail));

    // Leave Agora channel (does NOT destroy engine)
    await AgoraService.instance.leaveChannel();

    // Notify backend
    await _notifyLeave(); // tells server to broadcast ParticipantUpdated to all clients
    logDebug('[RoomCubit] leaveRoom() — done.');
  }

  // ── Forced eviction (admin kick / temp-ban / global-ban) ───────────────────
  // Tears the audio down the instant the eviction event arrives over the
  // socket. A banned user must NOT keep transmitting in the Agora channel while
  // a notice dialog waits for their tap — enforcement cannot be gated behind a
  // user action. The heartbeat is stopped and the channel left immediately; the
  // BlocListener then shows the notice and routes the user home, and
  // RoomCubit.close() releases the native engine on the way out.
  Future<void> _evictFromRoom() async {
    logDebug('[RoomCubit] _evictFromRoom() — admin eviction, tearing down audio.');
    _stopHeartbeat();
    try {
      await AgoraService.instance.leaveChannel();
    } catch (e) {
      logDebug('[RoomCubit] eviction leaveChannel error: $e');
    }
  }

  Future<void> _notifyLeave() async {
    try {
      await appDio.post('/rooms/$_roomId/leave');
    } catch (e) {
      logDebug('[RoomCubit] leave notify error: $e');
    }
  }

  Future<void> toggleMute() async {
    final newMuted = !state.isMuted;
    logDebug(
        '[RoomCubit] toggleMute() — isMuted: ${state.isMuted} → $newMuted');
    await AgoraService.instance.muteLocalAudio(mute: newMuted);
    // Reflect our own live mic state on our own grid tile immediately (Agora's
    // remote-mute callback only fires for OTHER clients, not ourselves).
    final attendees = state.attendees
        .map((p) => p.id == _userId ? p.copyWith(isMuted: newMuted) : p)
        .toList();
    emit(state.copyWith(isMuted: newMuted, attendees: attendees));
    unawaited(_playMicSfx(newMuted));
    logDebug('[RoomCubit] toggleMute() — done. UI state updated.');
  }

  // Short confirmation blip on every mic toggle (Teams/iPhone-call style) so
  // the user notices the state actually changed. Never throws into the
  // caller — a playback hiccup must not affect the mute toggle itself.
  Future<void> _playMicSfx(bool muted) async {
    try {
      await _sfxPlayer.setAsset(
        muted ? 'assets/sounds/mic_mute.wav' : 'assets/sounds/mic_unmute.wav',
      );
      await _sfxPlayer.play();
    } catch (e) {
      logDebug('[RoomCubit] mic sfx error: $e');
    }
  }

  /// Current authenticated user — bubbles compare against this to align
  /// own messages right and others left.
  String get currentUserId => _userId;

  /// True when the local user holds an elevated role — gates the ghost-mode
  /// (invisibility) toggle in the live controls bar.
  bool get isModerator =>
      _userRole == 'admin' ||
      _userRole == 'moderator' ||
      _userRole == 'supervisor';

  // ── Ghost mode (moderator invisibility) ────────────────────────────────────
  // Optimistic: the local grid updates instantly via RoomState.isGhostMode;
  // the backend then broadcasts UserVisibilityChanged so every other client
  // hides/shows the moderator's tile. Audio connection is untouched.
  Future<void> toggleGhostMode() async {
    if (!isModerator) return;
    final hidden = !state.isGhostMode;
    logDebug('[RoomCubit] toggleGhostMode() — hidden=$hidden');
    final hiddenIds = Set<String>.from(state.hiddenUserIds);
    hidden ? hiddenIds.add(_userId) : hiddenIds.remove(_userId);
    final next = state.copyWith(
      isGhostMode: hidden,
      hiddenUserIds: hiddenIds,
    );
    emit(next);
    _publishVisibleCount(next, next.participantCount);
    try {
      await appDio.post('/rooms/$_roomId/visibility', data: {'hidden': hidden});
    } catch (e) {
      // Keep the optimistic local state — visibility is non-critical and the
      // next toggle retries the sync.
      logDebug('[RoomCubit] toggleGhostMode sync error: $e');
    }
  }

  // ── Audio output route (loudspeaker ⇄ earpiece) ────────────────────────────
  Future<void> setSpeakerphone(bool enabled) async {
    if (state.isSpeakerphoneOn == enabled) return;
    logDebug('[RoomCubit] setSpeakerphone($enabled)');
    await AgoraService.instance.toggleSpeakerphone(enabled);
    emit(state.copyWith(isSpeakerphoneOn: enabled));
  }

  // Opening the sheet marks everything as read; the badge disappears.
  void toggleChat() {
    final opening = !state.chatVisible;
    emit(state.copyWith(
      chatVisible: opening,
      unreadCount: opening ? 0 : state.unreadCount,
    ));
  }

  void hideChat() => emit(state.copyWith(chatVisible: false));
  void toggleFloating() =>
      emit(state.copyWith(floatingEnabled: !state.floatingEnabled));

  // Called by the BlocListener immediately after it reads pendingModeration
  // so the dialog can never fire a second time for the same event.
  void clearModeration() => emit(state.copyWith(pendingModeration: null));

  // ── POST /api/rooms/{id}/messages ──────────────────────────────────────────
  Future<void> sendMessage(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || trimmed.length > 500) return;
    if (state.isChatMuted) {
      emit(state.copyWith(chatNoticeMessage: _chatMutedByAdminMessage));
      return;
    }

    // Optimistic: show the message immediately while the API call is in flight.
    final tempId = 'sending_${DateTime.now().millisecondsSinceEpoch}';
    final optimistic = ChatMessage(
      id: tempId,
      userId: _userId,
      senderName: _username,
      senderAvatar: '',
      senderRole: _userRole,
      text: trimmed,
      sentAt: DateTime.now(),
      isSending: true,
    );
    if (!isClosed) {
      emit(state.copyWith(messages: [...state.messages, optimistic]));
      // Safety net: if WS confirmation never arrives, remove the spinner so
      // the message is never stuck in isSending state indefinitely.
      _scheduleOptimisticTimeout(tempId);
    }

    try {
      await appDio.post('/rooms/$_roomId/messages', data: {
        'message': trimmed,
        'userId': _userId,
        'username': _username,
        'role': _userRole,
        'timestamp': DateTime.now().toUtc().toIso8601String(),
      });
      // On success, the server broadcasts MessageSent which deduplicates the
      // optimistic placeholder (see _onWsMessage > MessageSent).
    } catch (e) {
      logDebug('[RoomCubit] sendMessage error: $e');
      if (e is DioException && e.response?.statusCode == 403) {
        final data = e.response?.data;
        final code = data is Map<String, dynamic> ? data['code'] : null;
        if (code == 'chat_muted') {
          emit(state.copyWith(
            isChatMuted: true,
            chatNoticeMessage:
                data['message'] as String? ?? _chatMutedByAdminMessage,
          ));
        }
      } else if (e is DioException && e.response?.statusCode == 422) {
        // Bad-word filter rejected the message — alert the sender so they can
        // edit it. The message is rolled back below (never stored/broadcast).
        final data = e.response?.data;
        final code = data is Map<String, dynamic> ? data['code'] : null;
        if (code == 'banned_word') {
          emit(state.copyWith(
            chatNoticeMessage: data['message'] as String? ??
                'رسالتك تحتوي على كلمات غير لائقة. يُرجى تعديلها.',
          ));
        }
      }
      // Roll back the optimistic message so the user knows send failed.
      if (!isClosed) {
        emit(state.copyWith(
          messages: state.messages.where((m) => m.id != tempId).toList(),
        ));
      }
    }
  }

  Future<void> deleteMessage(String messageId) async {
    if (!isModerator || messageId.isEmpty) return;
    _markMessageDeleted(messageId);
    try {
      await appDio.delete('/rooms/$_roomId/messages/$messageId');
    } catch (e) {
      logDebug('[RoomCubit] deleteMessage error: $e');
      emit(state.copyWith(chatNoticeMessage: 'تعذر حذف الرسالة'));
    }
  }

  Future<void> muteUserFromChat(String userId) async {
    if (!isModerator || userId.isEmpty || userId == _userId) return;
    try {
      await appDio.post('/rooms/$_roomId/users/$userId/chat-mute');
      emit(state.copyWith(
          chatNoticeMessage: 'تم حظر المستخدم من الكتابة في الشات'));
    } catch (e) {
      logDebug('[RoomCubit] muteUserFromChat error: $e');
      emit(state.copyWith(chatNoticeMessage: 'تعذر حظر المستخدم من الشات'));
    }
  }

  Future<void> tempBanUser(String userId, int durationMinutes) async {
    if (!isModerator || userId.isEmpty || userId == _userId) return;
    final safeMinutes = durationMinutes.clamp(1, 10080);
    try {
      await appDio.post('/rooms/$_roomId/users/$userId/room-ban', data: {
        'duration_minutes': safeMinutes,
      });
      emit(state.copyWith(
          chatNoticeMessage: 'تم طرد المستخدم مؤقتاً من الغرفة'));
      _scheduleAttendeeRefresh();
    } catch (e) {
      logDebug('[RoomCubit] tempBanUser error: $e');
      emit(state.copyWith(chatNoticeMessage: 'تعذر طرد المستخدم مؤقتاً'));
    }
  }

  Future<void> globalBanUser(String userId) async {
    if (!isModerator || userId.isEmpty || userId == _userId) return;
    try {
      await appDio.post('/rooms/$_roomId/users/$userId/global-ban');
      emit(state.copyWith(chatNoticeMessage: 'تم حظر المستخدم من كل الرومات'));
      _scheduleAttendeeRefresh();
    } catch (e) {
      logDebug('[RoomCubit] globalBanUser error: $e');
      emit(state.copyWith(chatNoticeMessage: 'تعذر حظر المستخدم'));
    }
  }

  void _onAgoraEvent(AgoraEvent event) {
    // Only react to events if in live view (prevent stale reactions)
    if (state.view != RoomView.live) return;

    switch (event) {
      case AgoraJoinSuccess(:final uid):
        logDebug('[RoomCubit] Agora join success: $uid');
      // Optionally emit a success indicator or just stay connected

      case AgoraUserJoined(:final uid):
        logDebug('[RoomCubit] User joined: $uid');
      // Could update speakers list if tracking remote UIDs

      case AgoraUserOffline(:final uid):
        logDebug('[RoomCubit] User offline: $uid');
      // Could remove from speakers list

      case AgoraLeftChannel():
        logDebug('[RoomCubit] Left channel');
      // This happens when we call leaveChannel

      case AgoraError(:final code):
        logDebug('[RoomCubit] Agora error: $code');
        if (_isIgnorableAgoraErrorCode(code)) {
          logDebug('[RoomCubit] Ignoring non-blocking Agora code: ${code.name}');
          return;
        }
        emit(state.copyWith(
          audioErrorMessage: 'Audio connection error: ${code.name}',
        ));

      case AgoraSpeakingUpdate(:final speakingUids):
        _applySpeakingUids(speakingUids);

      case AgoraMuteUpdate(:final uid, :final muted):
        _applyRemoteMute(uid, muted);
    }
  }

  /// Live mic on/off for a remote participant — flips their grid badge the
  /// instant Agora reports the change (no backend round-trip, no manual
  /// refresh). Agora uids equal the participant's user id.
  void _applyRemoteMute(int uid, bool muted) {
    if (isClosed || state.attendees.isEmpty) return;
    final uidStr = uid.toString();
    var changed = false;
    final updated = state.attendees.map((p) {
      if (p.id == uidStr && p.isMuted != muted) {
        changed = true;
        return p.copyWith(isMuted: muted);
      }
      return p;
    }).toList();
    if (changed) emit(state.copyWith(attendees: updated));
  }

  /// Reflects Agora's live volume snapshot onto the attendee tiles so the
  /// pulsing ring rings ONLY around whoever is actually talking. Agora UIDs
  /// equal the participant's user id (see AgoraController::token), and uid 0
  /// (or our own uid) is the local user.
  void _applySpeakingUids(Set<int> speakingUids) {
    if (isClosed || state.attendees.isEmpty) return;

    final localUid = int.tryParse(_userId);
    final speakingIds = <String>{};
    for (final uid in speakingUids) {
      if (uid == 0 || (localUid != null && uid == localUid)) {
        if (_userId.isNotEmpty) speakingIds.add(_userId);
      } else {
        speakingIds.add(uid.toString());
      }
    }
    // A muted local mic publishes no audio, but guard so our own tile never
    // rings while we're muted.
    if (state.isMuted) speakingIds.remove(_userId);

    final changed = state.attendees
        .any((p) => p.isSpeaking != speakingIds.contains(p.id));
    if (!changed) return;

    emit(state.copyWith(
      attendees: state.attendees
          .map((p) => p.copyWith(isSpeaking: speakingIds.contains(p.id)))
          .toList(),
    ));
  }

  @override
  Future<void> close() async {
    _reconnectTimer?.cancel();
    _heartbeatTimer?.cancel();
    _attendeeRefreshTimer?.cancel();
    _wsSub?.cancel();
    _ws?.sink.close();
    _agoraSub?.cancel();
    _sfxPlayer.dispose();

    // Fire-and-forget leave so the server decrements the count even when
    // the user exits via the system back gesture instead of the Leave button.
    if (state.view == RoomView.live) {
      appDio.post('/rooms/$_roomId/leave').ignore();
    }

    // Release Agora engine (cleanup native resources)
    await AgoraService.instance.releaseEngine();

    return super.close();
  }
}

// =============================================================================
// SECTION 4 — PULSING RING (active speaker animation)
// =============================================================================
class _PulsingRing extends StatefulWidget {
  final double size;
  final Color color;
  final Widget child;
  const _PulsingRing(
      {required this.size, required this.color, required this.child});

  @override
  State<_PulsingRing> createState() => _PulsingRingState();
}

class _PulsingRingState extends State<_PulsingRing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale, _opacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat();
    _scale = Tween<double>(begin: 1.0, end: 1.22)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _opacity = Tween<double>(begin: 0.6, end: 0.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          AnimatedBuilder(
            animation: _ctrl,
            builder: (_, __) => Transform.scale(
              scale: _scale.value,
              child: Container(
                width: widget.size,
                height: widget.size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: widget.color.withValues(alpha: _opacity.value),
                    width: 2.5,
                  ),
                ),
              ),
            ),
          ),
          widget.child,
        ],
      ),
    );
  }
}

// =============================================================================
// SECTION 4b — LIVE PULSE DOT
//
// A tiny solid dot wrapped by a soft halo that repeatedly expands and fades —
// a calm "we're live" heartbeat. Replaces static live-badge icons in both the
// pre-join preview sheet and the in-room header.
// =============================================================================
class _LivePulseDot extends StatefulWidget {
  final double size;
  const _LivePulseDot({this.size = 8});

  @override
  State<_LivePulseDot> createState() => _LivePulseDotState();
}

class _LivePulseDotState extends State<_LivePulseDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  late final Animation<double> _scale = Tween<double>(begin: 1.0, end: 2.6)
      .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
  late final Animation<double> _opacity = Tween<double>(begin: 0.55, end: 0.0)
      .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dot = widget.size;
    final halo = dot * 2.6;
    return SizedBox(
      width: halo,
      height: halo,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Expanding + fading halo behind the core.
          AnimatedBuilder(
            animation: _ctrl,
            builder: (_, __) => Transform.scale(
              scale: _scale.value,
              child: Container(
                width: dot,
                height: dot,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.white.withValues(alpha: _opacity.value),
                ),
              ),
            ),
          ),
          // Solid core dot.
          Container(
            width: dot,
            height: dot,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.white,
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// SECTION 5 — ATTENDEE AVATAR  (shared between Detail + Live)
//
// Everyone renders identically; users with active publishing privileges
// (host/speaker) get a subtle mic badge pinned to the avatar's corner.
// =============================================================================
class _AttendeeAvatar extends StatelessWidget {
  final ParticipantModel p;
  final bool isLive;

  const _AttendeeAvatar({required this.p, this.isLive = false});

  @override
  Widget build(BuildContext context) {
    final avatar = Container(
      width: isLive ? 72 : 68,
      height: isLive ? 72 : 68,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.40),
          width: 1.8,
        ),
        color: isLive
            ? AppColors.primaryLight.withValues(alpha: 0.30)
            : AppColors.background,
      ),
      child: ClipOval(
        child: _avatarWithInitials(
          p.avatarUrl,
          p.name,
          diameter: isLive ? 72 : 68,
          fontSize: isLive ? 24 : 22,
          bg: isLive
              ? AppColors.primaryLight.withValues(alpha: 0.45)
              : const Color(0x1A305544),
          fg: isLive ? AppColors.white : AppColors.primary,
        ),
      ),
    );

    // Mic-status badge pinned to the avatar corner. Shows for anyone who is
    // muted (mic-off) — so a muted member is obvious like the admin is — and
    // for active broadcasters (mic). A muted-off badge tints red for clarity.
    final showMicBadge = p.isMuted || p.isBroadcaster;
    final badged = Stack(
      clipBehavior: Clip.none,
      children: [
        avatar,
        if (showMicBadge)
          PositionedDirectional(
            bottom: -2,
            end: -2,
            child: Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: p.isMuted
                    ? AppColors.error
                    : (isLive ? AppColors.white : AppColors.primary),
                shape: BoxShape.circle,
                border: Border.all(
                  color: isLive ? AppColors.primary : AppColors.white,
                  width: 1.5,
                ),
              ),
              child: Icon(
                p.isMuted ? LucideIcons.micOff : LucideIcons.mic,
                size: 11,
                color: p.isMuted
                    ? AppColors.white
                    : (isLive ? AppColors.primary : AppColors.white),
              ),
            ),
          ),
        // Moderator pill — white "مشرف" tag with green text, pinned over the
        // avatar's top edge (was gold/brown, which clashed with the green).
        if (p.isModerator)
          Positioned(
            top: -6,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppColors.primary,
                    width: 1.2,
                  ),
                ),
                child: Text(
                  AppLocalizations.of(context)!.moderatorBadge,
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                    height: 1.25,
                  ),
                ),
              ),
            ),
          ),
      ],
    );

    final ringSize = isLive ? 86.0 : 82.0;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Always reserve the pulsing-ring's footprint so the avatar + name
        // stay at a fixed level — the tile must never jump up/down when
        // someone starts or stops speaking.
        SizedBox(
          width: ringSize,
          height: ringSize,
          child: Center(
            child: p.isSpeaking
                ? _PulsingRing(
                    size: ringSize,
                    color: AppColors.primaryLight,
                    child: badged,
                  )
                : badged,
          ),
        ),
        const SizedBox(height: 7),
        Text(
          p.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontFamily: 'Cairo',
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: isLive ? Colors.white : AppColors.darkText,
            height: 1.2,
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// SECTION 6 — SECTION HEADER
// =============================================================================
class _SheetSectionHeader extends StatelessWidget {
  final String text;
  const _SheetSectionHeader({required this.text});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Text(
        text,
        textAlign: TextAlign.start,
        style: const TextStyle(
          fontFamily: 'Cairo',
          fontSize: 17,
          fontWeight: FontWeight.w800,
          color: AppColors.darkText,
        ),
      ),
    );
  }
}

// =============================================================================
// SECTION 7 — ROOM DETAIL VIEW  (Page 7 — pre-join)
// =============================================================================
class _RoomDetailView extends StatelessWidget {
  final RoomDetailModel room;
  final RoomState state;
  final RoomCubit cubit;

  const _RoomDetailView({
    required this.room,
    required this.state,
    required this.cubit,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final size = MediaQuery.of(context).size;
    final topPad = MediaQuery.of(context).padding.top;
    final botPad = MediaQuery.of(context).padding.bottom;
    const bottomBarH = 82.0;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      // Light nav bar for the (light) pre-join detail page — also restores the
      // light bar when the user backs out of the dark green live room.
      value: const SystemUiOverlayStyle(
        systemNavigationBarColor:          AppColors.background,
        systemNavigationBarIconBrightness: Brightness.dark,
        systemNavigationBarDividerColor:   AppColors.background,
        statusBarColor:                    Colors.transparent,
        statusBarIconBrightness:           Brightness.dark,
      ),
      child: Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          Positioned(
            top: 0, left: 0, right: 0,
            height: size.height * 0.40,
            // The pre-join header is the external BANNER/cover — strictly
            // separate from the live in-room background. headerImageUrl prefers
            // the dedicated banner and falls back to the legacy cover image.
            child: Image.network(
              room.headerImageUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                color: AppColors.primary.withValues(alpha: 0.20),
              ),
            ),
          ),
          Positioned(
            top: size.height * 0.24,
            left: 0,
            right: 0,
            height: size.height * 0.18,
            child: const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, AppColors.surface],
                ),
              ),
            ),
          ),
          Positioned(
            top: topPad + 12,
            right: 16,
            child: GestureDetector(
              onTap: () => context.canPop() ? context.pop() : null,
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  LucideIcons.arrowRight,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: size.height * 0.80,
            child: _RoomInfoSheet(
              room: room,
              attendees: state.visibleAttendees(cubit.currentUserId),
              cubit: cubit,
              bottomBarH: bottomBarH,
              botPad: botPad,
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.fromLTRB(
                20,
                12,
                20,
                botPad > 0 ? botPad + 8 : 20,
              ),
              decoration: const BoxDecoration(
                color: AppColors.surface,
                border: Border(
                  top: BorderSide(color: AppColors.cardBorder, width: 1),
                ),
              ),
              child: GestureDetector(
                onTap: () async {
                  await cubit.joinRoom();
                },
                child: Container(
                  width: double.infinity,
                  height: 54,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.28),
                        blurRadius: 14,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    l10n.joinRoom,
                    style: const TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
    );
  }
}

// =============================================================================
// SECTION 8 — ROOM INFO SHEET
// =============================================================================
class _RoomInfoSheet extends StatelessWidget {
  final RoomDetailModel room;
  final List<ParticipantModel> attendees;
  final RoomCubit cubit;
  final double bottomBarH;
  final double botPad;

  const _RoomInfoSheet({
    required this.room,
    required this.attendees,
    required this.cubit,
    required this.bottomBarH,
    required this.botPad,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
            20,
            20,
            20,
            16 + bottomBarH + botPad,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.cardBorder,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                room.title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppColors.darkText,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 10),
              // Live headcount — directly under the title.
              Center(
                child: BlocBuilder<RoomStatusCubit, RoomStatusState>(
                  buildWhen: (p, c) => p.counts[room.id] != c.counts[room.id],
                  builder: (ctx, status) => _StatChip(
                    icon: Icons.people_alt_rounded,
                    label: l10n.attendeesCount(
                      status.counts[room.id] ?? room.listenerCount,
                    ),
                  ),
                ),
              ),
              // Description — muted typography, directly under the count.
              if (room.description.trim().isNotEmpty) ...[
                const SizedBox(height: 14),
                Text(
                  room.description,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'Tajawal',
                    fontSize: 13.5,
                    color: AppColors.textSecondary,
                    height: 1.6,
                  ),
                ),
              ],
              const SizedBox(height: 22),
              _SheetSectionHeader(text: l10n.attendeesLabel),
              const SizedBox(height: 16),
              attendees.isEmpty
                  ? _NoAttendeesPlaceholder(text: l10n.noAttendeesYet)
                  : _AttendeesPreviewGrid(attendees: attendees, cubit: cubit),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// SECTION 9 — ATTENDEES PREVIEW GRID  (pre-join sheet — live roster)
//
// Same avatar+name tile as the in-room grid (_AttendeeAvatar), sized to its
// intrinsic content height inside the scrollable sheet — this isn't a
// full-screen view, so it skips the live grid's viewport-filling/centering.
// Tapping a tile opens the same profile sheet as the in-room grid.
// =============================================================================
class _AttendeesPreviewGrid extends StatelessWidget {
  final List<ParticipantModel> attendees;
  final RoomCubit cubit;

  const _AttendeesPreviewGrid({required this.attendees, required this.cubit});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 88,
        mainAxisExtent: 100,
        crossAxisSpacing: 10,
        mainAxisSpacing: 16,
      ),
      itemCount: attendees.length,
      itemBuilder: (_, i) {
        final p = attendees[i];
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _showRoomUserProfileSheet(context, p, cubit),
          child: _AttendeeAvatar(p: p),
        );
      },
    );
  }
}

/// Compact empty-state row shown when no one is currently in the room.
class _NoAttendeesPlaceholder extends StatelessWidget {
  final String text;
  const _NoAttendeesPlaceholder({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            LucideIcons.userX,
            size: 26,
            color: AppColors.textSecondary.withValues(alpha: 0.55),
          ),
          const SizedBox(height: 10),
          Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'Tajawal',
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// SECTION 10 — STAT CHIP
// =============================================================================
class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _StatChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    // Icon leads (reading-start side, auto-flips per Directionality) so it
    // matches the in-room headcount's icon-then-label order instead of
    // trailing at the visually "reversed" end.
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: AppColors.primary),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'Tajawal',
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.primary,
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// SECTION 11 — TIKTOK CHAT OVERLAY  (bottom sheet, slide-up/down)
// =============================================================================
class _TikTokChatOverlay extends StatefulWidget {
  final bool visible;
  final VoidCallback onClose;
  final RoomCubit cubit;

  const _TikTokChatOverlay({
    required this.visible,
    required this.onClose,
    required this.cubit,
  });

  @override
  State<_TikTokChatOverlay> createState() => _TikTokChatOverlayState();
}

class _TikTokChatOverlayState extends State<_TikTokChatOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<Offset> _slide;
  late final TextEditingController _textCtrl;
  final ScrollController _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _textCtrl = TextEditingController();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _slide = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    if (widget.visible) {
      _ctrl.forward();
      _scrollToLatest();
    }
  }

  // History is fetched before the WS connects, so on open the list already
  // holds the room's past messages — position it at the newest one instead
  // of leaving the viewport stuck at the top of the history.
  void _scrollToLatest({bool animated = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      if (animated) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      } else {
        _scroll.jumpTo(_scroll.position.maxScrollExtent);
      }
    });
  }

  @override
  void didUpdateWidget(_TikTokChatOverlay old) {
    super.didUpdateWidget(old);
    if (widget.visible && !old.visible) {
      _ctrl.forward();
      _scrollToLatest();
    }
    if (!widget.visible && old.visible) {
      _ctrl.reverse();
      // Dismiss the keyboard when the chat closes — otherwise it lingers.
      FocusScope.of(context).unfocus();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _textCtrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _send() {
    widget.cubit.sendMessage(_textCtrl.text);
    _textCtrl.clear();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final botPad = MediaQuery.of(context).padding.bottom;

    return BlocListener<RoomCubit, RoomState>(
      listenWhen: (prev, curr) =>
          widget.visible && curr.messages.length > prev.messages.length,
      listener: (_, __) => _scrollToLatest(animated: true),
      child: SlideTransition(
        position: _slide,
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.55,
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
            child: BackdropFilter(
            // Frosted sheet — slightly translucent so the room shows through,
            // rather than a flat opaque white.
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
            decoration: BoxDecoration(
              color: AppColors.surface.withValues(alpha: 0.82),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x1F000000),
                  blurRadius: 24,
                  offset: Offset(0, -6),
                ),
              ],
            ),
            child: Column(
              children: [
                // Header — drag handle + title + close.
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
                  child: Column(
                    children: [
                      Container(
                        width: 38,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppColors.cardBorder,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          GestureDetector(
                            onTap: widget.onClose,
                            child: Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: AppColors.background,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                LucideIcons.chevronDown,
                                color: AppColors.primary,
                                size: 18,
                              ),
                            ),
                          ),
                          const Spacer(),
                          Text(
                            l10n.chatTab,
                            style: const TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Messages: RoomState.messages is the live source of truth.
                Expanded(
                  child: BlocBuilder<RoomCubit, RoomState>(
                    buildWhen: (prev, curr) =>
                        prev.messages != curr.messages ||
                        prev.messages.length != curr.messages.length,
                    builder: (_, state) => ShaderMask(
                      // Smooth top fade-out: messages dissolve as they scroll up
                      // under the header. dstIn keeps the child where the
                      // gradient is opaque and hides it where transparent.
                      shaderCallback: (bounds) => LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          AppColors.white.withValues(alpha: 0.0),
                          AppColors.white,
                        ],
                        // Top ~15% transparent → fades to solid, so bubbles
                        // dissolve under the header instead of cutting off.
                        stops: const [0.0, 0.15],
                      ).createShader(bounds),
                      blendMode: BlendMode.dstIn,
                      child: ListView.builder(
                      controller: _scroll,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      itemCount: state.messages.length,
                      itemBuilder: (_, i) => _ChatBubble(
                        message: state.messages[i],
                        isMine: state.messages[i].userId ==
                            widget.cubit.currentUserId,
                        canModerate: widget.cubit.isModerator,
                        onDelete: state.messages[i].isDeleted ||
                                state.messages[i].isSending
                            ? null
                            : () => widget.cubit
                                .deleteMessage(state.messages[i].id),
                        onUserTap: state.messages[i].userId.isEmpty
                            ? null
                            : () => _showRoomUserProfileSheet(
                                  context,
                                  _participantFromMessage(state.messages[i]),
                                  widget.cubit,
                                ),
                        // Report a specific message. Only for other users'
                        // real (non-admin) messages — own messages, admin
                        // messages (synthetic id), and empty ids aren't
                        // reportable.
                        onReportMessage: (state.messages[i].userId ==
                                    widget.cubit.currentUserId ||
                                int.tryParse(state.messages[i].userId) == null)
                            ? null
                            : () => showReportMessageSheet(
                                  context,
                                  userId:
                                      int.parse(state.messages[i].userId),
                                  messageContent: state.messages[i].text,
                                  roomId: widget.cubit.state.roomDetail?.id,
                                ),
                      ),
                    ),
                    ),
                  ),
                ),

                // Floating-messages toggle moved to Settings (الرسائل العائمة).

                // Input
                _ChatInput(
                  ctrl: _textCtrl,
                  onSend: _send,
                  bottomPad: botPad,
                  enabled: !widget.cubit.state.isChatMuted,
                ),
              ],
            ),
          ),
          ),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// SECTION 11b — FLOATING MESSAGE PREVIEW
//
// One active incoming-message preview owned by _LiveRoomView. A BlocListener
// sets the message when RoomState.messages grows while the chat sheet is
// closed; a Timer clears it after 3 seconds so AnimatedSwitcher fades/slides
// it away cleanly.
// =============================================================================
class _FloatingMessagePreview extends StatelessWidget {
  final ChatMessage? message;

  const _FloatingMessagePreview({required this.message});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 240),
        reverseDuration: const Duration(milliseconds: 200),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, animation) {
          // Slide in from the reading-start edge (right in RTL, left in LTR).
          final dx = Directionality.of(context) == TextDirection.rtl
              ? 0.22
              : -0.22;
          final slide = Tween<Offset>(
            begin: Offset(dx, 0.10),
            end: Offset.zero,
          ).animate(animation);
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(position: slide, child: child),
          );
        },
        child: message == null
            ? const SizedBox.shrink(key: ValueKey('floating-empty'))
            : _FloatingBubble(
                key: ValueKey('floating-${message!.id}'),
                message: message!,
              ),
      ),
    );
  }
}

// =============================================================================
// SECTION 11c — FLOATING BUBBLE  (individual drifting message card)
// =============================================================================
class _FloatingBubble extends StatelessWidget {
  final ChatMessage message;
  const _FloatingBubble({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final isAdmin = message.senderRole == 'admin';
    final isElevated = isAdmin || message.senderRole == 'supervisor';
    // Elevated senders get a warm accent name; everyone else reads white.
    final Color nameColor = isElevated ? AppColors.accent : AppColors.white;

    const radius = BorderRadiusDirectional.only(
      topStart: Radius.circular(6),
      topEnd: Radius.circular(18),
      bottomStart: Radius.circular(18),
      bottomEnd: Radius.circular(18),
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.80,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Sender avatar — mirrors the chat/grid avatar styling.
          ClipOval(
            child: SizedBox(
              width: 34,
              height: 34,
              child: isAdmin
                  ? Container(
                      color: AppColors.primary,
                      alignment: Alignment.center,
                      child: const Icon(LucideIcons.shieldCheck,
                          size: 17, color: AppColors.white),
                    )
                  : _roomAvatarImage(
                      message.senderAvatar,
                      fallback: Container(
                        color: AppColors.primary,
                        child: const Icon(LucideIcons.user,
                            size: 17, color: AppColors.white),
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 8),
          // Chat-style bubble — name on top, message below.
          Flexible(
            child: ClipRRect(
              borderRadius: radius,
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
                  decoration: BoxDecoration(
                    color: AppColors.roomOverlay.withValues(alpha: 0.74),
                    borderRadius: radius,
                    border: Border.all(
                      color: AppColors.white.withValues(alpha: 0.16),
                      width: 0.8,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        message.senderName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: nameColor,
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        message.text,
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 13.5,
                          fontWeight: FontWeight.w500,
                          color: AppColors.white,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// SECTION 11d — MODERATION DIALOG  (kick / temporary-ban)
// Shown by the BlocListener in _LiveRoomView; non-dismissible by tapping away.
// After the user taps the confirm button the BlocListener navigates them out.
// =============================================================================
class _ModerationDialog extends StatelessWidget {
  final ModerationEvent event;
  const _ModerationDialog({required this.event});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isKick = event is KickEvent;
    final isGlobalBan = event is GlobalBanEvent;
    final isRoomClosed = event is RoomClosedEvent;
    final title = isRoomClosed
        ? 'تم إغلاق الغرفة'
        : isGlobalBan
            ? 'تم حظرك من كل الرومات'
            : isKick
                ? l10n.kickedFromRoom
                : l10n.tempBannedFromRoom;
    final body = isRoomClosed
        ? 'تم إغلاق هذه الغرفة بواسطة الإدارة.'
        : isGlobalBan
            ? ((event as GlobalBanEvent).reason.isNotEmpty
                ? (event as GlobalBanEvent).reason
                : 'تم حظر حسابك من دخول الرومات الصوتية بواسطة الإدارة.')
            : isKick
                ? l10n.kickedFromRoomBody
                : l10n.tempBannedFromRoomBody;

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: AppColors.error.withValues(alpha: 0.22),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.black.withValues(alpha: 0.18),
              blurRadius: 40,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                LucideIcons.shieldOff,
                color: AppColors.error,
                size: 32,
              ),
            ),
            const SizedBox(height: 20),

            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Cairo',
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.darkText,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              body,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Tajawal',
                fontSize: 14,
                color: AppColors.textSecondary,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              child: GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Container(
                  height: 50,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    l10n.confirm,
                    style: const TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.white,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// SECTION 12 — CHAT BUBBLE  (modern asymmetric-tail design)
//
// • Sender username sits ABOVE the bubble in a small gray label.
// • 16px rounded corners, with a sharp tail on the bottom-RIGHT for the
//   current user's messages and the bottom-LEFT for everyone else.
//   Alignment is intentionally physical (not directional) so the own/other
//   sides stay fixed in both RTL and LTR locales, like mainstream chat apps.
// • Dark-mode palette: muted blue-gray (self) / deep dark slate (others).
// =============================================================================
class _ChatBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isMine;
  final bool canModerate;
  final VoidCallback? onDelete;
  final VoidCallback? onUserTap;
  // Long-press the bubble to report THIS specific message (content + sender)
  // so a moderator sees exactly which message was flagged. Separate from
  // reporting the user via their avatar. Null → message isn't reportable
  // (own message, or admin/moderator with a synthetic id).
  final VoidCallback? onReportMessage;

  const _ChatBubble({
    required this.message,
    required this.isMine,
    this.canModerate = false,
    this.onDelete,
    this.onUserTap,
    this.onReportMessage,
  });

  static const _r = Radius.circular(14);
  static const _sharp = Radius.circular(4);

  @override
  Widget build(BuildContext context) {
    final isAdmin = message.senderRole == 'admin';
    final isElevated = isAdmin || message.senderRole == 'supervisor';
    final isDeleted = message.isDeleted;

    // Clean minimalist palette: own bubbles = brand green + white text;
    // others = light surface + dark text; deleted = neutral translucent.
    final Color bubbleColor = isDeleted
        ? AppColors.chatBubbleDeleted
        : isMine
            ? AppColors.chatBubbleSelf
            : AppColors.chatBubbleOther;
    final Color textColor = isDeleted
        ? AppColors.chatTextDeleted
        : isMine
            ? AppColors.chatTextSelf
            : AppColors.chatTextOther;
    final Color timeColor =
        isDeleted ? AppColors.chatTextDeleted : (isMine ? AppColors.chatTimeSelf : AppColors.chatTimeOther);

    final bubble = Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.74,
      ),
      padding: const EdgeInsets.fromLTRB(14, 9, 14, 7),
      decoration: BoxDecoration(
        color: bubbleColor,
        borderRadius: BorderRadiusDirectional.only(
          topStart: _r,
          topEnd: _r,
          bottomStart: isMine ? _sharp : _r, // sharp tail hugs own outer corner
          bottomEnd: isMine ? _r : _sharp, // sharp tail hugs other's outer corner
        ),
        border: isDeleted
            ? Border.all(
                color: AppColors.white.withValues(alpha: 0.10),
                width: 1,
              )
            : isElevated
                ? Border.all(
                    color: AppColors.primary.withValues(alpha: 0.55),
                    width: 1.1,
                  )
                // Same treatment as the support/report chat: a visible
                // hairline border on every ordinary bubble, not just the
                // special-cased ones.
                : Border.all(
                    color: isMine
                        ? AppColors.chatBorderSelf
                        : AppColors.chatBorderOther,
                    width: 1,
                  ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            message.text,
            textAlign: TextAlign.start,
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 13.5,
              fontWeight: FontWeight.w500,
              color: textColor,
              fontStyle: isDeleted ? FontStyle.italic : FontStyle.normal,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 3),
          // Timestamp / sending spinner — small, trailing inside the bubble.
          Align(
            alignment: AlignmentDirectional.bottomEnd,
            child: message.isSending
                ? SizedBox(
                    width: 11,
                    height: 11,
                    child: MubtaathLoader(
                      strokeWidth: 1.5,
                      color: timeColor,
                    ),
                  )
                : Text(
                    '${message.sentAt.hour}:'
                    '${message.sentAt.minute.toString().padLeft(2, '0')}',
                    style: TextStyle(
                      fontFamily: 'Tajawal',
                      fontSize: 9.5,
                      color: timeColor,
                      height: 1.0,
                    ),
                  ),
          ),
        ],
      ),
    );

    final avatar = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onUserTap,
      child: ClipOval(
        child: SizedBox(
          width: 26,
          height: 26,
          // Admins carry no stored avatar — render the platform admin emblem
          // instead of failing to load a name through Image.network.
          child: isAdmin
              ? Container(
                  color: AppColors.primary,
                  alignment: Alignment.center,
                  child: const Icon(
                    LucideIcons.shieldCheck,
                    size: 14,
                    color: AppColors.white,
                  ),
                )
              : _roomAvatarImage(
                  message.senderAvatar,
                  fallback: Container(
                    color: AppColors.primary,
                    child: const Icon(
                      LucideIcons.user,
                      size: 14,
                      color: AppColors.white,
                    ),
                  ),
                ),
        ),
      ),
    );

    final messageColumn = Column(
      crossAxisAlignment:
          isMine ? CrossAxisAlignment.start : CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Sender username — small, distinct gray label above the bubble.
        Padding(
          padding: const EdgeInsets.only(bottom: 3, left: 4, right: 4),
          child: Text(
            message.senderName,
            style: TextStyle(
              fontFamily: 'Tajawal',
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isElevated
                  ? AppColors.primary
                  : AppColors.chatSenderName,
              height: 1.0,
            ),
          ),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (canModerate && onDelete != null && !isMine) ...[
              _DeleteMessageButton(onTap: onDelete!),
              const SizedBox(width: 6),
            ],
            // Long-press → report this message (skipped for own / deleted /
            // non-reportable messages where onReportMessage is null).
            (onReportMessage == null || isDeleted)
                ? bubble
                : GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onLongPress: onReportMessage,
                    child: bubble,
                  ),
            if (canModerate && onDelete != null && isMine) ...[
              const SizedBox(width: 6),
              _DeleteMessageButton(onTap: onDelete!),
            ],
          ],
        ),
      ],
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      // Directional alignment: own messages hug the reading-start edge (right in
      // Arabic, left in English); others hug the opposite edge with their avatar
      // pinned to the outer screen edge. Inherits the ambient text direction.
      child: Row(
        mainAxisAlignment:
            isMine ? MainAxisAlignment.start : MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          messageColumn,
          if (!isMine) ...[const SizedBox(width: 7), avatar],
        ],
      ),
    );
  }
}

class _DeleteMessageButton extends StatelessWidget {
  final VoidCallback onTap;
  const _DeleteMessageButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: AppColors.error.withValues(alpha: 0.18),
          shape: BoxShape.circle,
          border: Border.all(
            color: AppColors.error.withValues(alpha: 0.35),
            width: 0.8,
          ),
        ),
        child: const Icon(
          LucideIcons.trash2,
          size: 14,
          color: AppColors.white,
        ),
      ),
    );
  }
}

// =============================================================================
// SECTION 13 — CHAT INPUT
// =============================================================================
class _ChatInput extends StatelessWidget {
  final TextEditingController ctrl;
  final VoidCallback onSend;
  final double bottomPad;
  final bool enabled;

  const _ChatInput({
    required this.ctrl,
    required this.onSend,
    required this.bottomPad,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    // Single clean bar on the white sheet — one rounded pill, no nested boxes.
    return Container(
      padding: EdgeInsets.fromLTRB(14, 10, 14, bottomPad + 12),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(
          top: BorderSide(color: AppColors.cardBorder, width: 1),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _AnimatedSendButton(onSend: onSend, enabled: enabled),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              constraints: const BoxConstraints(minHeight: 56),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: AppColors.cardBorder, width: 1.2),
              ),
              child: TextField(
                controller: ctrl,
                enabled: enabled,
                textAlign: TextAlign.start,
                minLines: 1,
                maxLines: 4,
                onSubmitted: (_) {
                  if (enabled) onSend();
                },
                inputFormatters: [
                  LengthLimitingTextInputFormatter(500),
                ],
                style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 14,
                  color: AppColors.darkText,
                ),
                decoration: InputDecoration(
                  isDense: true,
                  hintText: enabled
                      ? l10n.messagePlaceholder
                      : _chatMutedByAdminMessage,
                  hintStyle: const TextStyle(
                    fontFamily: 'Tajawal',
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 13,
                  ),
                ),
              ),
                ),
              ),
            ],
          ),
    );
  }
}

// =============================================================================
// SECTION 13a — ANIMATED SEND BUTTON
//
// Solid brand-green circle with a white send glyph. Wrapped in a tactile
// "press-pop" scale animation (shrink on press, spring back) so sending a
// message feels responsive.
// =============================================================================
class _AnimatedSendButton extends StatefulWidget {
  final VoidCallback onSend;
  final bool enabled;

  const _AnimatedSendButton({required this.onSend, required this.enabled});

  @override
  State<_AnimatedSendButton> createState() => _AnimatedSendButtonState();
}

class _AnimatedSendButtonState extends State<_AnimatedSendButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 130),
  );

  late final Animation<double> _scale = Tween<double>(
    begin: 1.0,
    end: 0.82,
  ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTap() {
    // Satisfying pop: shrink, then spring back to full size.
    _controller.forward().then((_) {
      if (mounted) _controller.reverse();
    });
    widget.onSend();
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.enabled;
    return GestureDetector(
      onTap: enabled ? _handleTap : null,
      child: ScaleTransition(
        scale: _scale,
        child: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: enabled ? AppColors.primary : AppColors.disabledBtn,
            shape: BoxShape.circle,
            boxShadow: enabled
                ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.40),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: const Icon(
            LucideIcons.send,
            color: AppColors.white,
            size: 19,
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// SECTION 13b — ROOM BACKGROUND
//
// Renders the live room's backdrop from the room's background customization:
//   • none  → nothing; the flat brand-green Scaffold colour shows through.
//   • url/file → the configured image, full-bleed, under a low-opacity green
//     scrim (top→bottom gradient) so the white text and the attendee grid stay
//     perfectly readable over any image. A failed load falls back to flat green.
// =============================================================================
class _RoomBackground extends StatelessWidget {
  final RoomDetailModel room;
  const _RoomBackground({required this.room});

  @override
  Widget build(BuildContext context) {
    if (!room.hasBackgroundImage) return const SizedBox.shrink();

    return Stack(
      fit: StackFit.expand,
      children: [
        Image.network(
          room.backgroundUrl,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
        ),
        // Readability scrim — brand-green, darker at the edges where the
        // controls and headcount sit, lighter through the middle grid.
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: const [0.0, 0.5, 1.0],
              colors: [
                AppColors.primaryDark.withValues(alpha: 0.62),
                AppColors.primary.withValues(alpha: 0.52),
                AppColors.primaryDark.withValues(alpha: 0.74),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// SECTION 14 — LIVE ROOM VIEW
// Wraps the Scaffold in BlocListeners for moderation side effects and live
// floating chat previews.
// =============================================================================
class _LiveRoomView extends StatefulWidget {
  final RoomDetailModel room;
  final RoomState state;
  final RoomCubit cubit;

  const _LiveRoomView({
    required this.room,
    required this.state,
    required this.cubit,
  });

  @override
  State<_LiveRoomView> createState() => _LiveRoomViewState();
}

class _LiveRoomViewState extends State<_LiveRoomView> {
  Timer? _floatingTimer;
  ChatMessage? _activeFloatingMessage;

  @override
  void dispose() {
    _floatingTimer?.cancel();
    super.dispose();
  }

  void _showFloatingMessage(ChatMessage message) {
    _floatingTimer?.cancel();
    setState(() => _activeFloatingMessage = message);
    _floatingTimer = Timer(const Duration(seconds: 3), () {
      if (!mounted) return;
      setState(() => _activeFloatingMessage = null);
    });
  }

  void _clearFloatingMessage() {
    _floatingTimer?.cancel();
    _floatingTimer = null;
    if (_activeFloatingMessage == null || !mounted) return;
    setState(() => _activeFloatingMessage = null);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final top = MediaQuery.of(context).padding.top;
    final bot = MediaQuery.of(context).padding.bottom;
    final room = widget.room;
    final state = widget.state;
    final cubit = widget.cubit;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      // The live room is a dark brand-green surface — paint the Android system
      // nav bar the same green (light icons) so it blends with the page instead
      // of showing a black strip.
      value: const SystemUiOverlayStyle(
        systemNavigationBarColor:          AppColors.primary,
        systemNavigationBarIconBrightness: Brightness.light,
        systemNavigationBarDividerColor:   AppColors.primary,
        statusBarColor:                    Colors.transparent,
        statusBarIconBrightness:           Brightness.light,
      ),
      child: MultiBlocListener(
      listeners: [
        BlocListener<RoomCubit, RoomState>(
          listenWhen: (prev, curr) =>
              curr.pendingModeration != null &&
              curr.pendingModeration != prev.pendingModeration,
          listener: (ctx, s) async {
            final event = s.pendingModeration!;
            // Clear immediately so a rapid second event doesn't replay this dialog.
            ctx.read<RoomCubit>().clearModeration();

            await showDialog<void>(
              context: ctx,
              barrierDismissible: false,
              builder: (_) => _ModerationDialog(event: event),
            );

            // Audio was already torn down the instant the event arrived. Route
            // the evicted user to Home — go() replaces the stack so the room
            // page is disposed and RoomCubit.close() releases the Agora engine.
            if (ctx.mounted) ctx.go('/home');
          },
        ),
        BlocListener<RoomCubit, RoomState>(
          listenWhen: (prev, curr) {
            if (curr.view != RoomView.live) return false;
            if (!curr.floatingEnabled || curr.chatVisible) return false;
            if (curr.messages.length <= prev.messages.length) return false;

            final latest = curr.messages.last;
            if (latest.isSending) return false;
            return latest.userId != widget.cubit.currentUserId;
          },
          listener: (_, curr) => _showFloatingMessage(curr.messages.last),
        ),
        BlocListener<RoomCubit, RoomState>(
          listenWhen: (prev, curr) =>
              (!prev.chatVisible && curr.chatVisible) ||
              (prev.floatingEnabled && !curr.floatingEnabled),
          listener: (_, __) => _clearFloatingMessage(),
        ),
      ],
      child: Scaffold(
        // Flat brand-green backdrop — the base for the 'none' background type
        // and the tint that keeps text readable over an image background.
        backgroundColor: AppColors.primary,
        body: Stack(
          fit: StackFit.expand,
          children: [
            // ── [L0] Background ──────────────────────────────────────────
            // none → nothing (flat green shows through); url/file → full-bleed
            // image under a low-opacity green scrim for readability.
            Positioned.fill(child: _RoomBackground(room: room)),

            // ── [L1] Main content ────────────────────────────────────────
            Column(
              children: [
                SizedBox(height: top + 8),
                // Clears the audio-route button (top-start, 44px tall,
                // starting at top+12) with room to spare before the title.
                const SizedBox(height: 78),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    room.title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const _LivePulseDot(size: 8),
                      const SizedBox(width: 8),
                      Text(
                        l10n.liveNow,
                        style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _AttendeesGrid(
                      attendees: state.visibleAttendees(cubit.currentUserId),
                      onAttendeeTap: (p) =>
                          _showRoomUserProfileSheet(context, p, cubit),
                    ),
                  ),
                ),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.people_alt_rounded,
                        color: Colors.white, size: 18),
                    const SizedBox(width: 6),
                    // Live headcount: WS-driven base count minus ghost-moded
                    // moderators, so a hidden admin reads as absent on every
                    // client. Rebuilds on both count broadcasts (statusCubit)
                    // and visibility changes (parent RoomState rebuild).
                    Text(
                      l10n.attendeesNow(
                        state.displayCount(
                          state.participantCount,
                          cubit.currentUserId,
                        ),
                      ),
                      style: const TextStyle(
                        fontFamily: 'Tajawal',
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Agora connection status after the room is already active.
                if (state.audioErrorMessage != null)
                  Text(
                    state.audioErrorMessage!,
                    style: const TextStyle(
                      fontFamily: 'Tajawal',
                      fontSize: 14,
                      color: Colors.red,
                    ),
                    textAlign: TextAlign.center,
                  ),

                const SizedBox(height: 24),

                // Controls — LTR-pinned so positions are locale-independent
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Directionality(
                    textDirection: TextDirection.ltr,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _ControlBtn(
                          icon: LucideIcons.logOut,
                          onTap: cubit.leaveRoom,
                        ),
                        _MicButton(
                          isMuted: state.isMuted,
                          onTap: cubit.toggleMute,
                        ),
                        // Ghost-mode toggle — moderators only, right next to
                        // the mic. Eye = visible, eye-off = hidden from grid.
                        if (cubit.isModerator)
                          _ControlBtn(
                            icon: state.isGhostMode
                                ? LucideIcons.eyeOff
                                : LucideIcons.eye,
                            isActive: state.isGhostMode,
                            onTap: () {
                              final goingHidden = !state.isGhostMode;
                              cubit.toggleGhostMode();
                              ScaffoldMessenger.of(context)
                                ..hideCurrentSnackBar()
                                ..showSnackBar(SnackBar(
                                  behavior: SnackBarBehavior.floating,
                                  backgroundColor: AppColors.roomOverlay,
                                  content: Text(
                                    goingHidden
                                        ? l10n.ghostModeEnabled
                                        : l10n.ghostModeDisabled,
                                    style: const TextStyle(
                                      fontFamily: 'Cairo',
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.white,
                                    ),
                                  ),
                                ));
                            },
                          ),
                        _ControlBtn(
                          icon: LucideIcons.messageCircle,
                          onTap: cubit.toggleChat,
                          badgeCount: state.unreadCount,
                          size: 64,
                        ),
                      ],
                    ),
                  ),
                ),

                SizedBox(height: bot + 16),
              ],
            ),

            // ── [L1b] Audio route selector — top header bar ──────────────
            // PositionedDirectional resolves `start` from the active locale:
            // Arabic (RTL) → top-RIGHT, English (LTR) → top-LEFT. No
            // hardcoded sides — the layout flips with the language.
            PositionedDirectional(
              top: top + 12,
              start: 16,
              child: GestureDetector(
                onTap: () => _showAudioRouteSheet(context, cubit),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: AppColors.white.withValues(alpha: 0.20),
                      width: 1,
                    ),
                  ),
                  child: Icon(
                    state.isSpeakerphoneOn
                        ? LucideIcons.volume2
                        : LucideIcons.phone,
                    color: AppColors.white,
                    size: 20,
                  ),
                ),
              ),
            ),

            // ── [L2] Floating message overlay ────────────────────────────
            // Driven by the BlocListener above; visible only while the chat
            // sheet is closed and floating previews are enabled. Aligned to the
            // reading-start edge (right in Arabic) as a chat-style card with the
            // sender's avatar + name.
            Positioned(
              bottom: bot + 96,
              left: 14,
              right: 14,
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: _FloatingMessagePreview(
                  message: _activeFloatingMessage,
                ),
              ),
            ),

            // ── [L3] TikTok chat overlay ─────────────────────────────────
            Positioned(
              bottom: 0,
              right: 0,
              left: 0,
              child: _TikTokChatOverlay(
                visible: state.chatVisible,
                onClose: cubit.hideChat,
                cubit: cubit,
              ),
            ),
          ],
        ),
      ),
    ),
    );
  }
}

// =============================================================================
// SECTION 15 — ATTENDEES GRID  (live view)
//
// One responsive, scrollable grid for EVERYONE in the room — speakers and
// listeners together. Broadcasters carry the mic badge on their avatar;
// there is no separate listeners section. Tiles are tappable and open the
// per-user options sheet (view profile / report).
// =============================================================================
class _AttendeesGrid extends StatelessWidget {
  final List<ParticipantModel> attendees;
  final ValueChanged<ParticipantModel>? onAttendeeTap;

  const _AttendeesGrid({required this.attendees, this.onAttendeeTap});

  @override
  Widget build(BuildContext context) {
    if (attendees.isEmpty) return const SizedBox.shrink();

    if (attendees.length == 1) {
      final p = attendees.single;
      return Center(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onAttendeeTap == null ? null : () => onAttendeeTap!(p),
          child: _MainAttendeeAvatar(p: p),
        ),
      );
    }

    // Vertically centre the participants within the available viewport. When
    // the grid is shorter than the viewport, the ConstrainedBox forces the
    // Column to fill it so MainAxisAlignment.center can centre the tiles; when
    // there are enough participants to overflow, the grid grows past minHeight
    // and the SingleChildScrollView takes over the scrolling.
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 104, // ~3-4 columns on phones, more on tablets
                    mainAxisExtent: 122, // avatar ring (86) + gap + name line
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 18,
                  ),
                  itemCount: attendees.length,
                  itemBuilder: (_, i) {
                    final p = attendees[i];
                    // Keyed by participant id so a NEW joiner's tile mounts once
                    // and slides/fades in, while existing tiles never re-animate.
                    return _TileAppear(
                      key: ValueKey(p.id),
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: onAttendeeTap == null
                            ? null
                            : () => onAttendeeTap!(p),
                        child: _AttendeeAvatar(p: p, isLive: true),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// Fade + gentle scale-in run once when a grid tile first mounts (i.e. when a
// participant joins), so new members slide in smoothly instead of popping.
class _TileAppear extends StatefulWidget {
  final Widget child;
  const _TileAppear({super.key, required this.child});

  @override
  State<_TileAppear> createState() => _TileAppearState();
}

class _TileAppearState extends State<_TileAppear>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  )..forward();

  late final Animation<double> _fade =
      CurvedAnimation(parent: _c, curve: Curves.easeOut);
  late final Animation<double> _scale = Tween<double>(begin: 0.72, end: 1.0)
      .animate(CurvedAnimation(parent: _c, curve: Curves.easeOutBack));

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
        opacity: _fade,
        child: ScaleTransition(scale: _scale, child: widget.child),
      );
}

class _MainAttendeeAvatar extends StatelessWidget {
  final ParticipantModel p;
  const _MainAttendeeAvatar({required this.p});

  Widget _mainAvatarImage(ParticipantModel p) => SizedBox(
        width: 116,
        height: 116,
        child: ClipOval(
          child: _avatarWithInitials(
            p.avatarUrl,
            p.name,
            diameter: 116,
            fontSize: 40,
            bg: AppColors.primaryLight.withValues(alpha: 0.55),
            fg: AppColors.white,
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 132,
          height: 132,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: AppColors.white.withValues(alpha: 0.72),
              width: 2.4,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.black.withValues(alpha: 0.18),
                blurRadius: 28,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: p.isSpeaking
              ? _PulsingRing(
                  size: 132,
                  color: AppColors.primaryLight,
                  child: _mainAvatarImage(p),
                )
              : _mainAvatarImage(p),
        ),
        const SizedBox(height: 14),
        Text(
          p.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontFamily: 'Cairo',
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AppColors.white,
          ),
        ),
        if (p.isModerator) ...[
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              AppLocalizations.of(context)!.moderatorBadge,
              style: const TextStyle(
                fontFamily: 'Cairo',
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// =============================================================================
// SECTION 15b — ROOM USER PROFILE SHEET  (grid/chat avatar tap)
//
// Dark, rounded-top modal with user info, profile/report actions, and
// moderator-only live room tools.
// =============================================================================
ParticipantModel _participantFromMessage(ChatMessage message) =>
    ParticipantModel.fromJson({
      'id': message.userId,
      'name': message.senderName,
      'avatarUrl': message.senderAvatar,
      'role': message.senderRole,
    });

void _showRoomUserProfileSheet(
  BuildContext context,
  ParticipantModel participant,
  RoomCubit cubit,
) {
  // Tapping your own avatar must never open the report/moderation sheet — it is
  // strictly for acting on OTHER users.
  if (participant.id == cubit.currentUserId) return;

  // Admin/moderator tiles carry a synthetic (Agora-uid) id, not a real user id,
  // and are never reportable/bannable — tapping one is a no-op instead of
  // firing a doomed GET /users/{hugeUid} that would 404.
  if (participant.isModerator) return;

  final userId = int.tryParse(participant.id);
  final roomId = cubit.state.roomDetail?.id;

  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (sheetCtx) => _RoomUserProfileSheet(
      participant: participant,
      canModerate: cubit.isModerator && userId != null,
      onViewProfile: userId == null
          ? null
          : () {
              Navigator.of(sheetCtx).pop();
              showUserProfileSheet(context, userId: userId, roomId: roomId);
            },
      // Admins/moderators are not reportable from the room sheet.
      onReport: (userId == null || participant.isModerator)
          ? null
          : () {
              Navigator.of(sheetCtx).pop();
              showReportUserSheet(context, userId: userId, roomId: roomId);
            },
      onMuteChat: userId == null
          ? null
          : () async {
              Navigator.of(sheetCtx).pop();
              await cubit.muteUserFromChat(participant.id);
            },
      onTempBan: userId == null
          ? null
          : () async {
              final minutes = await _askTempBanDuration(context);
              if (minutes == null) return;
              if (sheetCtx.mounted) Navigator.of(sheetCtx).pop();
              await cubit.tempBanUser(participant.id, minutes);
            },
      onGlobalBan: userId == null
          ? null
          : () async {
              final confirmed = await _confirmGlobalBan(context);
              if (!confirmed) return;
              if (sheetCtx.mounted) Navigator.of(sheetCtx).pop();
              await cubit.globalBanUser(participant.id);
            },
    ),
  );
}

class _RoomUserProfileSheet extends StatelessWidget {
  final ParticipantModel participant;
  final bool canModerate;
  final VoidCallback? onViewProfile;
  final VoidCallback? onReport;
  final VoidCallback? onMuteChat;
  final VoidCallback? onTempBan;
  final VoidCallback? onGlobalBan;

  const _RoomUserProfileSheet({
    required this.participant,
    required this.canModerate,
    required this.onViewProfile,
    required this.onReport,
    required this.onMuteChat,
    required this.onTempBan,
    required this.onGlobalBan,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return Container(
      decoration: const BoxDecoration(
        // White sheet — the room behind it is already green, so a green/dark
        // sheet washes out. Content inside reads in green / dark.
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(20, 12, 20, bottomPad + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 38,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.cardBorder,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 18),

          // Tapped user header — avatar + name (+ moderator tag)
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.avatarBg,
                  border: Border.all(
                    color: AppColors.cardBorder,
                    width: 1.4,
                  ),
                ),
                child: ClipOval(
                  child: _roomAvatarImage(
                    participant.avatarUrl,
                    fallback: const Icon(
                      LucideIcons.user,
                      size: 22,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      participant.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.darkText,
                      ),
                    ),
                    if (participant.isModerator)
                      Text(
                        l10n.moderatorBadge,
                        style: const TextStyle(
                          fontFamily: 'Tajawal',
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(
            color: AppColors.cardBorder,
            height: 1,
          ),
          const SizedBox(height: 8),

          if (onViewProfile != null)
            _SheetActionTile(
              icon: LucideIcons.userCircle2,
              label: l10n.viewProfile,
              color: AppColors.darkText,
              iconBg: AppColors.primary.withValues(alpha: 0.10),
              onTap: onViewProfile!,
            ),
          if (onReport != null)
            _SheetActionTile(
              icon: LucideIcons.flag,
              label: l10n.reportUser,
              color: AppColors.error,
              iconBg: AppColors.error.withValues(alpha: 0.16),
              onTap: onReport!,
            ),
          if (canModerate) ...[
            const SizedBox(height: 10),
            const Divider(
              color: AppColors.cardBorder,
              height: 1,
            ),
            const SizedBox(height: 14),
            const Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                'أدوات الإدارة',
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                ),
              ),
            ),
            const SizedBox(height: 4),
            if (onMuteChat != null)
              _SheetActionTile(
                icon: Icons.voice_over_off_rounded,
                label: 'بلك من الشات',
                color: AppColors.darkText,
                iconBg: AppColors.primary.withValues(alpha: 0.10),
                onTap: onMuteChat!,
              ),
            if (onTempBan != null)
              _SheetActionTile(
                icon: Icons.timer_off_rounded,
                label: 'طرد مؤقت',
                color: AppColors.warning,
                iconBg: AppColors.warning.withValues(alpha: 0.16),
                onTap: onTempBan!,
              ),
            if (onGlobalBan != null)
              _SheetActionTile(
                icon: Icons.block_rounded,
                label: 'حظر من كل الرومات',
                color: AppColors.error,
                iconBg: AppColors.error.withValues(alpha: 0.16),
                onTap: onGlobalBan!,
              ),
          ],
        ],
      ),
    );
  }
}

Future<int?> _askTempBanDuration(BuildContext context) async {
  final ctrl = TextEditingController(text: '60');
  try {
    return showDialog<int>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text(
          'مدة الطرد المؤقت',
          textAlign: TextAlign.right,
          style: TextStyle(
            fontFamily: 'Cairo',
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: AppColors.darkText,
          ),
        ),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(
            suffixText: 'دقيقة',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('إلغاء', style: TextStyle(fontFamily: 'Cairo')),
          ),
          TextButton(
            onPressed: () {
              final value = int.tryParse(ctrl.text.trim());
              Navigator.of(dialogCtx)
                  .pop(value == null || value < 1 ? 60 : value);
            },
            child: const Text('تأكيد', style: TextStyle(fontFamily: 'Cairo')),
          ),
        ],
      ),
    );
  } finally {
    ctrl.dispose();
  }
}

Future<bool> _confirmGlobalBan(BuildContext context) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (dialogCtx) => AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: const Text(
        'تأكيد الحظر',
        textAlign: TextAlign.right,
        style: TextStyle(
          fontFamily: 'Cairo',
          fontSize: 17,
          fontWeight: FontWeight.w800,
          color: AppColors.darkText,
        ),
      ),
      content: const Text(
        'سيتم منع المستخدم من دخول كل الرومات الصوتية.',
        textAlign: TextAlign.right,
        style: TextStyle(
          fontFamily: 'Tajawal',
          fontSize: 14,
          color: AppColors.textSecondary,
          height: 1.5,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogCtx).pop(false),
          child: const Text('إلغاء', style: TextStyle(fontFamily: 'Cairo')),
        ),
        TextButton(
          onPressed: () => Navigator.of(dialogCtx).pop(true),
          child: const Text(
            'حظر',
            style: TextStyle(fontFamily: 'Cairo', color: AppColors.error),
          ),
        ),
      ],
    ),
  );
  return result ?? false;
}

/// Single dark-sheet action row — distinct icon chip + high-contrast label.
class _SheetActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Color iconBg;
  final VoidCallback onTap;
  final Widget? trailing;

  const _SheetActionTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.iconBg,
    required this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 19),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ),
              trailing ??
                  Icon(
                    LucideIcons.chevronLeft,
                    size: 18,
                    color: AppColors.textSecondary.withValues(alpha: 0.6),
                  ),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// SECTION 15c — AUDIO ROUTE SHEET  (loudspeaker ⇄ earpiece)
//
// Opened from the header button. Routes through
// AgoraService.toggleSpeakerphone → RtcEngine.setEnableSpeakerphone(bool).
// =============================================================================
void _showAudioRouteSheet(BuildContext context, RoomCubit cubit) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (sheetCtx) => BlocBuilder<RoomCubit, RoomState>(
      bloc: cubit,
      builder: (_, state) {
        final l10n = AppLocalizations.of(sheetCtx)!;
        final bottomPad = MediaQuery.of(sheetCtx).padding.bottom;

        return Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.fromLTRB(20, 12, 20, bottomPad + 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.cardBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 18),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  l10n.audioOutput,
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              _AudioRouteOption(
                icon: LucideIcons.volume2,
                label: l10n.loudspeaker,
                selected: state.isSpeakerphoneOn,
                onTap: () async {
                  await cubit.setSpeakerphone(true);
                  if (sheetCtx.mounted) Navigator.of(sheetCtx).pop();
                },
              ),
              _AudioRouteOption(
                icon: LucideIcons.phone,
                label: l10n.earpiece,
                selected: !state.isSpeakerphoneOn,
                onTap: () async {
                  await cubit.setSpeakerphone(false);
                  if (sheetCtx.mounted) Navigator.of(sheetCtx).pop();
                },
              ),
            ],
          ),
        );
      },
    ),
  );
}

class _AudioRouteOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _AudioRouteOption({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // White sheet: green for the selected route, muted grey for the other.
    return _SheetActionTile(
      icon: icon,
      label: label,
      color: selected ? AppColors.primary : AppColors.textSecondary,
      iconBg: selected
          ? AppColors.primary.withValues(alpha: 0.12)
          : AppColors.cardBorder.withValues(alpha: 0.45),
      onTap: onTap,
      trailing: selected
          ? const Icon(
              LucideIcons.checkCircle2,
              size: 19,
              color: AppColors.primary,
            )
          : const SizedBox(width: 19),
    );
  }
}

// =============================================================================
// SECTION 16 — MIC BUTTON
// =============================================================================
class _MicButton extends StatefulWidget {
  final bool isMuted;
  final VoidCallback onTap;
  const _MicButton({required this.isMuted, required this.onTap});

  @override
  State<_MicButton> createState() => _MicButtonState();
}

class _MicButtonState extends State<_MicButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 110),
      lowerBound: 0.88,
      upperBound: 1.0,
    )..value = 1.0;
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _tap() async {
    await _ctrl.reverse();
    await _ctrl.forward();
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _ctrl,
      child: GestureDetector(
        onTap: _tap,
        child: Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: widget.isMuted
                ? Colors.white.withValues(alpha: 0.15)
                : Colors.white,
            shape: BoxShape.circle,
          ),
          child: Icon(
            widget.isMuted ? LucideIcons.micOff : LucideIcons.mic,
            color: widget.isMuted ? Colors.white : AppColors.primary,
            size: 30,
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// SECTION 17 — CONTROL BUTTON
//
// [badgeCount] — unread indicator. Strict rule: renders NOTHING when 0
// (SizedBox.shrink); shows the exact count when ≥ 1 (99+ cap).
// =============================================================================
class _ControlBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final int badgeCount;
  final double size;

  /// Highlighted state (e.g. ghost mode ON) — gold fill, dark icon.
  final bool isActive;

  const _ControlBtn({
    required this.icon,
    required this.onTap,
    this.badgeCount = 0,
    this.isActive = false,
    this.size = 52,
  });

  @override
  Widget build(BuildContext context) {
    final iconSize = size * (22 / 52);
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: isActive
                  ? AppColors.white
                  : Colors.white.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon,
                color: isActive ? AppColors.primary : Colors.white,
                size: iconSize),
          ),
          // Badge sits inset over the circle's corner (not hanging past its
          // edge) so it reads as one control with an accent, not two shapes.
          // White chip + green count — matches the room's green/white palette.
          Positioned(
            right: 2,
            top: 2,
            child: badgeCount <= 0
                ? const SizedBox.shrink()
                : Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    constraints:
                        const BoxConstraints(minWidth: 18, minHeight: 18),
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(color: AppColors.primary, width: 1.4),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      badgeCount > 99 ? '99+' : '$badgeCount',
                      style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                        height: 1.0,
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// SECTION 18 — ROOT PAGE
// =============================================================================
class RoomDetailsPage extends StatefulWidget {
  final String roomId;
  const RoomDetailsPage({super.key, required this.roomId});

  @override
  State<RoomDetailsPage> createState() => _RoomDetailsPageState();
}

class _RoomDetailsPageState extends State<RoomDetailsPage> {
  bool _joiningDialogVisible = false;

  void _showJoiningDialog(BuildContext context) {
    if (_joiningDialogVisible) return;
    _joiningDialogVisible = true;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: AppColors.black.withValues(alpha: 0.28),
      builder: (_) => const _JoiningRoomDialog(),
    );
  }

  void _hideJoiningDialog(BuildContext context) {
    if (!_joiningDialogVisible) return;
    _joiningDialogVisible = false;
    Navigator.of(context, rootNavigator: true).pop();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (ctx) => RoomCubit(
        roomId: widget.roomId,
        statusCubit: ctx.read<RoomStatusCubit>(),
      ),
      child: BlocConsumer<RoomCubit, RoomState>(
        listenWhen: (prev, curr) =>
            prev.isConnectingAudio != curr.isConnectingAudio ||
            prev.view != curr.view ||
            curr.entryDeniedMessage != prev.entryDeniedMessage ||
            curr.audioErrorMessage != prev.audioErrorMessage ||
            curr.chatNoticeMessage != prev.chatNoticeMessage,
        listener: (ctx, s) {
          if (s.isConnectingAudio) {
            _showJoiningDialog(ctx);
          } else {
            _hideJoiningDialog(ctx);
          }

          if (s.chatNoticeMessage != null && s.chatNoticeMessage!.isNotEmpty) {
            ScaffoldMessenger.of(ctx)
              ..hideCurrentSnackBar()
              ..showSnackBar(SnackBar(
                behavior: SnackBarBehavior.floating,
                backgroundColor: AppColors.roomOverlay,
                content: Text(
                  s.chatNoticeMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.white,
                  ),
                ),
              ));
            ctx.read<RoomCubit>().clearChatNotice();
          }

          if (s.audioErrorMessage != null &&
              s.audioErrorMessage!.isNotEmpty &&
              s.view == RoomView.detail) {
            ScaffoldMessenger.of(ctx)
              ..hideCurrentSnackBar()
              ..showSnackBar(SnackBar(
                behavior: SnackBarBehavior.floating,
                backgroundColor: AppColors.error,
                content: Text(
                  s.audioErrorMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.white,
                  ),
                ),
              ));
          }

          if (s.entryDeniedMessage == null) return;
          final l10n = AppLocalizations.of(ctx)!;
          final text =
              (s.entryDeniedMessage != null && s.entryDeniedMessage!.isNotEmpty)
                  ? s.entryDeniedMessage!
                  : l10n.roomFull;
          ctx.read<RoomCubit>().clearEntryDenied();
          // Shown on the app-root ScaffoldMessenger so it survives the pop.
          ScaffoldMessenger.of(ctx)
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(
              behavior: SnackBarBehavior.floating,
              backgroundColor: AppColors.error,
              content: Text(
                text,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.white,
                ),
              ),
            ));
          if (ctx.canPop()) ctx.pop();
        },
        builder: (context, state) {
          final cubit = context.read<RoomCubit>();

          if (state.isLoading) {
            return const Scaffold(
              backgroundColor: AppColors.background,
              body: Center(
                child: MubtaathLoader(
                  color: AppColors.primary,
                  strokeWidth: 2.5,
                ),
              ),
            );
          }

          if (state.hasError || state.roomDetail == null) {
            return Scaffold(
              backgroundColor: AppColors.background,
              body: Center(
                child: Text(
                  AppLocalizations.of(context)!.genericError,
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 16,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            );
          }

          return AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, anim) =>
                FadeTransition(opacity: anim, child: child),
            child: state.view == RoomView.detail
                ? KeyedSubtree(
                    key: const ValueKey('detail'),
                    child: _RoomDetailView(
                      room: state.roomDetail!,
                      state: state,
                      cubit: cubit,
                    ),
                  )
                : KeyedSubtree(
                    key: const ValueKey('live'),
                    child: _LiveRoomView(
                      room: state.roomDetail!,
                      state: state,
                      cubit: cubit,
                    ),
                  ),
          );
        },
      ),
    );
  }
}

class _JoiningRoomDialog extends StatelessWidget {
  const _JoiningRoomDialog();

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Material(
        type: MaterialType.transparency,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Center(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 32),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 26),
              decoration: BoxDecoration(
                color: AppColors.surface.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: AppColors.white.withValues(alpha: 0.50),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.black.withValues(alpha: 0.16),
                    blurRadius: 36,
                    offset: const Offset(0, 14),
                  ),
                ],
              ),
              child: const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  MubtaathLoader(
                    color: AppColors.primary,
                    strokeWidth: 2.8,
                  ),
                  SizedBox(height: 18),
                  Text(
                    _joiningRoomMessage,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.darkText,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

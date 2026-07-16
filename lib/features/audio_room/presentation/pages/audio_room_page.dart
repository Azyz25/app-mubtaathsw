import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:mubtaath/core/l10n/app_localizations.dart';
import 'package:mubtaath/core/theme/app_colors.dart';
import 'package:mubtaath/core/widgets/mubtaath_loader.dart';
import 'package:mubtaath/features/audio_room/presentation/cubit/audio_room_cubit.dart';
import 'package:mubtaath/features/audio_room/presentation/cubit/audio_room_state.dart';
import 'package:mubtaath/features/audio_room/presentation/widgets/speaker_tile.dart';
import 'package:mubtaath/features/reports/presentation/widgets/user_profile_sheet.dart';

// ─────────────────────────────────────────────────────────────────────────────
// AudioRoomPage
//
// Navigate to this page with just the room UUID:
//   context.push('/audio-room/$channelId');
//
// The cubit handles the full join flow:
//   POST /api/rooms/{id}/join  →  POST /api/agora/token  →  RtcEngine.joinChannel
// No token needs to be fetched or passed from the caller.
// ─────────────────────────────────────────────────────────────────────────────

class AudioRoomPage extends StatefulWidget {
  final String channelId;

  const AudioRoomPage({
    super.key,
    required this.channelId,
  });

  @override
  State<AudioRoomPage> createState() => _AudioRoomPageState();
}

class _AudioRoomPageState extends State<AudioRoomPage> {
  @override
  void initState() {
    super.initState();
    _requestPermissionAndJoin();
  }

  Future<void> _requestPermissionAndJoin() async {
    final status = await Permission.microphone.request();
    if (!mounted) return;

    if (status.isGranted) {
      context.read<AudioRoomCubit>().joinRoom(channelId: widget.channelId);
    } else {
      _showPermissionDeniedSnack();
    }
  }

  void _showPermissionDeniedSnack() {
    final l10n = AppLocalizations.of(context)!;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          l10n.microphonePermissionRequired,
          style: const TextStyle(fontFamily: 'Tajawal', color: Colors.white),
        ),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        action: SnackBarAction(
          label: AppLocalizations.of(context)!.openSettings,
          textColor: Colors.white,
          onPressed: openAppSettings,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AudioRoomCubit, AudioRoomState>(
      builder: (context, state) {
        final cubit = context.read<AudioRoomCubit>();
        final l10n = AppLocalizations.of(context)!;

        return Scaffold(
          backgroundColor: AppColors.primary,
          body: Stack(
            fit: StackFit.expand,
            children: [
              _buildMainContent(context, state, cubit, l10n),
              _buildTopBar(context, state, cubit, l10n),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTopBar(
    BuildContext context,
    AudioRoomState state,
    AudioRoomCubit cubit,
    AppLocalizations l10n,
  ) {
    final top = MediaQuery.of(context).padding.top;

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: EdgeInsets.fromLTRB(16, top + 12, 16, 12),
        child: Row(
          children: [
            // Back / leave
            GestureDetector(
              onTap: () async {
                await cubit.leaveRoom();
                if (context.mounted) context.pop();
              },
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  LucideIcons.arrowRight,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),

            const Spacer(),

            // Channel name
            Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.channelId,
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                _StatusBadge(status: state.status, l10n: l10n),
              ],
            ),

            const Spacer(),

            // Audio output toggle — locale-aware trailing position.
            // Ambient Directionality places this naturally opposite the back
            // button: RIGHT side in LTR (English), LEFT side in RTL (Arabic).
            _AudioOutputButton(state: state, cubit: cubit, l10n: l10n),
          ],
        ),
      ),
    );
  }

  Widget _buildMainContent(
    BuildContext context,
    AudioRoomState state,
    AudioRoomCubit cubit,
    AppLocalizations l10n,
  ) {
    final top = MediaQuery.of(context).padding.top + 80;
    final bot = MediaQuery.of(context).padding.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(24, top, 24, bot + 16),
      child: Column(
        children: [
          const SizedBox(height: 24),

          // ── Connectivity warning (Agora SDK failed to initialise) ─────
          if (state.status == AudioRoomStatus.warning)
            _ConnectivityWarningBanner(
              onRetry: () => _requestPermissionAndJoin(),
              l10n: l10n,
            ),

          // ── Error banner (network / server errors) ────────────────────
          if (state.status == AudioRoomStatus.error)
            _ErrorBanner(
              message: l10n.audioConnectionError,
              onRetry: () => _requestPermissionAndJoin(),
            ),

          // ── Participants label ────────────────────────────────────────
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              l10n.participants,
              style: const TextStyle(
                fontFamily: 'Cairo',
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.white70,
              ),
            ),
          ),

          const SizedBox(height: 16),

          // ── Participants grid or empty state ──────────────────────────
          Expanded(
            child: state.remoteUids.isEmpty
                ? _EmptyParticipants(
                    isConnecting: state.status == AudioRoomStatus.connecting,
                    l10n: l10n,
                  )
                : Wrap(
                    spacing: 20,
                    runSpacing: 24,
                    alignment: WrapAlignment.center,
                    children: state.remoteUids
                        .map((uid) => GestureDetector(
                              onTap: () => showUserProfileSheet(
                                context,
                                userId: uid,
                                roomId: widget.channelId,
                              ),
                              child: SpeakerTile(uid: uid),
                            ))
                        .toList(),
                  ),
          ),

          // ── Controls ──────────────────────────────────────────────────
          _ControlsBar(
            state: state,
            cubit: cubit,
            l10n: l10n,
            onLeave: () async {
              await cubit.leaveRoom();
              if (context.mounted) context.pop();
            },
          ),

          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sub-widgets
// ─────────────────────────────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  final AudioRoomStatus status;
  final AppLocalizations l10n;

  const _StatusBadge({required this.status, required this.l10n});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      AudioRoomStatus.idle      => ('—', Colors.white38),
      AudioRoomStatus.connecting => (l10n.connecting, AppColors.warning),
      AudioRoomStatus.connected  => (l10n.connected, AppColors.success),
      AudioRoomStatus.warning    => (l10n.agoraConnectivityWarning, AppColors.warning),
      AudioRoomStatus.error      => (l10n.audioConnectionError, AppColors.error),
    };

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(
            fontFamily: 'Tajawal',
            fontSize: 12,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _EmptyParticipants extends StatelessWidget {
  final bool isConnecting;
  final AppLocalizations l10n;

  const _EmptyParticipants({
    required this.isConnecting,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isConnecting)
            const MubtaathLoader(
              color: Colors.white54,
              strokeWidth: 2.5,
            )
          else
            Icon(
              LucideIcons.users,
              size: 48,
              color: Colors.white.withValues(alpha: 0.25),
            ),
          const SizedBox(height: 16),
          Text(
            isConnecting ? l10n.connecting : l10n.noParticipantsYet,
            style: TextStyle(
              fontFamily: 'Tajawal',
              fontSize: 15,
              color: Colors.white.withValues(alpha: 0.55),
            ),
          ),
        ],
      ),
    );
  }
}

class _ConnectivityWarningBanner extends StatelessWidget {
  final VoidCallback onRetry;
  final AppLocalizations l10n;

  const _ConnectivityWarningBanner({
    required this.onRetry,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.55)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 1),
            child: Icon(LucideIcons.wifiOff, color: AppColors.warning, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.agoraConnectivityWarning,
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  l10n.agoraConnectivityWarningBody,
                  style: TextStyle(
                    fontFamily: 'Tajawal',
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.75),
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: onRetry,
            child: const Icon(LucideIcons.refreshCw,
                color: Colors.white70, size: 18),
          ),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorBanner({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.20),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.50)),
      ),
      child: Row(
        children: [
          const Icon(LucideIcons.alertCircle, color: AppColors.error, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontFamily: 'Tajawal',
                fontSize: 13,
                color: Colors.white,
              ),
            ),
          ),
          GestureDetector(
            onTap: onRetry,
            child: const Icon(LucideIcons.refreshCw,
                color: Colors.white70, size: 18),
          ),
        ],
      ),
    );
  }
}

class _ControlsBar extends StatelessWidget {
  final AudioRoomState state;
  final AudioRoomCubit cubit;
  final AppLocalizations l10n;
  final VoidCallback onLeave;

  const _ControlsBar({
    required this.state,
    required this.cubit,
    required this.l10n,
    required this.onLeave,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = state.status == AudioRoomStatus.connected;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Mic hint
        if (isActive && state.isMuted)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              l10n.tapMicToSpeak,
              style: TextStyle(
                fontFamily: 'Tajawal',
                fontSize: 13,
                color: Colors.white.withValues(alpha: 0.55),
              ),
            ),
          ),

        // Buttons row — LTR forced so positions are locale-independent
        Directionality(
          textDirection: TextDirection.ltr,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Leave room
              _RoundBtn(
                icon: LucideIcons.logOut,
                label: l10n.leaveRoom,
                color: AppColors.error,
                onTap: onLeave,
              ),

              // Mic toggle
              _MicBtn(
                isMuted: state.isMuted,
                enabled: isActive,
                onTap: isActive ? cubit.toggleMic : null,
              ),

              // Placeholder for future actions (invite, reactions, …)
              _RoundBtn(
                icon: LucideIcons.userPlus,
                label: l10n.participants,
                color: Colors.white24,
                onTap: null,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MicBtn extends StatelessWidget {
  final bool isMuted;
  final bool enabled;
  final VoidCallback? onTap;

  const _MicBtn({
    required this.isMuted,
    required this.enabled,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isMuted
              ? Colors.white.withValues(alpha: 0.15)
              : Colors.white,
        ),
        child: Icon(
          isMuted ? LucideIcons.micOff : LucideIcons.mic,
          color: isMuted ? Colors.white54 : AppColors.primary,
          size: 28,
        ),
      ),
    );
  }
}

class _RoundBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  const _RoundBtn({
    required this.icon,
    required this.label,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Tajawal',
              fontSize: 11,
              color: Colors.white.withValues(alpha: 0.65),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Audio output picker — header trailing action
//
// Placement relies entirely on ambient Directionality (inherited from
// MaterialApp locale):
//   • Arabic  (RTL) → Row renders right-to-left → this widget is on the LEFT
//   • English (LTR) → Row renders left-to-right  → this widget is on the RIGHT
//
// Either side is the correct "trailing / action" position for its locale.
// ─────────────────────────────────────────────────────────────────────────────

class _AudioOutputButton extends StatelessWidget {
  final AudioRoomState state;
  final AudioRoomCubit cubit;
  final AppLocalizations l10n;

  const _AudioOutputButton({
    required this.state,
    required this.cubit,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    final isSpeaker = state.isSpeakerPhoneEnabled;

    return PopupMenuButton<bool>(
      onSelected: cubit.setSpeakerphone,
      tooltip: l10n.audioOutput,
      color: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 6,
      itemBuilder: (_) => [
        PopupMenuItem(
          value: true,
          child: _AudioOutputOption(
            icon: LucideIcons.volume2,
            label: l10n.audioOutputSpeaker,
            isActive: isSpeaker,
          ),
        ),
        PopupMenuItem(
          value: false,
          child: _AudioOutputOption(
            icon: LucideIcons.headphones,
            label: l10n.audioOutputEarpiece,
            isActive: !isSpeaker,
          ),
        ),
      ],
      // The trigger button — matches the back button style exactly.
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          isSpeaker ? LucideIcons.volume2 : LucideIcons.headphones,
          color: Colors.white,
          size: 20,
        ),
      ),
    );
  }
}

class _AudioOutputOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;

  const _AudioOutputOption({
    required this.icon,
    required this.label,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    final color = isActive ? AppColors.primary : AppColors.textSecondary;

    return Row(
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 10),
        Text(
          label,
          style: TextStyle(
            fontFamily: 'Cairo',
            fontSize: 14,
            fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
            color: isActive ? AppColors.primary : AppColors.textPrimary,
          ),
        ),
        if (isActive) ...[
          const Spacer(),
          const Icon(LucideIcons.check, color: AppColors.primary, size: 16),
        ],
      ],
    );
  }
}

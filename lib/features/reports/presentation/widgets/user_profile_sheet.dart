import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mubtaath/core/l10n/app_localizations.dart';
import 'package:mubtaath/core/theme/app_colors.dart';
import 'package:mubtaath/features/reports/presentation/cubit/user_profile_cubit.dart';
import 'package:mubtaath/features/reports/presentation/widgets/report_sheet.dart';

/// Shows a read-only profile bottom sheet for another user.
/// On "Report User" tap: closes profile sheet, then opens report sheet.
void showUserProfileSheet(
  BuildContext context, {
  required int userId,
  String? roomId,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetCtx) => BlocProvider(
      create: (_) => UserProfileCubit()..fetchUser(userId),
      child: _UserProfileSheet(
        userId: userId,
        onReport: () {
          Navigator.of(sheetCtx).pop();
          showReportUserSheet(context, userId: userId, roomId: roomId);
        },
      ),
    ),
  );
}

class _UserProfileSheet extends StatelessWidget {
  final int userId;
  final VoidCallback onReport;

  const _UserProfileSheet({
    required this.userId,
    required this.onReport,
  });

  @override
  Widget build(BuildContext context) {
    final l10n      = AppLocalizations.of(context)!;
    final bottomPad = MediaQuery.of(context).padding.bottom;
    final lang      = Localizations.localeOf(context).languageCode;

    return Container(
      decoration: const BoxDecoration(
        color:        AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(24, 0, 24, bottomPad + 24),
      child: BlocBuilder<UserProfileCubit, UserProfileState>(
        builder: (context, state) {
          final isLoading = state.status == UserProfileStatus.loading ||
              state.status == UserProfileStatus.initial;
          final showReport = !isLoading;

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Drag handle ──────────────────────────────────────────────
              const SizedBox(height: 12),
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color:        AppColors.cardBorder,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // ── Title ────────────────────────────────────────────────────
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  l10n.userProfile,
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize:   17,
                    fontWeight: FontWeight.w800,
                    color:      AppColors.darkText,
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // ── Body ─────────────────────────────────────────────────────
              if (isLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: CircularProgressIndicator(
                    color:       AppColors.primary,
                    strokeWidth: 2.5,
                  ),
                )
              else if (state.status == UserProfileStatus.error)
                _ErrorBody(
                  message: state.errorMessage ?? l10n.genericError,
                  userId:  userId,
                )
              else
                _ProfileBody(state: state, lang: lang),

              // ── Report button — shown once loading is done ───────────────
              if (showReport) ...[
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: onReport,
                    icon:  const Icon(LucideIcons.flag, size: 16),
                    label: Text(
                      l10n.reportUser,
                      style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontSize:   14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor:        AppColors.error,
                      foregroundColor:        AppColors.white,
                      padding:                const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Loaded state — avatar + name + username + country chip
// ─────────────────────────────────────────────────────────────────────────────
class _ProfileBody extends StatelessWidget {
  final UserProfileState state;
  final String lang;

  const _ProfileBody({required this.state, required this.lang});

  @override
  Widget build(BuildContext context) {
    final countryName = lang == 'ar'
        ? (state.countryNameAr ?? state.countryNameEn ?? '')
        : (state.countryNameEn ?? state.countryNameAr ?? '');
    final flag = state.countryFlag ?? '';

    return Column(
      children: [
        // Avatar
        Container(
          width: 84,
          height: 84,
          decoration: BoxDecoration(
            shape:  BoxShape.circle,
            color:  AppColors.avatarBg,
            border: Border.all(color: AppColors.cardBorder, width: 2),
          ),
          child: ClipOval(
            child: state.avatarUrl != null && state.avatarUrl!.isNotEmpty
                ? Image.network(
                    state.avatarUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.person,
                      color: AppColors.primary,
                      size: 42,
                    ),
                  )
                : const Icon(Icons.person, color: AppColors.primary, size: 42),
          ),
        ),
        const SizedBox(height: 12),

        // Full name
        Text(
          state.name ?? '—',
          style: const TextStyle(
            fontFamily: 'Cairo',
            fontSize:   18,
            fontWeight: FontWeight.w800,
            color:      AppColors.darkText,
          ),
        ),

        // Username
        if (state.username != null) ...[
          const SizedBox(height: 4),
          Text(
            '@${state.username}',
            style: const TextStyle(
              fontFamily: 'Tajawal',
              fontSize:   13,
              color:      AppColors.textSecondary,
            ),
          ),
        ],

        // Country chip
        if (countryName.isNotEmpty) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color:        AppColors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.cardBorder, width: 1.2),
            ),
            child: Text(
              flag.isNotEmpty ? '$flag  $countryName' : countryName,
              style: const TextStyle(
                fontFamily: 'Tajawal',
                fontSize:   13,
                color:      AppColors.darkText,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Error state — generic icon + UID fallback (report button still shown)
// ─────────────────────────────────────────────────────────────────────────────
class _ErrorBody extends StatelessWidget {
  final String message;
  final int    userId;

  const _ErrorBody({required this.message, required this.userId});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 84,
          height: 84,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.avatarBg,
          ),
          child: const Icon(Icons.person, color: AppColors.primary, size: 42),
        ),
        const SizedBox(height: 12),
        Text(
          'UID $userId',
          style: const TextStyle(
            fontFamily: 'Cairo',
            fontSize:   16,
            fontWeight: FontWeight.w700,
            color:      AppColors.darkText,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontFamily: 'Tajawal',
            fontSize:   13,
            color:      AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

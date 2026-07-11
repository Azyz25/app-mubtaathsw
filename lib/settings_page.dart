// =============================================================================
// MUBTAATH APP — SETTINGS PAGE  (Localized — ar/en)
// =============================================================================
// Language changes go through LanguageCubit (app-scoped, persisted).
// SettingsCubit is kept for local UI state (isLoggingOut).
// All hardcoded Arabic strings replaced with AppLocalizations keys.
// Directionality(rtl) wrappers removed — locale controls direction via
// GlobalWidgetsLocalizations injected in main.dart.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mubtaath/core/auth_notifier.dart';
import 'package:mubtaath/core/bloc/language_cubit.dart';
import 'package:mubtaath/core/services/dio_client.dart';
import 'package:mubtaath/core/services/secure_storage_service.dart';
import 'package:mubtaath/core/l10n/app_localizations.dart';
import 'package:mubtaath/core/theme/app_colors.dart';
import 'package:mubtaath/core/widgets/language_picker.dart';
import 'package:mubtaath/core/widgets/shared_widgets.dart';

// =============================================================================
// SECTION 1 — SETTINGS STATE
// =============================================================================

class SettingsState {
  final bool isLoggingOut;
  final bool isDeletingAccount;
  const SettingsState({
    this.isLoggingOut      = false,
    this.isDeletingAccount = false,
  });
  SettingsState copyWith({bool? isLoggingOut, bool? isDeletingAccount}) =>
      SettingsState(
        isLoggingOut:      isLoggingOut      ?? this.isLoggingOut,
        isDeletingAccount: isDeletingAccount ?? this.isDeletingAccount,
      );
}

// =============================================================================
// SECTION 2 — SETTINGS CUBIT
// =============================================================================

class SettingsCubit extends Cubit<SettingsState> {
  SettingsCubit() : super(const SettingsState());

  Future<void> logout() async {
    emit(state.copyWith(isLoggingOut: true));
    await SecureStorageService.clearAll();
  }

  /// Permanently deletes the user's own account (Apple Guideline 5.1.1).
  ///
  /// Calls DELETE /api/user/delete-account; on success the server has hard-
  /// deleted the account and revoked every token, so we wipe the local auth
  /// session too. Returns true on success so the caller can route to login,
  /// false on failure so it can surface an error and keep the user signed in.
  Future<bool> deleteUserAccount() async {
    emit(state.copyWith(isDeletingAccount: true));
    try {
      await appDio.delete('/user/delete-account');
      await SecureStorageService.clearAll();
      return true;
    } catch (_) {
      emit(state.copyWith(isDeletingAccount: false));
      return false;
    }
  }
}

// =============================================================================
// SECTION 3 — SETTINGS CARD WIDGET
// =============================================================================

class _SettingsCard extends StatelessWidget {
  final IconData      icon;
  final String        label;
  final String?       valueLabel;
  final VoidCallback? onTap;

  const _SettingsCard({
    required this.icon,
    required this.label,
    this.valueLabel,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        width: double.infinity,
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: 18, vertical: 18,
        ),
        decoration: BoxDecoration(
          color:        AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.cardBorder, width: 1.2),
        ),
        child: Row(
          children: [
            // Icon + label — leading side (right in RTL, left in LTR)
            Icon(icon, color: AppColors.primary, size: 22),
            const SizedBox(width: 10),
            Text(
              label,
              style: const TextStyle(
                fontFamily: 'Cairo',
                fontSize:   15,
                fontWeight: FontWeight.w700,
                color:      AppColors.darkText,
                height:     1.2,
              ),
            ),
            const Spacer(),
            // Value label — trailing side (left in RTL, right in LTR)
            if (valueLabel != null)
              Text(
                valueLabel!,
                style: const TextStyle(
                  fontFamily: 'Tajawal',
                  fontSize:   14,
                  fontWeight: FontWeight.w500,
                  color:      AppColors.textSecondary,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// SECTION 4 — ABOUT APP BOTTOM SHEET
// =============================================================================

void _showAboutSheet(BuildContext context) {
  final l10n     = AppLocalizations.of(context)!;
  final langCode = Localizations.localeOf(context).languageCode;

  showModalBottomSheet(
    context:            context,
    isScrollControlled: true,
    showDragHandle:     false,
    backgroundColor:    Colors.transparent,
    builder: (_) => DraggableScrollableSheet(
      expand:          false,
      initialChildSize: 0.55,
      minChildSize:     0.40,
      maxChildSize:     0.85,
      builder: (_, scrollController) => Container(
        decoration: const BoxDecoration(
          color:        AppColors.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            // Drag handle
            Container(
              width: 38, height: 4,
              decoration: BoxDecoration(
                color: AppColors.cardBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: SingleChildScrollView(
                controller: scrollController,
                padding: const EdgeInsetsDirectional.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    const SizedBox(height: 16),
                    // Official app logo
                    SizedBox(
                      width: 80, height: 80,
                      child: Image.asset(
                        'assets/images/logo.png',
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => Container(
                          decoration: BoxDecoration(
                            color:        AppColors.primary,
                            borderRadius: BorderRadius.circular(22),
                          ),
                          child: const Icon(
                            LucideIcons.users,
                            color: Colors.white,
                            size:  36,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      l10n.mubtaathTitle,
                      style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontSize:   22,
                        fontWeight: FontWeight.w800,
                        color:      AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      l10n.mubtaathTagline,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontFamily: 'Tajawal',
                        fontSize:   14,
                        fontWeight: FontWeight.w500,
                        color:      AppColors.textSecondary,
                        height:     1.5,
                      ),
                    ),
                    const SizedBox(height: 20),
                    // App concept card — mock data (replace with API later)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsetsDirectional.symmetric(
                        horizontal: 18, vertical: 20,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.10),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        langCode == 'ar'
                            ? 'مبتعث هو منصة صوتية متكاملة تُصمَّم خصيصاً للطلاب السعوديين المبتعثين في الخارج. نجمع أبناء المجتمع السعودي المبتعث تحت سقف واحد، ونوفّر لهم بيئة تواصل آمنة وداعمة بعيداً عن وطنهم.\n\nرؤيتنا\nنسعى إلى أن يجد كل مبتعث مجتمعاً حقيقياً يدعمه في رحلته الأكاديمية والشخصية؛ مجتمعاً يُجيب على تساؤلاته، ويُشاركه تجاربه، ويُذكّره بأنه ليس وحده.\n\nما نقدّمه\n• غرف صوتية متخصصة للنقاش والدعم\n• دليل الطالب المبتعث في كل دولة\n• أوقات الصلاة وبوصلة القبلة\n• آخر الإشعارات والتحديثات للمبتعثين'
                            : 'Mubtaath is a comprehensive voice platform designed specifically for Saudi scholarship students abroad. We bring the Saudi student community together under one roof, providing a safe and supportive environment away from home.\n\nOur Vision\nWe strive for every scholarship student to find a real community that supports them throughout their academic and personal journey — one that answers their questions, shares experiences, and reminds them they are never alone.\n\nWhat We Offer\n• Specialized voice rooms for discussion and support\n• Student guide for each host country\n• Prayer times and Qibla compass\n• Latest notifications and updates for scholarship students',
                        textAlign: TextAlign.start,
                        style: const TextStyle(
                          fontFamily: 'Tajawal',
                          fontSize:   14,
                          color:      AppColors.darkText,
                          height:     1.8,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    _AboutInfoRow(
                      label: l10n.appVersion,
                      value: '1.0.1',
                    ),
                    const Divider(color: AppColors.cardBorder, height: 1),
                    _AboutInfoRow(
                      label: l10n.appLanguage,
                      value: langCode == 'ar' ? l10n.arabic : l10n.english,
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _AboutInfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _AboutInfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'Cairo',
              fontSize:   14,
              fontWeight: FontWeight.w700,
              color:      AppColors.darkText,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              fontFamily: 'Tajawal',
              fontSize:   14,
              fontWeight: FontWeight.w500,
              color:      AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// SECTION 5 — LOGOUT BOTTOM SHEET
// =============================================================================

void _showLogoutSheet(BuildContext context, SettingsCubit cubit) {
  final l10n = AppLocalizations.of(context)!;
  showModalBottomSheet(
    context:            context,
    showDragHandle:     false,
    backgroundColor:    Colors.transparent,
    isScrollControlled: true,
    builder: (sheetCtx) => Container(
      decoration: const BoxDecoration(
        color:        AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsetsDirectional.symmetric(horizontal: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          // Drag handle pill
          Container(
            width: 38, height: 4,
            decoration: BoxDecoration(
              color:        AppColors.cardBorder,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 28),
          // Warning icon circle
          Container(
            width: 64, height: 64,
            decoration: BoxDecoration(
              color:  AppColors.logoutRed.withValues(alpha: 0.08),
              shape:  BoxShape.circle,
            ),
            child: const Icon(LucideIcons.logOut, color: AppColors.logoutRed, size: 28),
          ),
          const SizedBox(height: 16),
          Text(
            l10n.logoutConfirmTitle,
            style: const TextStyle(
              fontFamily: 'Cairo',
              fontSize:   18,
              fontWeight: FontWeight.w800,
              color:      AppColors.darkText,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.logoutConfirmBody,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'Tajawal',
              fontSize:   14,
              color:      AppColors.textSecondary,
              height:     1.5,
            ),
          ),
          const SizedBox(height: 28),
          // Confirm logout — filled destructive button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () async {
                Navigator.of(sheetCtx).pop();
                await cubit.logout();
                authNotifier.value = false;
                if (context.mounted) context.go('/login');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.logoutRed,
                foregroundColor: Colors.white,
                padding:         const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
              child: Text(
                l10n.logoutConfirm,
                style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontSize:   15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Cancel — outlined ghost button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => Navigator.of(sheetCtx).pop(),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 15),
                side:    const BorderSide(color: AppColors.cardBorder, width: 1.2),
                shape:   RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(
                l10n.cancel,
                style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontSize:   15,
                  fontWeight: FontWeight.w600,
                  color:      AppColors.textSecondary,
                ),
              ),
            ),
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
        ],
      ),
    ),
  );
}

// =============================================================================
// SECTION 5B — DELETE ACCOUNT CONFIRMATION DIALOG  (Apple Guideline 5.1.1)
//
// Critical, non-instant destructive action: a blocking dialog the user must
// explicitly confirm. While the network call is in flight the confirm button
// shows a spinner (driven by SettingsCubit.isDeletingAccount) and both buttons
// are disabled so the request can't be fired twice.
// =============================================================================

void _showDeleteAccountDialog(BuildContext context, SettingsCubit cubit) {
  final l10n = AppLocalizations.of(context)!;

  showDialog(
    context:            context,
    barrierDismissible: false,
    builder: (dialogCtx) => BlocProvider.value(
      value: cubit,
      child: BlocBuilder<SettingsCubit, SettingsState>(
        builder: (ctx, state) {
          final deleting = state.isDeletingAccount;

          return AlertDialog(
            backgroundColor: AppColors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Destructive icon badge
                Container(
                  width: 64, height: 64,
                  decoration: BoxDecoration(
                    color: AppColors.logoutRed.withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.delete_forever,
                    color: AppColors.logoutRed,
                    size:  30,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  l10n.deleteAccountConfirmTitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize:   18,
                    fontWeight: FontWeight.w800,
                    color:      AppColors.darkText,
                  ),
                ),
              ],
            ),
            content: Text(
              l10n.deleteAccountConfirmBody,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Tajawal',
                fontSize:   14,
                color:      AppColors.textSecondary,
                height:     1.6,
              ),
            ),
            actionsPadding: const EdgeInsetsDirectional.fromSTEB(20, 0, 20, 16),
            actions: [
              Column(
                children: [
                  // Confirm — filled destructive button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: deleting
                          ? null
                          : () async {
                              final messenger = ScaffoldMessenger.of(context);
                              final router    = GoRouter.of(context);

                              final ok = await cubit.deleteUserAccount();
                              if (!dialogCtx.mounted) return;
                              Navigator.of(dialogCtx).pop();

                              if (ok) {
                                authNotifier.value = false;
                                router.go('/login');
                              } else {
                                messenger.showSnackBar(
                                  SnackBar(
                                    content: Text(l10n.deleteAccountError),
                                    backgroundColor: AppColors.logoutRed,
                                  ),
                                );
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.logoutRed,
                        foregroundColor: Colors.white,
                        padding:         const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                      child: deleting
                          ? const SizedBox(
                              width:  22,
                              height: 22,
                              child:  CircularProgressIndicator(
                                color:       Colors.white,
                                strokeWidth: 2.5,
                              ),
                            )
                          : Text(
                              l10n.deleteAccountConfirm,
                              style: const TextStyle(
                                fontFamily: 'Cairo',
                                fontSize:   15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Cancel — outlined ghost button
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: deleting
                          ? null
                          : () => Navigator.of(dialogCtx).pop(),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        side:    const BorderSide(color: AppColors.cardBorder, width: 1.2),
                        shape:   RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        l10n.cancel,
                        style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontSize:   15,
                          fontWeight: FontWeight.w600,
                          color:      AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    ),
  );
}

// =============================================================================
// SECTION 6 — SETTINGS PAGE
// =============================================================================

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => SettingsCubit(),
      child: const _SettingsView(),
    );
  }
}

class _SettingsView extends StatelessWidget {
  const _SettingsView();

  @override
  Widget build(BuildContext context) {
    final l10n        = AppLocalizations.of(context)!;
    final langCubit   = context.watch<LanguageCubit>();
    final currentLang = langCubit.state.languageCode == 'ar'
        ? l10n.arabic
        : l10n.english;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: BlocBuilder<SettingsCubit, SettingsState>(
        builder: (context, state) {
          final cubit = context.read<SettingsCubit>();

          return SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Header ────────────────────────────────────────────────
                SharedHeader(title: l10n.settingsTitle),

                const SizedBox(height: 32),

                Expanded(
                  child: Padding(
                    padding: const EdgeInsetsDirectional.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // 1. Language
                        _SettingsCard(
                          icon:       LucideIcons.languages,
                          label:      l10n.appLanguage,
                          valueLabel: currentLang,
                          onTap: () => showLanguagePicker(context),
                        ),

                        const SizedBox(height: 14),

                        // 2. Help
                        _SettingsCard(
                          icon:  LucideIcons.helpCircle,
                          label: l10n.help,
                          onTap: () => context.push('/support'),
                        ),

                        const SizedBox(height: 14),

                        // 3. About
                        _SettingsCard(
                          icon:  LucideIcons.info,
                          label: l10n.aboutApp,
                          onTap: () => _showAboutSheet(context),
                        ),

                        const Spacer(),

                        // 4. Logout
                        CoreLogoutButton(
                          onTap: () => _showLogoutSheet(context, cubit),
                        ),

                        const SizedBox(height: 8),

                        // 5. Delete account (Apple Guideline 5.1.1) —
                        // destructive red text button → confirmation dialog
                        TextButton.icon(
                          onPressed: () =>
                              _showDeleteAccountDialog(context, cubit),
                          icon: const Icon(
                            Icons.delete_forever,
                            color: AppColors.logoutRed,
                            size:  20,
                          ),
                          label: Text(
                            l10n.deleteAccount,
                            style: const TextStyle(
                              fontFamily: 'Cairo',
                              fontSize:   14,
                              fontWeight: FontWeight.w700,
                              color:      AppColors.logoutRed,
                            ),
                          ),
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.logoutRed,
                            padding: const EdgeInsets.symmetric(
                              vertical: 8, horizontal: 12,
                            ),
                          ),
                        ),

                        const SizedBox(height: 8),

                        const Text(
                          'v 1.0.1',
                          style: TextStyle(
                            fontFamily: 'Tajawal',
                            fontSize:   13,
                            color:      AppColors.textSecondary,
                          ),
                        ),

                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

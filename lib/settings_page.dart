// =============================================================================
// MUBTAATH APP — SETTINGS PAGE  (Localized — ar/en)
// =============================================================================
// Language changes go through LanguageCubit (app-scoped, persisted).
// SettingsCubit is kept for local UI state (isLoggingOut).
// All hardcoded Arabic strings replaced with AppLocalizations keys.
// Directionality(rtl) wrappers removed — locale controls direction via
// GlobalWidgetsLocalizations injected in main.dart.
// =============================================================================

import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mubtaath/main.dart' show PushDiagnostics;
import 'package:mubtaath/core/auth_notifier.dart';
import 'package:mubtaath/core/bloc/language_cubit.dart';
import 'package:mubtaath/core/services/dio_client.dart';
import 'package:mubtaath/core/services/secure_storage_service.dart';
import 'package:mubtaath/core/l10n/app_localizations.dart';
import 'package:mubtaath/core/theme/app_colors.dart';
import 'package:mubtaath/core/services/floating_messages_setting.dart';
import 'package:mubtaath/core/services/nav_style_setting.dart';
import 'package:mubtaath/core/widgets/language_picker.dart';
import 'package:mubtaath/core/widgets/shared_widgets.dart';
import 'package:mubtaath/home_page.dart' show HomeCubit, liquidNavScrollClearance;

bool get _isIOS =>
    defaultTargetPlatform == TargetPlatform.iOS ||
    defaultTargetPlatform == TargetPlatform.macOS;

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
// SECTION 3b — FLOATING MESSAGES TOGGLE  (moved here from the room chat sheet)
// =============================================================================
class _FloatingMessagesToggleCard extends StatefulWidget {
  const _FloatingMessagesToggleCard();

  @override
  State<_FloatingMessagesToggleCard> createState() =>
      _FloatingMessagesToggleCardState();
}

class _FloatingMessagesToggleCardState
    extends State<_FloatingMessagesToggleCard> {
  bool _enabled = true;

  @override
  void initState() {
    super.initState();
    FloatingMessagesSetting.get().then((v) {
      if (mounted) setState(() => _enabled = v);
    });
  }

  Future<void> _toggle(bool v) async {
    setState(() => _enabled = v);
    await FloatingMessagesSetting.set(v);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      width: double.infinity,
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: 18, vertical: 12,
      ),
      decoration: BoxDecoration(
        color:        AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.cardBorder, width: 1.2),
      ),
      child: Row(
        children: [
          const Icon(LucideIcons.sparkles, color: AppColors.primary, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              l10n.floatingMessages,
              style: const TextStyle(
                fontFamily: 'Cairo',
                fontSize:   15,
                fontWeight: FontWeight.w700,
                color:      AppColors.darkText,
                height:     1.2,
              ),
            ),
          ),
          Switch(
            value: _enabled,
            onChanged: _toggle,
            activeThumbColor: AppColors.white,
            activeTrackColor: AppColors.primary,
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// SECTION 3c — iOS NAV BAR STYLE PICKER  (iOS only)
// =============================================================================

class _IOSNavStyleCard extends StatefulWidget {
  const _IOSNavStyleCard();

  @override
  State<_IOSNavStyleCard> createState() => _IOSNavStyleCardState();
}

class _IOSNavStyleCardState extends State<_IOSNavStyleCard> {
  String _style = NavStyleSetting.liquid;

  @override
  void initState() {
    super.initState();
    NavStyleSetting.get().then((v) {
      if (mounted) setState(() => _style = v);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final valueLabel =
        _style == NavStyleSetting.classic ? l10n.navStyleClassic : l10n.navStyleLiquid;

    return _SettingsCard(
      icon:       LucideIcons.layoutTemplate,
      label:      l10n.navBarStyle,
      valueLabel: valueLabel,
      onTap: () async {
        final picked = await _showNavStylePicker(context, current: _style);
        if (picked == null || !context.mounted) return;
        setState(() => _style = picked);
        context.read<HomeCubit>().setIosNavStyle(picked);
      },
    );
  }
}

/// Bottom sheet with a live-style preview of both nav bar options, so the
/// user sees exactly what each looks like before picking.
Future<String?> _showNavStylePicker(
  BuildContext context, {
  required String current,
}) {
  final l10n = AppLocalizations.of(context)!;
  return showModalBottomSheet<String>(
    context:            context,
    isScrollControlled: true,
    backgroundColor:    Colors.transparent,
    builder: (sheetCtx) => Container(
      decoration: const BoxDecoration(
        color:        AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
        20, 12, 20, MediaQuery.of(sheetCtx).padding.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 38, height: 4,
            decoration: BoxDecoration(
              color: AppColors.cardBorder,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 18),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              l10n.navBarStyle,
              style: const TextStyle(
                fontFamily: 'Cairo',
                fontSize:   17,
                fontWeight: FontWeight.w800,
                color:      AppColors.darkText,
              ),
            ),
          ),
          const SizedBox(height: 18),
          _NavStyleOption(
            label:    l10n.navStyleLiquid,
            selected: current == NavStyleSetting.liquid,
            preview:  const _NavPreviewLiquid(),
            onTap: () => Navigator.of(sheetCtx).pop(NavStyleSetting.liquid),
          ),
          const SizedBox(height: 14),
          _NavStyleOption(
            label:    l10n.navStyleClassic,
            selected: current == NavStyleSetting.classic,
            preview:  const _NavPreviewClassic(),
            onTap: () => Navigator.of(sheetCtx).pop(NavStyleSetting.classic),
          ),
        ],
      ),
    ),
  );
}

class _NavStyleOption extends StatelessWidget {
  final String   label;
  final bool     selected;
  final Widget   preview;
  final VoidCallback onTap;

  const _NavStyleOption({
    required this.label,
    required this.selected,
    required this.preview,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary.withValues(alpha: 0.06) : AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.cardBorder,
            width: selected ? 1.6 : 1.2,
          ),
        ),
        child: Column(
          children: [
            // Mini phone-screen frame containing the style preview.
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Container(
                height: 96,
                color: AppColors.avatarBg,
                alignment: Alignment.bottomCenter,
                child: preview,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(
                  selected ? LucideIcons.checkCircle2 : LucideIcons.circle,
                  size:  18,
                  color: selected ? AppColors.primary : AppColors.textSecondary,
                ),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize:   14,
                    fontWeight: FontWeight.w700,
                    color: selected ? AppColors.primary : AppColors.darkText,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// Static mockup of the floating "liquid glass" pill — a rounded dark-green
// bar with a visible gap below it, matching _IOSNav's actual look.
class _NavPreviewLiquid extends StatelessWidget {
  const _NavPreviewLiquid();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
      child: Container(
        height: 30,
        decoration: BoxDecoration(
          color:        AppColors.primaryDark.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: AppColors.white.withValues(alpha: 0.25)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: List.generate(
            4,
            (i) => Container(
              width:  5, height: 5,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.white.withValues(alpha: i == 0 ? 1 : 0.45),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Static mockup of the classic flat bar — full-width, flush with the bottom,
// rounded top corners only, matching _AndroidNav's actual look.
class _NavPreviewClassic extends StatelessWidget {
  const _NavPreviewClassic();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 26,
      width:  double.infinity,
      decoration: const BoxDecoration(
        color:        AppColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(
          4,
          (i) => Container(
            width:  5, height: 5,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: i == 0 ? AppColors.primary : AppColors.cardBorder,
            ),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// SECTION 4 — ABOUT APP BOTTOM SHEET
// =============================================================================

// Diagnostic dialog for the push-registration flow (Settings → "تشخيص الإشعارات").
// Shows Firebase/APNs/FCM status so an iOS push failure can be read on-device.
void _showPushDiagnostics(BuildContext context) {
  final text = PushDiagnostics.summary();
  showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.white,
      title: const Text(
        'Push diagnostics',
        style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w800, fontSize: 16),
      ),
      content: SelectableText(
        text,
        style: const TextStyle(fontFamily: 'monospace', fontSize: 13, height: 1.6),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Clipboard.setData(ClipboardData(text: text));
            ScaffoldMessenger.of(ctx).showSnackBar(
              const SnackBar(content: Text('Copied')),
            );
          },
          child: const Text('Copy'),
        ),
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Close'),
        ),
      ],
    ),
  );
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
                              child:  MubtaathLoader(
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
                  child: SingleChildScrollView(
                    padding: EdgeInsetsDirectional.fromSTEB(
                      20, 0, 20, liquidNavScrollClearance(context),
                    ),
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

                        // Floating messages toggle (moved here from the room chat)
                        const _FloatingMessagesToggleCard(),

                        const SizedBox(height: 14),

                        // iOS-only: switch between the floating pill and the
                        // classic flat nav bar.
                        if (_isIOS) ...[
                          const _IOSNavStyleCard(),
                          const SizedBox(height: 14),
                        ],

                        // 2. Help
                        _SettingsCard(
                          icon:  LucideIcons.helpCircle,
                          label: l10n.help,
                          onTap: () => context.push('/support'),
                        ),

                        const SizedBox(height: 14),

                        // 3. Terms & Conditions
                        _SettingsCard(
                          icon:  LucideIcons.fileText,
                          label: l10n.termsAndConditions,
                          onTap: () => context.push('/legal/terms'),
                        ),

                        const SizedBox(height: 14),

                        // 4. Privacy Policy
                        _SettingsCard(
                          icon:  LucideIcons.shieldCheck,
                          label: l10n.privacyPolicy,
                          onTap: () => context.push('/legal/privacy'),
                        ),

                        const SizedBox(height: 14),

                        // 5. About — dashboard-editable content (legal 'about').
                        _SettingsCard(
                          icon:  LucideIcons.info,
                          label: l10n.aboutApp,
                          onTap: () => context.push('/legal/about'),
                        ),

                        const SizedBox(height: 14),

                        // TEMP — push-notification diagnostic (iOS APNs debug).
                        // Remove once notifications are confirmed working.
                        _SettingsCard(
                          icon:  LucideIcons.bell,
                          label: l10n.pushDiagnosticsLabel,
                          onTap: () => _showPushDiagnostics(context),
                        ),

                        // Fixed gap, not Spacer — this Column now scrolls, so
                        // Spacer would fight an unbounded height instead of
                        // sizing against Expanded's old bounded one (which is
                        // what made the logout button end up stuck right
                        // under the About card: the flex space it computed
                        // was often only a few px once content nearly filled
                        // the available height).
                        const SizedBox(height: 32),

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

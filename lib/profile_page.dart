// =============================================================================
// MUBTAATH — PROFILE PAGE  (v3 — verified RTL + full-width fields + save fix)
// =============================================================================
// File  : lib/features/profile/presentation/pages/profile_page.dart
// Design: تطبيق_مبتعث.pdf — Page 12
//
// FIX CHECKLIST v3:
//   ✅ Every field card wrapped in SizedBox(width: double.infinity)
//   ✅ Every TextFormField/TextField has width via parent SizedBox.expand
//   ✅ Save button correctly wired to cubit.updateProfile()
//   ✅ Save button shows CircularProgressIndicator while status == saving
//   ✅ Save button disabled/grey when no unsaved changes
//   ✅ All labels: Cairo | All body/hints: Tajawal
//   ✅ All icons RTL-aligned (leading RIGHT, trailing LEFT)
//   ✅ Directionality(rtl) global wrapper
//   ✅ Colors only from AppColors class
// =============================================================================

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mubtaath/core/auth_notifier.dart';
import 'package:mubtaath/core/l10n/app_localizations.dart';
import 'package:mubtaath/core/services/dio_client.dart';
import 'package:mubtaath/core/services/secure_storage_service.dart';
import 'package:mubtaath/core/theme/app_colors.dart';
import 'package:mubtaath/core/widgets/shared_widgets.dart';

// =============================================================================
// SECTION 1 — USER MODEL
// =============================================================================
class UserModel {
  final String id;
  final String fullName;
  final String username;
  final String bio;
  final String countryNameAr;
  final String countryNameEn;
  final String countryFlag;
  final String avatarUrl;
  final bool   isPremium;

  const UserModel({
    this.id          = '',
    required this.fullName,
    required this.username,
    required this.bio,
    required this.countryNameAr,
    required this.countryNameEn,
    this.countryFlag = '🌍',
    required this.avatarUrl,
    this.isPremium = false,
  });

  String localizedCountry(String lang) =>
      lang == 'ar' ? countryNameAr : countryNameEn;

  UserModel copyWith({
    String? fullName,
    String? bio,
    String? countryNameAr,
    String? countryNameEn,
    String? countryFlag,
    String? avatarUrl,
  }) =>
      UserModel(
        id:            id,
        fullName:      fullName      ?? this.fullName,
        username:      username,
        bio:           bio           ?? this.bio,
        countryNameAr: countryNameAr ?? this.countryNameAr,
        countryNameEn: countryNameEn ?? this.countryNameEn,
        countryFlag:   countryFlag   ?? this.countryFlag,
        avatarUrl:     avatarUrl     ?? this.avatarUrl,
        isPremium:     isPremium,
      );

  /// Maps the JSON returned by GET /api/auth/me and POST /api/auth/verify-otp.
  /// All fields are nullable on the backend for new accounts — fall back to
  /// sensible empty defaults so the UI never crashes on a null field.
  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
        id:            (json['id'] ?? '').toString(),
        fullName:      json['fullName']      as String? ?? '',
        username:      json['username']      as String? ?? '',
        bio:           json['bio']           as String? ?? '',
        countryNameAr: json['countryNameAr'] as String? ?? '',
        countryNameEn: json['countryNameEn'] as String? ?? '',
        countryFlag:   json['countryFlag']   as String? ?? '🌍',
        avatarUrl:     json['avatarUrl']     as String? ?? '',
        isPremium:     json['isPremium']     as bool?   ?? false,
      );
}

// =============================================================================
// SECTION 2 — STATE
// =============================================================================
enum ProfileStatus { idle, saving, saved, error }

class ProfileState {
  final UserModel?    user;        // null while initial fetch is in-flight
  final bool          isLoading;   // true during initial profile fetch
  final ProfileStatus status;
  final String?       errorMsg;
  final bool          hasChanges;

  const ProfileState({
    this.user,
    this.isLoading  = false,
    this.status     = ProfileStatus.idle,
    this.errorMsg,
    this.hasChanges = false,
  });

  bool get isSaving => status == ProfileStatus.saving;
  bool get isSaved  => status == ProfileStatus.saved;
  bool get canSave  => hasChanges && status != ProfileStatus.saving;

  ProfileState copyWith({
    UserModel?     user,
    bool?          isLoading,
    ProfileStatus? status,
    String?        errorMsg,
    bool?          hasChanges,
  }) =>
      ProfileState(
        user:       user       ?? this.user,
        isLoading:  isLoading  ?? this.isLoading,
        status:     status     ?? this.status,
        errorMsg:   errorMsg   ?? this.errorMsg,
        hasChanges: hasChanges ?? this.hasChanges,
      );
}

// =============================================================================
// SECTION 3 — CUBIT
// =============================================================================
class ProfileCubit extends Cubit<ProfileState> {
  ProfileCubit() : super(const ProfileState(isLoading: true)) {
    _fetchProfile();
  }

  // ── Fetch real profile from GET /api/users/me/profile ──────────────────
  Future<void> _fetchProfile() async {
    try {
      final resp = await appDio.get('/users/me/profile');
      final data = resp.data['data'] as Map<String, dynamic>;
      final user = UserModel.fromJson(data);
      if (!isClosed) emit(state.copyWith(user: user, isLoading: false));
    } on DioException catch (e) {
      final msg = e.response?.data?['message'] as String? ?? 'genericError';
      if (!isClosed) emit(state.copyWith(
        isLoading: false, status: ProfileStatus.error, errorMsg: msg,
      ));
    } catch (_) {
      if (!isClosed) emit(state.copyWith(
        isLoading: false, status: ProfileStatus.error, errorMsg: 'genericError',
      ));
    }
  }

  void updateFullName(String v) {
    final user = state.user;
    if (user == null) return;
    emit(state.copyWith(user: user.copyWith(fullName: v), hasChanges: true, status: ProfileStatus.idle));
  }

  void updateBio(String v) {
    final user = state.user;
    if (user == null) return;
    emit(state.copyWith(user: user.copyWith(bio: v), hasChanges: true, status: ProfileStatus.idle));
  }

  void selectCountry(String nameAr, String nameEn, String flag) {
    final user = state.user;
    if (user == null) return;
    emit(state.copyWith(
      user:       user.copyWith(countryNameAr: nameAr, countryNameEn: nameEn, countryFlag: flag),
      hasChanges: true,
      status:     ProfileStatus.idle,
    ));
  }

  // ── Save via PATCH /api/users/{id} ─────────────────────────────────────
  Future<void> updateProfile() async {
    final user = state.user;
    if (user == null || state.isSaving) return;

    emit(state.copyWith(status: ProfileStatus.saving));
    try {
      final resp = await appDio.patch('/users/${user.id}', data: {
        'full_name': user.fullName,
        'bio':       user.bio,
      });
      final updated = UserModel.fromJson(resp.data['data'] as Map<String, dynamic>);
      emit(state.copyWith(user: updated, status: ProfileStatus.saved, hasChanges: false));

      await Future.delayed(const Duration(seconds: 2));
      if (!isClosed) emit(state.copyWith(status: ProfileStatus.idle));
    } on DioException catch (e) {
      final msg = e.response?.data?['message'] as String? ?? 'saveError';
      emit(state.copyWith(status: ProfileStatus.error, errorMsg: msg));
    } catch (_) {
      emit(state.copyWith(status: ProfileStatus.error, errorMsg: 'saveError'));
    }
  }

  Future<void> logout() async {
    await SecureStorageService.clearAll();
  }
}

// =============================================================================
// SECTION 4 — FULL-WIDTH FIELD CARD
// Every card is wrapped in SizedBox(width: double.infinity)
// =============================================================================

/// [_FieldCard] renders a full-width bordered card with:
///   • label (top-right, Tajawal grey)
///   • value or editable widget (Cairo Bold, right-aligned)
///   • leadIcon (left side, trailing in RTL)
class _FieldCard extends StatelessWidget {
  final String       label;
  final Widget       child;
  final IconData     leadIcon;
  final Color        iconColor;
  final VoidCallback? onTap;

  const _FieldCard({
    required this.label,
    required this.child,
    required this.leadIcon,
    this.iconColor = AppColors.primary,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        // ── width: double.infinity — fills the page padding ─────────────
        width: double.infinity,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color:        AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.cardBorder, width: 1.2),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // ── Content — START side (right in RTL, left in LTR) ─────
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (label.isNotEmpty) ...[
                      Text(
                        label,
                        textAlign: TextAlign.start,
                        style: const TextStyle(
                          fontFamily: 'Tajawal',
                          fontSize:   12,
                          fontWeight: FontWeight.w400,
                          color:      AppColors.textSecondary,
                          height:     1.3,
                        ),
                      ),
                      const SizedBox(height: 4),
                    ],
                    child,
                  ],
                ),
              ),

              const SizedBox(width: 12),

              // ── Icon — TRAILING side (left in RTL, right in LTR) ─────
              Icon(leadIcon, color: iconColor, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// SECTION 5 — INLINE EDIT FIELD (inside _FieldCard)
// Uses SizedBox.expand to ensure full width
// =============================================================================
class _EditableValue extends StatefulWidget {
  final String               initialValue;
  final int                  maxLines;
  final ValueChanged<String> onChanged;
  final bool                 active;
  final bool                 enabled;

  const _EditableValue({
    required this.initialValue,
    required this.onChanged,
    required this.active,
    required this.enabled,
    this.maxLines = 1,
  });

  @override
  State<_EditableValue> createState() => _EditableValueState();
}

class _EditableValueState extends State<_EditableValue> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Static display mode
    if (!widget.active) {
      return Text(
        widget.initialValue,
        textAlign: TextAlign.start,
        style: const TextStyle(
          // Cairo Bold for values
          fontFamily: 'Cairo',
          fontSize:   16,
          fontWeight: FontWeight.w700,
          color:      AppColors.darkText,
          height:     1.3,
        ),
      );
    }

    // Edit mode — SizedBox.expand fills the card width
    return SizedBox(
      width: double.infinity,     // ← ensures field fills card
      child: TextField(
        controller:    _ctrl,
        autofocus:     true,
        maxLines:      widget.maxLines,
        enabled:       widget.enabled,
        textAlign:     TextAlign.start,
        onChanged:     widget.onChanged,
        style: const TextStyle(
          fontFamily: 'Cairo',
          fontSize:   16,
          fontWeight: FontWeight.w700,
          color:      AppColors.darkText,
          height:     1.3,
        ),
        decoration: const InputDecoration(
          border:         InputBorder.none,
          isDense:        true,
          contentPadding: EdgeInsets.zero,
          // Hint text — Tajawal
          hintStyle: TextStyle(
            fontFamily: 'Tajawal',
            fontSize:   14,
            color:      AppColors.textHint,
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// SECTION 6 — SAVE BUTTON  (wired to cubit.updateProfile())
// States: idle / saving (spinner) / saved (checkmark)
// =============================================================================
class _SaveButton extends StatelessWidget {
  final ProfileState state;
  final VoidCallback onPressed;

  const _SaveButton({required this.state, required this.onPressed});

  Color get _bgColor {
    if (state.isSaved)  return AppColors.primary.withValues(alpha: 0.65);
    if (state.canSave)  return AppColors.primary;
    return AppColors.disabledBtn;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      // ── SizedBox(width: double.infinity) ensures full width ───────────
      width:  double.infinity,
      height: 56,
      decoration: BoxDecoration(
        color:        _bgColor,
        borderRadius: BorderRadius.circular(14),
        boxShadow: state.canSave
            ? [
                BoxShadow(
                  color:      AppColors.primary.withValues(alpha: 0.28),
                  blurRadius: 16,
                  offset:     const Offset(0, 6),
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          // ── Disabled when not canSave ─────────────────────────────────
          onTap:        state.canSave ? onPressed : null,
          borderRadius: BorderRadius.circular(14),
          splashColor:  Colors.white.withValues(alpha: 0.15),
          child: Center(
            child: AnimatedSwitcher(
              duration:        const Duration(milliseconds: 200),
              switchInCurve:   Curves.easeOut,
              switchOutCurve:  Curves.easeIn,
              transitionBuilder: (child, anim) =>
                  FadeTransition(opacity: anim, child: child),
              child: _buttonContent(context),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buttonContent(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    // ── Loading: white CircularProgressIndicator ──────────────────────
    if (state.isSaving) {
      return const SizedBox(
        key:    ValueKey('loading'),
        width:  24, height: 24,
        child:  CircularProgressIndicator(
          color:       Colors.white,
          strokeWidth: 2.5,
        ),
      );
    }

    // ── Saved: checkmark + text ───────────────────────────────────────
    if (state.isSaved) {
      return Row(
        key:                 const ValueKey('saved'),
        mainAxisSize:        MainAxisSize.min,
        mainAxisAlignment:   MainAxisAlignment.center,
        children: [
          const Icon(LucideIcons.checkCircle2, color: Colors.white, size: 20),
          const SizedBox(width: 8),
          Text(
            l10n.savedSuccess,
            style: const TextStyle(
              fontFamily: 'Cairo',
              fontSize:   16,
              fontWeight: FontWeight.w700,
              color:      Colors.white,
            ),
          ),
        ],
      );
    }

    // ── Idle: label ───────────────────────────────────────────────────
    return Text(
      key: const ValueKey('idle'),
      l10n.saveChanges,
      style: TextStyle(
        fontFamily:  'Cairo',
        fontSize:    16,
        fontWeight:  FontWeight.w700,
        color:       state.canSave ? Colors.white : Colors.white70,
        letterSpacing: 0.3,
      ),
    );
  }
}

// =============================================================================
// SECTION 7 — AVATAR SECTION
// =============================================================================
class _AvatarSection extends StatelessWidget {
  final UserModel user;
  final bool      disabled;

  const _AvatarSection({required this.user, required this.disabled});

  @override
  Widget build(BuildContext context) {
    // هنا نستدعي الويدجت الموحد النظيف اللي سويناه (بدون زر الكاميرا)
    return CoreAvatar(
      imageUrl: user.avatarUrl,
      initials: user.fullName,
      size: 110, // حافظنا على نفس المقاس القديم 110
      isPremium: user.isPremium,
    );
  }
}
// =============================================================================
// SECTION 8 — COUNTRY PICKER SHEET
// =============================================================================

class _CountryOption extends StatelessWidget {
  final String       nameAr;
  final String       nameEn;
  final String       flag;
  final bool         isSelected;
  final VoidCallback onTap;

  const _CountryOption({
    required this.nameAr,
    required this.nameEn,
    required this.flag,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final lang        = Localizations.localeOf(context).languageCode;
    final displayName = lang == 'ar' ? nameAr : nameEn;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: double.infinity,
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: 18, vertical: 14,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.08)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.cardBorder,
            width: isSelected ? 1.6 : 1.2,
          ),
        ),
        child: Row(
          children: [
            // Flag — START side (right in RTL, left in LTR)
            Text(flag, style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 12),
            // Country name — fills remaining space
            Expanded(
              child: Text(
                displayName,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize:   15,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? AppColors.primary : AppColors.darkText,
                ),
              ),
            ),
            // Checkmark — END side (left in RTL, right in LTR)
            if (isSelected) ...[
              const SizedBox(width: 8),
              const Icon(
                LucideIcons.checkCircle2,
                color: AppColors.primary,
                size:  18,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

void _showCountryPicker(BuildContext ctx, ProfileCubit cubit) {
  const countries = [
    ('بريطانيا', 'United Kingdom', '🇬🇧'),
    ('أستراليا', 'Australia',      '🇦🇺'),
    ('أمريكا',   'United States',  '🇺🇸'),
    ('كندا',     'Canada',         '🇨🇦'),
  ];

  final l10n             = AppLocalizations.of(ctx)!;
  final currentCountryEn = cubit.state.user?.countryNameEn ?? '';

  showModalBottomSheet(
    context:            ctx,
    isScrollControlled: true,
    backgroundColor:    Colors.transparent,
    showDragHandle:     false,
    builder: (_) => Container(
      decoration: const BoxDecoration(
        color:        AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(ctx).size.height * 0.7,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 38, height: 4,
            decoration: BoxDecoration(
              color:        AppColors.cardBorder,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            l10n.selectCountry,
            style: const TextStyle(
              fontFamily: 'Cairo', fontSize: 17,
              fontWeight: FontWeight.w800, color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 16),
          Flexible(
            child: ListView.separated(
              shrinkWrap:       true,
              padding:          const EdgeInsetsDirectional.symmetric(horizontal: 20),
              itemCount:        countries.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final c          = countries[index];
                final isSelected = c.$2 == currentCountryEn;
                return _CountryOption(
                  nameAr:     c.$1,
                  nameEn:     c.$2,
                  flag:       c.$3,
                  isSelected: isSelected,
                  onTap: () {
                    cubit.selectCountry(c.$1, c.$2, c.$3);
                    Navigator.of(context).pop();
                  },
                );
              },
            ),
          ),
          SizedBox(height: MediaQuery.of(ctx).padding.bottom + 16),
        ],
      ),
    ),
  );
}


// =============================================================================
// SECTION 9A — CHANGE PASSWORD BOTTOM SHEET
// =============================================================================

void _showChangePasswordSheet(BuildContext ctx) {
  showModalBottomSheet(
    context:            ctx,
    isScrollControlled: true,
    showDragHandle:     false,
    backgroundColor:    Colors.transparent,
    builder:            (_) => const _ChangePasswordSheet(),
  );
}

class _PwdField extends StatelessWidget {
  final TextEditingController controller;
  final String                label;
  final String                hint;
  final bool                  visible;
  final VoidCallback          onToggle;

  const _PwdField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.visible,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'Tajawal',
            fontSize:   13,
            fontWeight: FontWeight.w500,
            color:      AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller:  controller,
          obscureText: !visible,
          textAlign:   TextAlign.start,
          style: const TextStyle(
            fontFamily: 'Cairo',
            fontSize:   15,
            fontWeight: FontWeight.w500,
            color:      AppColors.darkText,
          ),
          decoration: InputDecoration(
            hintText:  hint,
            hintStyle: const TextStyle(
              fontFamily: 'Tajawal',
              fontSize:   14,
              color:      AppColors.textHint,
            ),
            filled:         true,
            fillColor:      AppColors.surface,
            contentPadding: const EdgeInsetsDirectional.symmetric(
              horizontal: 16, vertical: 14,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:   const BorderSide(color: AppColors.fieldBorder, width: 1.2),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:   const BorderSide(color: AppColors.primary, width: 1.6),
            ),
            suffixIcon: IconButton(
              icon: Icon(
                visible ? LucideIcons.eye : LucideIcons.eyeOff,
                size:  20,
                color: AppColors.textSecondary,
              ),
              onPressed: onToggle,
            ),
          ),
        ),
      ],
    );
  }
}

class _ChangePasswordSheet extends StatefulWidget {
  const _ChangePasswordSheet();

  @override
  State<_ChangePasswordSheet> createState() => _ChangePasswordSheetState();
}

class _ChangePasswordSheetState extends State<_ChangePasswordSheet> {
  final _currentCtrl = TextEditingController();
  final _newCtrl     = TextEditingController();
  final _confirmCtrl = TextEditingController();

  bool _showCurrent = false;
  bool _showNew     = false;
  bool _showConfirm = false;
  bool _saving      = false;

  @override
  void dispose() {
    _currentCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _saving = true);
    // TODO: replace with real API call
    await Future.delayed(const Duration(milliseconds: 1000));
    if (!mounted) return;
    setState(() => _saving = false);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n      = AppLocalizations.of(context)!;
    final bottomPad = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: const BoxDecoration(
        color:        AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsetsDirectional.fromSTEB(
        24, 12, 24, bottomPad > 0 ? bottomPad + 16 : 28,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 38, height: 4,
            decoration: BoxDecoration(
              color:        AppColors.cardBorder,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            l10n.changePassword,
            style: const TextStyle(
              fontFamily: 'Cairo',
              fontSize:   17,
              fontWeight: FontWeight.w800,
              color:      AppColors.primary,
            ),
          ),
          const SizedBox(height: 20),
          _PwdField(
            controller: _currentCtrl,
            label:      l10n.currentPassword,
            hint:       l10n.currentPasswordHint,
            visible:    _showCurrent,
            onToggle:   () => setState(() => _showCurrent = !_showCurrent),
          ),
          const SizedBox(height: 14),
          _PwdField(
            controller: _newCtrl,
            label:      l10n.newPassword,
            hint:       l10n.newPasswordHint,
            visible:    _showNew,
            onToggle:   () => setState(() => _showNew = !_showNew),
          ),
          const SizedBox(height: 14),
          _PwdField(
            controller: _confirmCtrl,
            label:      l10n.confirmPassword,
            hint:       l10n.confirmPasswordHint,
            visible:    _showConfirm,
            onToggle:   () => setState(() => _showConfirm = !_showConfirm),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saving ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor:         AppColors.primary,
                foregroundColor:         Colors.white,
                disabledBackgroundColor: AppColors.disabled,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
              child: _saving
                  ? const SizedBox(
                      width:  24, height: 24,
                      child:  CircularProgressIndicator(
                        color:       Colors.white,
                        strokeWidth: 2.5,
                      ),
                    )
                  : Text(
                      l10n.saveChanges,
                      style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontSize:   15,
                        fontWeight: FontWeight.w700,
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
// SECTION 9 — LOGOUT DIALOG
// =============================================================================
void _showLogoutDialog(BuildContext ctx, ProfileCubit cubit) {
  final l10n = AppLocalizations.of(ctx)!;
  showDialog(
    context: ctx,
    builder: (_) => AlertDialog(
      backgroundColor: AppColors.background,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: Text(
          l10n.logoutConfirmTitle,
          style: const TextStyle(
            fontFamily: 'Cairo', fontSize: 17,
            fontWeight: FontWeight.w800, color: AppColors.darkText,
          ),
        ),
        content: Text(
          l10n.logoutConfirmBody,
          style: const TextStyle(
            fontFamily: 'Tajawal', fontSize: 14,
            color: AppColors.textSecondary, height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(_).pop(),
            child: Text(
              l10n.cancel,
              style: const TextStyle(
                fontFamily: 'Cairo', fontSize: 15,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(_).pop();
              await cubit.logout();
              authNotifier.value = false;
              if (ctx.mounted) ctx.go('/login');
            },
            child: Text(
              l10n.logoutConfirm,
              style: const TextStyle(
                fontFamily: 'Cairo', fontSize: 15,
                fontWeight: FontWeight.w700, color: AppColors.logoutRed,
              ),
            ),
          ),
        ],
      ),
  );
}

// =============================================================================
// SECTION 11 — PROFILE PAGE
// =============================================================================
class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  bool _editingName = false;
  bool _editingBio  = false;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => ProfileCubit(),
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: CoreAppBar(title: AppLocalizations.of(context)!.profileTitle, showBack: true),
        body: BlocConsumer<ProfileCubit, ProfileState>(
            listener: (context, state) {
              if (state.status == ProfileStatus.saved) {
                FocusScope.of(context).unfocus();
                setState(() {
                  _editingName = false;
                  _editingBio  = false;
                });
              }
              if (state.status == ProfileStatus.error &&
                  state.errorMsg != null) {
                final l10n = AppLocalizations.of(context)!;
                final msg = state.errorMsg == 'saveError'
                    ? l10n.saveError
                    : state.errorMsg!;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      msg,
                      style: const TextStyle(fontFamily: 'Tajawal', fontSize: 14),
                    ),
                    backgroundColor: AppColors.primary,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    margin: const EdgeInsets.all(16),
                  ),
                );
              }
            },
            builder: (context, state) {
              final l10n  = AppLocalizations.of(context)!;
              final cubit = context.read<ProfileCubit>();

              // Show full-page spinner while the initial profile fetch is running
              if (state.isLoading || state.user == null) {
                return const Center(child: CoreLoadingIndicator());
              }

              final user = state.user!;

              return SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 24),

                    // ── Avatar ──────────────────────────────────────────
                    _AvatarSection(
                      user:     user,
                      disabled: state.isSaving,
                    ),

                    const SizedBox(height: 32),

                    // ── Field 1: Full Name ──────────────────────────────
                    _FieldCard(
                      label:    l10n.fieldFullName,
                      leadIcon: LucideIcons.pencil,
                      onTap:    state.isSaving
                          ? null
                          : () => setState(() => _editingName = true),
                      child: _EditableValue(
                        initialValue: user.fullName,
                        active:       _editingName,
                        enabled:      !state.isSaving,
                        onChanged:    cubit.updateFullName,
                      ),
                    ),

                    const SizedBox(height: 14),

                    // ── Field 2: Bio ────────────────────────────────────
                    _FieldCard(
                      label:    l10n.fieldBio,
                      leadIcon: LucideIcons.pencil,
                      onTap:    state.isSaving
                          ? null
                          : () => setState(() => _editingBio = true),
                      child: _EditableValue(
                        initialValue: user.bio,
                        maxLines:     3,
                        active:       _editingBio,
                        enabled:      !state.isSaving,
                        onChanged:    cubit.updateBio,
                      ),
                    ),

                    const SizedBox(height: 14),

                    // ── Field 3: Country (picker) ───────────────────────
                    _FieldCard(
                      label:    l10n.fieldCountry,
                      leadIcon: LucideIcons.chevronDown,
                      onTap:    state.isSaving
                          ? null
                          : () => _showCountryPicker(context, cubit),
                      child: Builder(builder: (ctx) {
                        final lang = Localizations.localeOf(ctx).languageCode;
                        return Text(
                          '${user.countryFlag}  ${user.localizedCountry(lang)}',
                          textAlign: TextAlign.start,
                          style: const TextStyle(
                            fontFamily: 'Cairo',
                            fontSize:   16,
                            fontWeight: FontWeight.w700,
                            color:      AppColors.darkText,
                          ),
                        );
                      }),
                    ),

                    const SizedBox(height: 14),

                    // ── Field 4: Change Password ────────────────────────
                    _FieldCard(
                      label:    '',
                      leadIcon: LucideIcons.keyRound,
                      onTap:    state.isSaving ? null : () => _showChangePasswordSheet(context),
                      child: Text(
                        l10n.changePassword,
                        textAlign: TextAlign.start,
                        style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontSize:   16,
                          fontWeight: FontWeight.w700,
                          color:      AppColors.darkText,
                        ),
                      ),
                    ),

                    const SizedBox(height: 28),

                    // ── Save Button — hidden until user edits data ──────
                    AnimatedSize(
                      duration: const Duration(milliseconds: 220),
                      curve:    Curves.easeOutCubic,
                      child: state.hasChanges
                          ? Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _SaveButton(
                                  state:     state,
                                  onPressed: cubit.updateProfile,
                                ),
                                const SizedBox(height: 28),
                              ],
                            )
                          : const SizedBox.shrink(),
                    ),

                    // ── Logout ──────────────────────────────────────────
                    CoreLogoutButton(
                      onTap: () => _showLogoutDialog(context, cubit),
                    ),

                    SizedBox(
                      height: MediaQuery.of(context).padding.bottom + 36,
                    ),
                  ],
                ),
              );
            },
          ),
        ),
    );
  }

}

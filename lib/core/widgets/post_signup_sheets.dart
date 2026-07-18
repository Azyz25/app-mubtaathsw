// lib/core/widgets/post_signup_sheets.dart
//
// Two bottom sheets shown right after a brand-new account is created:
//   1. Phone completion — Google/Apple never hand over a phone number, so a
//      new social-signup account is created without one; this collects it
//      the same way registration's own phone field does.
//   2. Bio prompt — shown once for every newly created account regardless of
//      how they signed up, so the profile isn't empty the first time anyone
//      else sees it.
// Both PATCH the same /users/{id} endpoint the Profile page itself uses.

import 'package:flutter/material.dart';
import 'package:intl_phone_field/countries.dart' show countries, Country;
import 'package:mubtaath/core/l10n/app_localizations.dart';
import 'package:mubtaath/core/services/dio_client.dart';
import 'package:mubtaath/core/theme/app_colors.dart';
import 'package:mubtaath/core/widgets/country_picker_sheet.dart';
import 'package:mubtaath/core/widgets/home_country_picker_sheet.dart';

Future<void> showPhoneCompletionSheet(
  BuildContext context, {
  required String userId,
}) {
  return showModalBottomSheet<void>(
    context:            context,
    backgroundColor:    AppColors.white,
    isScrollControlled: true,
    isDismissible:      false,
    enableDrag:         false,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (sheetCtx) => _PhoneCompletionSheet(userId: userId),
  );
}

class _PhoneCompletionSheet extends StatefulWidget {
  const _PhoneCompletionSheet({required this.userId});
  final String userId;

  @override
  State<_PhoneCompletionSheet> createState() => _PhoneCompletionSheetState();
}

class _PhoneCompletionSheetState extends State<_PhoneCompletionSheet> {
  static final Country _defaultCountry =
      countries.firstWhere((c) => c.code == 'SA');
  Country _selectedCountry = _defaultCountry;
  final _phoneController = TextEditingController();
  bool _saving = false;
  String? _error;

  // Study-destination country — separate from the phone dial code above,
  // same distinction registration itself makes.
  String? _selectedCountryCode;
  String? _selectedCountryNameAr;
  String? _selectedCountryNameEn;
  String? _selectedCountryFlag;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context)!;
    final digits = _phoneController.text.trim();
    final min = _selectedCountry.minLength;
    final max = _selectedCountry.maxLength;
    if (digits.length < min || digits.length > max) {
      setState(() => _error = l10n.validPhoneInvalid);
      return;
    }

    setState(() { _saving = true; _error = null; });
    try {
      await appDio.patch('/users/${widget.userId}', data: {
        'phone_number': '+${_selectedCountry.dialCode}$digits',
        if (_selectedCountryCode != null) 'country_code':    _selectedCountryCode,
        if (_selectedCountryNameAr != null) 'country_name_ar': _selectedCountryNameAr,
        if (_selectedCountryNameEn != null) 'country_name_en': _selectedCountryNameEn,
        if (_selectedCountryFlag != null) 'country_flag':    _selectedCountryFlag,
      });
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) setState(() { _saving = false; _error = l10n.genericError; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: EdgeInsets.fromLTRB(
          24, 12, 24, MediaQuery.of(context).padding.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(
              l10n.completeYourProfile,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Cairo', fontSize: 17,
                fontWeight: FontWeight.w800, color: AppColors.deepDark,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.phoneRequiredForAccount,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Tajawal', fontSize: 13.5,
                color: AppColors.textSecondary, height: 1.6,
              ),
            ),
            const SizedBox(height: 20),
            Directionality(
              textDirection: TextDirection.ltr,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: () => showCountryPickerSheet(
                      context,
                      onSelected: (c) => setState(() => _selectedCountry = c),
                    ),
                    child: Container(
                      height: 54,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color:        AppColors.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.fieldBorder, width: 1.2),
                      ),
                      alignment: Alignment.center,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_selectedCountry.flag, style: const TextStyle(fontSize: 20)),
                          const SizedBox(width: 6),
                          Text(
                            '+${_selectedCountry.dialCode}',
                            style: const TextStyle(
                              fontFamily: 'Cairo', fontSize: 14,
                              fontWeight: FontWeight.w600, color: AppColors.darkText,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: SizedBox(
                      height: 54,
                      child: TextField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        textDirection: TextDirection.ltr,
                        style: const TextStyle(fontFamily: 'Cairo', fontSize: 15),
                        maxLength: _selectedCountry.maxLength,
                        decoration: InputDecoration(
                          counterText: '',
                          filled: true,
                          fillColor: AppColors.surface,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(color: AppColors.fieldBorder, width: 1.2),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(color: AppColors.fieldBorder, width: 1.2),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(color: AppColors.primary, width: 1.6),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            GestureDetector(
              onTap: () => showHomeCountryPickerSheet(
                context,
                selectedCode: _selectedCountryCode,
                onSelected: (c) => setState(() {
                  _selectedCountryCode   = c.code;
                  _selectedCountryNameAr = c.nameAr;
                  _selectedCountryNameEn = c.nameEn;
                  _selectedCountryFlag   = c.flag;
                }),
              ),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
                decoration: BoxDecoration(
                  color:        AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.fieldBorder, width: 1.2),
                ),
                child: Row(
                  children: [
                    if (_selectedCountryFlag != null) ...[
                      Text(_selectedCountryFlag!, style: const TextStyle(fontSize: 20)),
                      const SizedBox(width: 10),
                      Text(
                        _selectedCountryNameAr!,
                        style: const TextStyle(
                          fontFamily: 'Cairo', fontSize: 15,
                          fontWeight: FontWeight.w600, color: AppColors.darkText,
                        ),
                      ),
                      const Spacer(),
                    ] else ...[
                      Expanded(
                        child: Text(
                          l10n.selectYourCountry,
                          style: const TextStyle(
                            fontFamily: 'Tajawal', fontSize: 14, color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                    const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: AppColors.textSecondary, size: 20,
                    ),
                  ],
                ),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'Tajawal', fontSize: 12.5, color: AppColors.error,
                ),
              ),
            ],
            const SizedBox(height: 20),
            SizedBox(
              height: 52,
              child: FilledButton(
                onPressed: _saving ? null : _save,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 22, height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5, color: AppColors.white,
                        ),
                      )
                    : Text(
                        l10n.saveBio, // "Save" — reused, generic enough
                        style: const TextStyle(
                          fontFamily: 'Cairo', fontWeight: FontWeight.w700,
                          fontSize: 15, color: AppColors.white,
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

// ─────────────────────────────────────────────────────────────────────────

Future<void> showBioPromptSheet(
  BuildContext context, {
  required String userId,
}) {
  return showModalBottomSheet<void>(
    context:            context,
    backgroundColor:    AppColors.white,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (sheetCtx) => _BioPromptSheet(userId: userId),
  );
}

class _BioPromptSheet extends StatefulWidget {
  const _BioPromptSheet({required this.userId});
  final String userId;

  @override
  State<_BioPromptSheet> createState() => _BioPromptSheetState();
}

class _BioPromptSheetState extends State<_BioPromptSheet> {
  final _bioController = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final text = _bioController.text.trim();
    if (text.isEmpty) {
      Navigator.of(context).pop();
      return;
    }
    setState(() => _saving = true);
    try {
      await appDio.patch('/users/${widget.userId}', data: {'bio': text});
    } catch (_) {
      // Non-fatal — the user can always set it later from Settings/Profile.
    } finally {
      if (mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: EdgeInsets.fromLTRB(
          24, 12, 24, MediaQuery.of(context).padding.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(
              l10n.writeYourBio,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Cairo', fontSize: 17,
                fontWeight: FontWeight.w800, color: AppColors.deepDark,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.bioPromptHint,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Tajawal', fontSize: 13.5,
                color: AppColors.textSecondary, height: 1.6,
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _bioController,
              maxLength: 500,
              maxLines: 4,
              textAlign: TextAlign.start,
              style: const TextStyle(fontFamily: 'Tajawal', fontSize: 14.5),
              decoration: InputDecoration(
                hintText: l10n.bioPromptPlaceholder,
                filled: true,
                fillColor: AppColors.surface,
                contentPadding: const EdgeInsets.all(14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: AppColors.fieldBorder, width: 1.2),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: AppColors.fieldBorder, width: 1.2),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: AppColors.primary, width: 1.6),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 50,
                    child: OutlinedButton(
                      onPressed: _saving ? null : () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.fieldBorder, width: 1.2),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: Text(
                        l10n.skipForNow,
                        style: const TextStyle(
                          fontFamily: 'Cairo', fontWeight: FontWeight.w600,
                          fontSize: 14, color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SizedBox(
                    height: 50,
                    child: FilledButton(
                      onPressed: _saving ? null : _save,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: _saving
                          ? const SizedBox(
                              width: 20, height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5, color: AppColors.white,
                              ),
                            )
                          : Text(
                              l10n.saveBio,
                              style: const TextStyle(
                                fontFamily: 'Cairo', fontWeight: FontWeight.w700,
                                fontSize: 14, color: AppColors.white,
                              ),
                            ),
                    ),
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

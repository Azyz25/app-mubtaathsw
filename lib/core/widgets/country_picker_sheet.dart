// lib/core/widgets/country_picker_sheet.dart
//
// Shared searchable country picker bottom sheet — used by registration's
// phone field and the post-signup phone-completion sheet (Google/Apple
// sign-in), so both stay visually and behaviourally identical.

import 'package:flutter/material.dart';
import 'package:intl_phone_field/countries.dart' show countries, Country;
import 'package:mubtaath/core/l10n/app_localizations.dart';
import 'package:mubtaath/core/theme/app_colors.dart';

void showCountryPickerSheet(
  BuildContext context, {
  required ValueChanged<Country> onSelected,
}) {
  final l10n = AppLocalizations.of(context)!;
  final lang = Localizations.localeOf(context).languageCode;
  showModalBottomSheet<void>(
    context:            context,
    backgroundColor:    AppColors.background,
    isScrollControlled: true,
    constraints: BoxConstraints(
      maxHeight: MediaQuery.of(context).size.height * 0.78,
    ),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (sheetCtx) {
      var query = '';
      return StatefulBuilder(
        builder: (context, setLocalState) {
          final visible = query.trim().isEmpty
              ? countries
              : countries.where((c) {
                  final q = query.trim().toLowerCase();
                  return c.localizedName(lang).toLowerCase().contains(q) ||
                      c.name.toLowerCase().contains(q) ||
                      c.dialCode.contains(q);
                }).toList();

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 4),
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: AppColors.cardBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 4),
                child: Text(
                  l10n.selectYourCountry,
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: TextField(
                  autofocus: false,
                  onChanged: (v) => setLocalState(() => query = v),
                  textAlign: TextAlign.start,
                  style: const TextStyle(fontFamily: 'Cairo', fontSize: 14),
                  decoration: InputDecoration(
                    hintText: l10n.searchHint,
                    prefixIcon: const Icon(Icons.search, size: 20, color: AppColors.textSecondary),
                    filled: true,
                    fillColor: AppColors.surface,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.fieldBorder, width: 1.2),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.fieldBorder, width: 1.2),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.primary, width: 1.6),
                    ),
                  ),
                ),
              ),
              const Divider(height: 1),
              Flexible(
                child: ListView.builder(
                  itemCount: visible.length,
                  itemBuilder: (_, i) {
                    final c = visible[i];
                    return ListTile(
                      onTap: () {
                        onSelected(c);
                        Navigator.of(sheetCtx).pop();
                      },
                      leading: Text(c.flag, style: const TextStyle(fontSize: 22)),
                      title: Text(
                        c.localizedName(lang),
                        style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.darkText,
                        ),
                      ),
                      trailing: Text(
                        '+${c.dialCode}',
                        style: const TextStyle(
                          fontFamily: 'Tajawal',
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      );
    },
  );
}

// lib/core/widgets/home_country_picker_sheet.dart
//
// Shared "which country are you studying in" picker — the small, curated
// list of supported study destinations. Distinct from country_picker_sheet.dart,
// which is the full ~200-country list used only for phone dial codes.
// Used by registration and the post-signup completion sheet (Google/Apple
// sign-in), so both stay visually and behaviourally identical.

import 'package:flutter/material.dart';
import 'package:mubtaath/core/l10n/app_localizations.dart';
import 'package:mubtaath/core/theme/app_colors.dart';

class HomeCountryEntry {
  final String nameAr;
  final String nameEn;
  final String code;
  final String flag;
  const HomeCountryEntry(this.nameAr, this.nameEn, this.code, this.flag);
}

const kSupportedHomeCountries = <HomeCountryEntry>[
  HomeCountryEntry('بريطانيا',  'United Kingdom', 'GB', '🇬🇧'),
  HomeCountryEntry('أستراليا',  'Australia',      'AU', '🇦🇺'),
  HomeCountryEntry('أمريكا',    'United States',  'US', '🇺🇸'),
  HomeCountryEntry('كندا',      'Canada',         'CA', '🇨🇦'),
];

void showHomeCountryPickerSheet(
  BuildContext context, {
  required ValueChanged<HomeCountryEntry> onSelected,
  String? selectedCode,
}) {
  final l10n = AppLocalizations.of(context)!;
  showModalBottomSheet<void>(
    context:            context,
    backgroundColor:    AppColors.background,
    isScrollControlled: true,
    constraints: BoxConstraints(
      maxHeight: MediaQuery.of(context).size.height * 0.75,
    ),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (sheetCtx) => Column(
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
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Text(
            l10n.fieldCountry,
            style: const TextStyle(
              fontFamily: 'Cairo',
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
        ),
        const Divider(height: 1),
        Flexible(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ...kSupportedHomeCountries.map((c) => ListTile(
                  onTap: () {
                    onSelected(c);
                    Navigator.of(sheetCtx).pop();
                  },
                  leading: Text(c.flag, style: const TextStyle(fontSize: 22)),
                  title: Text(
                    c.nameAr,
                    style: const TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.darkText,
                    ),
                  ),
                  trailing: selectedCode == c.code
                      ? const Icon(Icons.check_circle, color: AppColors.primary, size: 20)
                      : null,
                )),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

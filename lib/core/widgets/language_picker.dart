import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mubtaath/core/bloc/language_cubit.dart';
import 'package:mubtaath/core/l10n/app_localizations.dart';
import 'package:mubtaath/core/theme/app_colors.dart';

/// Shows the app-wide language selection bottom sheet.
/// Safe to call from any page — reads [LanguageCubit] from the root tree.
void showLanguagePicker(BuildContext context) {
  final languageCubit = context.read<LanguageCubit>();
  final l10n          = AppLocalizations.of(context)!;

  showModalBottomSheet(
    context:         context,
    showDragHandle:  false,
    backgroundColor: AppColors.background,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => BlocProvider.value(
      value: languageCubit,
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(horizontal: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 38, height: 4,
              decoration: BoxDecoration(
                color: AppColors.cardBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              l10n.appLanguage,
              style: const TextStyle(
                fontFamily: 'Cairo', fontSize: 17,
                fontWeight: FontWeight.w800, color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 16),
            _LangOption(flag: '🇸🇦', langName: l10n.arabic,  code: 'ar'),
            const SizedBox(height: 12),
            _LangOption(flag: '🇬🇧', langName: l10n.english, code: 'en'),
            const SizedBox(height: 28),
          ],
        ),
      ),
    ),
  );
}

class _LangOption extends StatelessWidget {
  final String flag;
  final String langName;
  final String code;

  const _LangOption({
    required this.flag,
    required this.langName,
    required this.code,
  });

  @override
  Widget build(BuildContext context) {
    final currentCode = context.watch<LanguageCubit>().state.languageCode;
    final isSelected  = currentCode == code;

    return GestureDetector(
      onTap: () {
        if (!isSelected) {
          context.read<LanguageCubit>().changeLanguage(code);
        }
        Navigator.of(context).pop();
      },
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
            Icon(
              isSelected ? LucideIcons.checkCircle2 : LucideIcons.circle,
              color: isSelected ? AppColors.primary : AppColors.cardBorder,
              size:  20,
            ),
            const Spacer(),
            Text(
              langName,
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize:   15,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? AppColors.primary : AppColors.darkText,
              ),
            ),
            const SizedBox(width: 10),
            Text(flag, style: const TextStyle(fontSize: 22)),
          ],
        ),
      ),
    );
  }
}

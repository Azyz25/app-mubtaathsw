import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mubtaath/core/auth_notifier.dart';
import 'package:mubtaath/core/l10n/app_localizations.dart';
import 'package:mubtaath/core/theme/app_colors.dart';
import 'package:mubtaath/core/services/secure_storage_service.dart';

class AccountSuspendedPage extends StatelessWidget {
  const AccountSuspendedPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),

              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.10),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  LucideIcons.shieldOff,
                  color: AppColors.error,
                  size: 38,
                ),
              ),

              const SizedBox(height: 28),

              Text(
                l10n.accountSuspendedTitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppColors.darkText,
                ),
              ),

              const SizedBox(height: 12),

              Text(
                l10n.accountSuspendedBody,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'Tajawal',
                  fontSize: 14,
                  color: AppColors.textSecondary,
                  height: 1.65,
                ),
              ),

              const SizedBox(height: 40),

              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => context.go('/support'),
                  icon: const Icon(LucideIcons.messageCircle, size: 16),
                  label: Text(
                    l10n.contactSupport,
                    style: const TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 14),

              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () async {
                    await SecureStorageService.clearAll();
                    suspendedNotifier.value = false;
                    authNotifier.value = false;
                    if (context.mounted) context.go('/login');
                  },
                  child: Text(
                    l10n.logout,
                    style: const TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ),

              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}

// lib/features/reports/presentation/pages/public_contact_page.dart
//
// Contact Support — reachable WITHOUT an account. Apple requires support be
// reachable pre-signup; this posts to a public (no-auth) backend endpoint
// that emails the message to support, separate entirely from the
// authenticated Report/ticket system in support_page.dart.

import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mubtaath/core/l10n/app_localizations.dart';
import 'package:mubtaath/core/services/dio_client.dart';
import 'package:mubtaath/core/theme/app_colors.dart';
import 'package:mubtaath/core/widgets/mubtaath_loader.dart';

class PublicContactPage extends StatefulWidget {
  const PublicContactPage({super.key});

  @override
  State<PublicContactPage> createState() => _PublicContactPageState();
}

class _PublicContactPageState extends State<PublicContactPage> {
  final _formKey          = GlobalKey<FormState>();
  final _emailController  = TextEditingController();
  final _messageController = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _emailController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context)!;
    if (!_formKey.currentState!.validate()) return;

    setState(() => _sending = true);
    try {
      await appDio.post('/support/contact', data: {
        'email':   _emailController.text.trim(),
        'message': _messageController.text.trim(),
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            l10n.contactMessageSent,
            style: const TextStyle(fontFamily: 'Tajawal', color: AppColors.white),
          ),
          backgroundColor: AppColors.primary,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ),
      );
      Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            l10n.genericError,
            style: const TextStyle(fontFamily: 'Tajawal', color: AppColors.white),
          ),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor:        AppColors.background,
        elevation:              0,
        scrolledUnderElevation: 0,
        leading: const BackButton(color: AppColors.darkText),
        title: Text(
          l10n.contactSupport,
          style: const TextStyle(
            fontFamily: 'Cairo',
            fontSize:   17,
            fontWeight: FontWeight.w800,
            color:      AppColors.darkText,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsetsDirectional.symmetric(horizontal: 20, vertical: 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 56, height: 56,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.10),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(LucideIcons.headphones, color: AppColors.primary, size: 26),
                ),
                const SizedBox(height: 16),
                Text(
                  l10n.contactSupportSubtitle,
                  style: const TextStyle(
                    fontFamily: 'Tajawal',
                    fontSize:   13.5,
                    color:      AppColors.textSecondary,
                    height:     1.6,
                  ),
                ),
                const SizedBox(height: 28),

                Text(
                  l10n.yourEmail,
                  style: const TextStyle(
                    fontFamily: 'Cairo', fontSize: 14,
                    fontWeight: FontWeight.w700, color: AppColors.darkText,
                  ),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller:   _emailController,
                  keyboardType: TextInputType.emailAddress,
                  textDirection: TextDirection.ltr,
                  style: const TextStyle(fontFamily: 'Tajawal', fontSize: 14),
                  decoration: InputDecoration(
                    filled:         true,
                    fillColor:      AppColors.surface,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
                  validator: (v) {
                    final value = v?.trim() ?? '';
                    final emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
                    if (value.isEmpty || !emailPattern.hasMatch(value)) {
                      return l10n.validEmailInvalid;
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 20),
                Text(
                  l10n.yourMessage,
                  style: const TextStyle(
                    fontFamily: 'Cairo', fontSize: 14,
                    fontWeight: FontWeight.w700, color: AppColors.darkText,
                  ),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _messageController,
                  maxLines:   6,
                  textDirection: TextDirection.rtl,
                  textAlign:     TextAlign.right,
                  style: const TextStyle(fontFamily: 'Tajawal', fontSize: 13.5),
                  decoration: InputDecoration(
                    hintText: l10n.describeYourIssue,
                    hintStyle: const TextStyle(
                      fontFamily: 'Tajawal', fontSize: 13, color: AppColors.textSecondary,
                    ),
                    filled:         true,
                    fillColor:      AppColors.surface,
                    contentPadding: const EdgeInsets.all(16),
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
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return l10n.descriptionRequired;
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _sending ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                      disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.55),
                    ),
                    child: _sending
                        ? const SizedBox(
                            width: 22, height: 22,
                            child: MubtaathLoader(color: AppColors.white, strokeWidth: 2.5),
                          )
                        : Text(
                            l10n.sendMessage,
                            style: const TextStyle(
                              fontFamily: 'Cairo', fontSize: 15, fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

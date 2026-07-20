// lib/core/security/tamper_warning_gate.dart
//
// Wraps the whole app (via MaterialApp.builder) and shows a single
// dismissible warning the first time TamperGuardService reports a
// root/debugger/hooking/emulator/dev-mode/ADB threat. Living at the
// MaterialApp.builder level — rather than inside any specific page — means
// it works regardless of which screen the app happens to be on when the
// native side finishes its check, without needing a shared navigator key.

import 'package:flutter/material.dart';
import 'package:mubtaath/core/auth_notifier.dart';
import 'package:mubtaath/core/l10n/app_localizations.dart';
import 'package:mubtaath/core/security/tamper_guard_service.dart';
import 'package:mubtaath/core/theme/app_colors.dart';

class TamperWarningGate extends StatefulWidget {
  final Widget child;
  const TamperWarningGate({super.key, required this.child});

  @override
  State<TamperWarningGate> createState() => _TamperWarningGateState();
}

class _TamperWarningGateState extends State<TamperWarningGate> {
  bool _shown = false;

  @override
  void initState() {
    super.initState();
    tamperThreatNotifier.addListener(_onThreat);
    // Covers the race where the threat was already detected (and the
    // notifier set) before this widget existed.
    if (tamperThreatNotifier.value != null) _onThreat();
  }

  @override
  void dispose() {
    tamperThreatNotifier.removeListener(_onThreat);
    super.dispose();
  }

  void _onThreat() {
    final threat = tamperThreatNotifier.value;
    if (threat == null || _shown) return;
    _shown = true;
    WidgetsBinding.instance.addPostFrameCallback((_) => _showWarning(threat));
  }

  String _messageFor(TamperThreat threat, AppLocalizations l10n) {
    switch (threat) {
      case TamperThreat.root:      return l10n.securityWarningRoot;
      case TamperThreat.debug:     return l10n.securityWarningDebug;
      case TamperThreat.hooks:     return l10n.securityWarningHooks;
      case TamperThreat.emulator:  return l10n.securityWarningEmulator;
      case TamperThreat.devMode:   return l10n.securityWarningDevMode;
      case TamperThreat.adb:       return l10n.securityWarningAdb;
    }
  }

  void _showWarning(TamperThreat threat) {
    if (!mounted) return;
    final ctx = context;
    final l10n = AppLocalizations.of(ctx)!;
    showDialog<void>(
      context: ctx,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(
          l10n.securityWarningTitle,
          style: const TextStyle(
            fontFamily: 'Cairo', fontSize: 17,
            fontWeight: FontWeight.w800, color: AppColors.darkText,
          ),
        ),
        content: Text(
          _messageFor(threat, l10n),
          style: const TextStyle(
            fontFamily: 'Tajawal', fontSize: 14,
            color: AppColors.textSecondary, height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: Text(
              l10n.gotIt,
              style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

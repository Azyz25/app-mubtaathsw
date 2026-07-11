// =============================================================================
// MUBTAATH APP — OTP VERIFICATION PAGE  (v2 — pinput rewrite)
// =============================================================================
// File Path  : lib/features/auth/presentation/pages/otp_verification_page.dart
// Design Ref : تطبيق_مبتعث.pdf — Page 5
// Package    : pinput ^5.0.0  →  add to pubspec.yaml
// State Mgmt : flutter_bloc (OtpCubit)
// Navigation : success → context.go('/home') | back → context.pop()
//
// FIX LOG (v2):
//  ✅ Removed KeyboardListener wrapper  → was causing double-border visual bug
//  ✅ Removed AnimatedContainer wrapper → was creating 3 nested paint layers
//  ✅ Replaced manual FocusNode list    → pinput handles focus natively
//  ✅ Auto-advance / backspace-retreat  → built into pinput, zero custom code
//  ✅ Paste support (4 or 6 digits)     → pinput handles clipboard paste natively
//  ✅ Single source of truth for style  → PinTheme defines all visual states
//
// pubspec.yaml — add this dependency:
//   dependencies:
//     pinput: ^5.0.0
//     flutter_bloc: ^8.1.5
//     go_router: ^14.0.0
// =============================================================================

import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:pinput/pinput.dart';
import 'package:mubtaath/core/auth_notifier.dart';
import 'package:mubtaath/core/bloc/language_cubit.dart';
import 'package:mubtaath/core/services/dio_client.dart';
import 'package:mubtaath/core/services/language_sync_service.dart';
import 'package:mubtaath/core/services/secure_storage_service.dart';
import 'package:mubtaath/core/theme/app_colors.dart';
import 'package:mubtaath/core/l10n/app_localizations.dart';
import 'package:mubtaath/core/widgets/shared_widgets.dart';

// =============================================================================
// SECTION 1 — OTP STATE  (→ cubit/otp_state.dart)
// =============================================================================

abstract class OtpState {
  const OtpState();
}

class OtpInitial extends OtpState {
  const OtpInitial();
}

class OtpLoading extends OtpState {
  const OtpLoading();
}

class OtpSuccess extends OtpState {
  const OtpSuccess();
}

class OtpResendOk extends OtpState {
  const OtpResendOk();
}

class OtpFailure extends OtpState {
  final String message;
  const OtpFailure(this.message);
}

// =============================================================================
// SECTION 2 — OTP CUBIT  (→ cubit/otp_cubit.dart)
// =============================================================================

class OtpCubit extends Cubit<OtpState> {
  OtpCubit() : super(const OtpInitial());

  Future<void> verifyOtp({required String email, required String code}) async {
    if (state is OtpLoading) return;
    if (code.length < 6) {
      emit(const OtpFailure('otpIncompleteError'));
      return;
    }
    emit(const OtpLoading());
    try {
      final response = await appDio.post('/auth/verify-otp', data: {
        'email': email,
        'otp':   code,
      });
      final token = response.data['data']['accessToken'] as String;
      await SecureStorageService.saveAuthToken(token);
      emit(const OtpSuccess());
    } on DioException catch (e) {
      final msg = e.response?.data?['message'] as String?;
      emit(OtpFailure(msg ?? 'otpInvalidError'));
    } catch (_) {
      emit(const OtpFailure('otpInvalidError'));
    }
  }

  Future<void> resendOtp({required String email}) async {
    if (state is OtpLoading) return;
    emit(const OtpLoading());
    try {
      await appDio.post('/auth/resend-otp', data: {'email': email});
      emit(const OtpResendOk());
    } on DioException catch (e) {
      final msg = e.response?.data?['message'] as String?;
      emit(OtpFailure(msg ?? 'otpResendError'));
    } catch (_) {
      emit(const OtpFailure('otpResendError'));
    }
  }

  void reset() => emit(const OtpInitial());
}


// =============================================================================
// SECTION 4 — PIN THEMES FACTORY
// Single place to define ALL visual states — no duplication anywhere.
// =============================================================================

class _PinThemes {
  // ── Shared decoration base ─────────────────────────────────────────────────
  static BoxDecoration _base({
    required Color borderColor,
    required double borderWidth,
    List<BoxShadow>? shadows,
  }) =>
      BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: borderColor,
          width: borderWidth,
        ),
        boxShadow: shadows,
      );

  // ── Cell size extracted from PDF ───────────────────────────────────────────
  // Screen width ≈ 390px | 6 cells | horizontal padding 24px each side
  // Available = 390 - 48 = 342px | spacing ~8px × 5 = 40px
  // Cell width = (342 - 40) / 6 ≈ 50px | height = 62px (portrait ratio)
  static const Size _cellSize = Size(50, 62);

  // ── Text style for digits ──────────────────────────────────────────────────
  static const TextStyle _digitStyle = TextStyle(
    fontFamily: 'Cairo',
    fontSize: 22,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
  );

  // ── Default (empty, unfocused) ─────────────────────────────────────────────
  static PinTheme get defaultTheme => PinTheme(
        width: _cellSize.width,
        height: _cellSize.height,
        textStyle: _digitStyle,
        decoration: _base(
          borderColor: AppColors.fieldBorder,
          borderWidth: 1.2,
        ),
      );

  // ── Focused (active cell) ──────────────────────────────────────────────────
  static PinTheme get focusedTheme => PinTheme(
        width: _cellSize.width,
        height: _cellSize.height,
        textStyle: _digitStyle,
        decoration: _base(
          borderColor: AppColors.primary,
          borderWidth: 1.8,
          shadows: [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.14),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
      );

  // ── Submitted (filled, unfocused) ─────────────────────────────────────────
  static PinTheme get submittedTheme => PinTheme(
        width: _cellSize.width,
        height: _cellSize.height,
        textStyle: _digitStyle,
        decoration: _base(
          borderColor: AppColors.primary.withOpacity(0.45),
          borderWidth: 1.2,
        ),
      );

  // ── Error state ────────────────────────────────────────────────────────────
  static PinTheme get errorTheme => PinTheme(
        width: _cellSize.width,
        height: _cellSize.height,
        textStyle: _digitStyle.copyWith(color: AppColors.inputError),
        decoration: _base(
          borderColor: AppColors.inputError,
          borderWidth: 1.8,
        ),
      );
}

// =============================================================================
// SECTION 5 — OTP VERIFICATION PAGE
// =============================================================================

class OtpVerificationPage extends StatefulWidget {
  /// Email displayed in subtitle — passed from RegisterPage via GoRouter extra
  final String email;

  const OtpVerificationPage({
    super.key,
    this.email = 'example@example.com',
  });

  @override
  State<OtpVerificationPage> createState() => _OtpVerificationPageState();
}

class _OtpVerificationPageState extends State<OtpVerificationPage> {
  // ── pinput controller — single controller, no FocusNode list needed ────────
  final TextEditingController _pinController = TextEditingController();

  // ── Error flag — drives errorTheme on all cells simultaneously ─────────────
  bool _hasError = false;

  // ── Resend countdown ───────────────────────────────────────────────────────
  static const int _startSeconds = 59;
  int _secondsLeft = _startSeconds;
  bool _canResend = false;
  Timer? _timer;

  // ── Cubit reference (injected via BlocProvider below) ─────────────────────
  late final OtpCubit _cubit;

  @override
  void initState() {
    super.initState();
    _cubit = OtpCubit();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pinController.dispose();
    _cubit.close();
    super.dispose();
  }

  // ── Timer ──────────────────────────────────────────────────────────────────

  void _startTimer() {
    setState(() {
      _secondsLeft = _startSeconds;
      _canResend = false;
    });
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() {
        if (_secondsLeft > 0) {
          _secondsLeft--;
        } else {
          _canResend = true;
          t.cancel();
        }
      });
    });
  }

  String get _timerLabel {
    final m = _secondsLeft ~/ 60;
    final s = (_secondsLeft % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  // ── Actions ────────────────────────────────────────────────────────────────

  void _verify() {
    FocusScope.of(context).unfocus();
    setState(() => _hasError = false);
    _cubit.verifyOtp(email: widget.email, code: _pinController.text);
  }

  void _resend() {
    if (!_canResend) return;
    _pinController.clear();
    setState(() => _hasError = false);
    _cubit.resendOtp(email: widget.email);
    _startTimer();
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            msg,
            textAlign: TextAlign.start,
            style: const TextStyle(
              fontFamily: 'Tajawal',
              fontSize: 14,
              color: Colors.white,
            ),
          ),
          backgroundColor: isError ? AppColors.inputError : AppColors.primary,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
          duration: const Duration(seconds: 3),
        ),
      );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _cubit,
      child: Scaffold(
          backgroundColor: AppColors.background,
          body: BlocConsumer<OtpCubit, OtpState>(
            listener: (ctx, state) {
              if (state is OtpSuccess) {
                // Token was already saved to SecureStorage inside OtpCubit.verifyOtp()
                authNotifier.value = true;
                // Sync the chosen locale on registration so notifications match it.
                LanguageSyncService.syncLocale(
                  ctx.read<LanguageCubit>().state.languageCode,
                );
                ctx.go('/home');
              } else if (state is OtpFailure) {
                setState(() => _hasError = true);
                final l10n = AppLocalizations.of(context)!;
                final String msg;
                switch (state.message) {
                  case 'otpIncompleteError':
                    msg = l10n.otpIncompleteError;
                    break;
                  case 'otpInvalidError':
                    msg = l10n.otpInvalidError;
                    break;
                  case 'otpResendError':
                    msg = l10n.otpResendError;
                    break;
                  default:
                    msg = state.message;
                }
                _showSnack(msg, isError: true);
              } else if (state is OtpResendOk) {
                _showSnack(AppLocalizations.of(context)!.newCodeSent);
              }
            },
            builder: (ctx, state) {
              final isLoading = state is OtpLoading;

              return SafeArea(
                child: Column(
                  children: [
                    // ── Fixed header: back button ────────────────────────
                    Padding(
                      padding: const EdgeInsetsDirectional.only(
                        start: 24, top: 12, bottom: 4,
                      ),
                      child: Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: _BackButton(
                          enabled: !isLoading,
                          onTap: () => context.canPop()
                              ? context.pop()
                              : context.go('/register'),
                        ),
                      ),
                    ),

                    // ── Scrollable body ──────────────────────────────────
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const SizedBox(height: 24),

                            // ── Title ────────────────────────────────────
                            Text(
                              AppLocalizations.of(context)!.emailConfirmation,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 26,
                                fontWeight: FontWeight.w800,
                                color: AppColors.primary,
                                height: 1.3,
                              ),
                            ),

                            const SizedBox(height: 10),

                            // ── Subtitle ─────────────────────────────────
                            Text(
                              AppLocalizations.of(context)!.otpEnterCode,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontFamily: 'Tajawal',
                                fontSize: 14,
                                fontWeight: FontWeight.w400,
                                color: AppColors.textSecondary,
                                height: 1.5,
                              ),
                            ),

                            const SizedBox(height: 4),

                            // ── Email label ───────────────────────────────
                            Text(
                              widget.email,
                              textAlign: TextAlign.center,
                              textDirection: TextDirection.ltr, // always LTR
                              style: const TextStyle(
                                fontFamily: 'Tajawal',
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary,
                              ),
                            ),

                            const SizedBox(height: 52),

                            // ── OTP INPUT (pinput) ────────────────────────
                            // pinput renders a SINGLE TextField internally.
                            // The cursor is invisible — each "cell" is just
                            // a styled Container painted over the hidden field.
                            // This eliminates ALL double-border issues.
                            Pinput(
                              controller: _pinController,
                              length: 6,
                              keyboardType: TextInputType.number,
                              autofocus: true,
                              enabled: !isLoading,

                              // ── Themes (single source of truth) ─────────
                              defaultPinTheme: _PinThemes.defaultTheme,
                              focusedPinTheme: _PinThemes.focusedTheme,
                              submittedPinTheme: _PinThemes.submittedTheme,
                              errorPinTheme:
                                  _hasError ? _PinThemes.errorTheme : null,

                              // ── Spacing between cells ────────────────────
                              // (342px available - 6*50px cells) / 5 gaps = ~8px
                              separatorBuilder: (_) => const SizedBox(width: 8),

                              // ── Auto-verify on completion ────────────────
                              onCompleted: (_) => _verify(),

                              // ── Clear error on any change ────────────────
                              onChanged: (_) {
                                if (_hasError) {
                                  setState(() => _hasError = false);
                                }
                              },

                              // ── Cursor: hidden (cells show the digit) ────
                              showCursor: true,
                              cursor: Column(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  Container(
                                    width: 20,
                                    height: 2,
                                    decoration: BoxDecoration(
                                      color: AppColors.primary,
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                ],
                              ),

                              // ── Haptic / error text ───────────────────────
                              // No error text shown below — we use SnackBar
                              errorText: null,

                              // ── Paste — handled natively by pinput ────────
                              // long-press → paste → all cells filled ✅
                            ),

                            const SizedBox(height: 48),

                            // ── Resend Timer ─────────────────────────────
                            _ResendSection(
                              canResend: _canResend,
                              timerLabel: _timerLabel,
                              enabled: !isLoading,
                              onResend: _resend,
                            ),

                            const SizedBox(height: 40),
                          ],
                        ),
                      ),
                    ),

                    // ── Verify button — pinned to bottom ─────────────────
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                      child: CorePrimaryButton(
                        label: AppLocalizations.of(context)!.verify,
                        isLoading: isLoading,
                        onPressed: _verify,
                      ),
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

// =============================================================================
// SECTION 6 — BACK BUTTON WIDGET  (private)
// =============================================================================

class _BackButton extends StatelessWidget {
  final bool enabled;
  final VoidCallback onTap;

  const _BackButton({required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppColors.fieldBorder,
              width: 1.2,
            ),
          ),
          child: const Icon(
            // Points RIGHT in RTL layout → visually means "go back"
            Icons.chevron_right_rounded,
            color: AppColors.textPrimary,
            size: 22,
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// SECTION 7 — RESEND SECTION WIDGET  (private)
// =============================================================================

class _ResendSection extends StatelessWidget {
  final bool canResend;
  final String timerLabel;
  final bool enabled;
  final VoidCallback onResend;

  const _ResendSection({
    required this.canResend,
    required this.timerLabel,
    required this.enabled,
    required this.onResend,
  });

  @override
  Widget build(BuildContext context) {
    // Design: "إعادة ارسال الرمز ( 0:45 )" — one line, bold, centered
    // Active:   primary green, fully tappable
    // Inactive: grey, timer shown in parentheses, not tappable

    final l10n = AppLocalizations.of(context)!;
    return GestureDetector(
      onTap: (canResend && enabled) ? onResend : null,
      child: AnimatedDefaultTextStyle(
        duration: const Duration(milliseconds: 200),
        style: TextStyle(
          fontFamily: 'Cairo',
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: canResend ? AppColors.primary : AppColors.textSecondary,
        ),
        child: Text(
          canResend ? l10n.resendCode : l10n.resendWithTimer(timerLabel),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

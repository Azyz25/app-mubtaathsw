// =============================================================================
// MUBTAATH — RESET PASSWORD PAGE
// =============================================================================
// Reached from ForgotPasswordPage after a reset code is requested.
// Flow: enter the 6-digit code (emailed) + a new password → POST
//       /auth/reset-password → back to /login.
//
// Honors project rules: AppColors-only, AppLocalizations-only, Cubit state.
// =============================================================================

import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:pinput/pinput.dart';
import 'package:mubtaath/core/l10n/app_localizations.dart';
import 'package:mubtaath/core/security/screenshot_blocker_mixin.dart';
import 'package:mubtaath/core/services/dio_client.dart';
import 'package:mubtaath/core/theme/app_colors.dart';
import 'package:mubtaath/core/widgets/shared_widgets.dart';

// =============================================================================
// SECTION 1 — STATE
// =============================================================================

enum ResetStatus { idle, loading, success, error, resent }

class ResetPasswordState {
  final ResetStatus status;

  /// Either a known l10n key (e.g. 'validPasswordMin') or a raw Arabic
  /// message returned by the backend — resolved in the page listener.
  final String? errorKey;

  const ResetPasswordState({
    this.status = ResetStatus.idle,
    this.errorKey,
  });

  bool get isLoading => status == ResetStatus.loading;

  ResetPasswordState copyWith({ResetStatus? status, String? errorKey}) =>
      ResetPasswordState(
        status: status ?? this.status,
        errorKey: errorKey ?? this.errorKey,
      );
}

// =============================================================================
// SECTION 2 — CUBIT
// =============================================================================

class ResetPasswordCubit extends Cubit<ResetPasswordState> {
  ResetPasswordCubit() : super(const ResetPasswordState());

  Future<void> submit({
    required String email,
    required String otp,
    required String password,
    required String confirmPassword,
  }) async {
    if (state.isLoading) return;

    // ── Client-side guards (mirror the backend rules) ──────────────────────
    if (otp.length < 6) {
      emit(state.copyWith(
          status: ResetStatus.error, errorKey: 'otpIncompleteError'));
      return;
    }
    if (password.length < 8) {
      emit(state.copyWith(
          status: ResetStatus.error, errorKey: 'validPasswordMin'));
      return;
    }
    if (password != confirmPassword) {
      emit(state.copyWith(
          status: ResetStatus.error, errorKey: 'validPasswordMismatch'));
      return;
    }

    emit(state.copyWith(status: ResetStatus.loading));

    try {
      await appDio.post('/auth/reset-password', data: {
        'email': email,
        'otp': otp,
        'password': password,
        'password_confirmation': confirmPassword,
      });
      emit(state.copyWith(status: ResetStatus.success));
    } on DioException catch (e) {
      final msg = e.response?.data?['message'] as String?;
      emit(state.copyWith(
          status: ResetStatus.error, errorKey: msg ?? 'genericError'));
    } catch (_) {
      emit(state.copyWith(status: ResetStatus.error, errorKey: 'genericError'));
    }
  }

  /// Re-requests a fresh reset code for the same email.
  Future<void> resend(String email) async {
    try {
      await appDio.post('/auth/forgot-password', data: {'email': email});
      emit(state.copyWith(status: ResetStatus.resent));
    } on DioException catch (e) {
      final msg = e.response?.data?['message'] as String?;
      emit(state.copyWith(
          status: ResetStatus.error, errorKey: msg ?? 'genericError'));
    } catch (_) {
      emit(state.copyWith(status: ResetStatus.error, errorKey: 'genericError'));
    }
  }
}

// =============================================================================
// SECTION 3 — PIN THEMES (AppColors-only)
// =============================================================================

class _ResetPinThemes {
  static const Size _cell = Size(48, 58);

  static const TextStyle _digit = TextStyle(
    fontFamily: 'Cairo',
    fontSize: 20,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
  );

  static BoxDecoration _base(Color border, double width,
          [List<BoxShadow>? shadows]) =>
      BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border, width: width),
        boxShadow: shadows,
      );

  static PinTheme get defaultTheme => PinTheme(
        width: _cell.width,
        height: _cell.height,
        textStyle: _digit,
        decoration: _base(AppColors.fieldBorder, 1.2),
      );

  static PinTheme get focusedTheme => PinTheme(
        width: _cell.width,
        height: _cell.height,
        textStyle: _digit,
        decoration: _base(AppColors.primary, 1.8, [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.14),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ]),
      );

  static PinTheme get submittedTheme => PinTheme(
        width: _cell.width,
        height: _cell.height,
        textStyle: _digit,
        decoration:
            _base(AppColors.primary.withValues(alpha: 0.45), 1.2),
      );

  static PinTheme get errorTheme => PinTheme(
        width: _cell.width,
        height: _cell.height,
        textStyle: _digit.copyWith(color: AppColors.inputError),
        decoration: _base(AppColors.inputError, 1.8),
      );
}

// =============================================================================
// SECTION 4 — RESET PASSWORD PAGE
// =============================================================================

class ResetPasswordPage extends StatefulWidget {
  /// Email that requested the reset — passed from ForgotPasswordPage.
  final String email;

  const ResetPasswordPage({super.key, required this.email});

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage>
    with ScreenshotBlockerMixin<ResetPasswordPage> {
  final TextEditingController _pinCtrl = TextEditingController();
  final TextEditingController _passCtrl = TextEditingController();
  final TextEditingController _confirmCtrl = TextEditingController();

  bool _obscurePass = true;
  bool _obscureConfirm = true;
  bool _pinError = false;

  // ── Resend countdown ───────────────────────────────────────────────────────
  static const int _resendStart = 59;
  int _secondsLeft = _resendStart;
  bool _canResend = false;
  Timer? _timer;

  late final ResetPasswordCubit _cubit;

  @override
  void initState() {
    super.initState();
    _cubit = ResetPasswordCubit();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pinCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    _cubit.close();
    super.dispose();
  }

  void _startTimer() {
    setState(() {
      _secondsLeft = _resendStart;
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

  void _submit() {
    FocusScope.of(context).unfocus();
    setState(() => _pinError = false);
    _cubit.submit(
      email: widget.email,
      otp: _pinCtrl.text,
      password: _passCtrl.text,
      confirmPassword: _confirmCtrl.text,
    );
  }

  void _resend() {
    if (!_canResend) return;
    _cubit.resend(widget.email);
    _startTimer();
  }

  String _mapError(AppLocalizations l10n, String? key) {
    switch (key) {
      case 'otpIncompleteError':
        return l10n.otpIncompleteError;
      case 'validPasswordMin':
        return l10n.validPasswordMin;
      case 'validPasswordMismatch':
        return l10n.validPasswordMismatch;
      case 'genericError':
      case null:
        return l10n.genericError;
      default:
        return key; // backend Arabic message
    }
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
              color: AppColors.white,
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return BlocProvider.value(
      value: _cubit,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          toolbarHeight: 64,
          backgroundColor: AppColors.background,
          elevation: 0,
          scrolledUnderElevation: 0,
          automaticallyImplyLeading: false,
          leadingWidth: 80,
          leading: const Align(
            alignment: AlignmentDirectional.centerStart,
            child: Padding(
              padding: EdgeInsetsDirectional.only(start: 24),
              child: CoreBackButton(),
            ),
          ),
        ),
        body: BlocConsumer<ResetPasswordCubit, ResetPasswordState>(
          listener: (ctx, state) {
            switch (state.status) {
              case ResetStatus.success:
                _showSnack(l10n.passwordResetSuccess);
                // Capture the router before the async gap so we never touch
                // BuildContext after awaiting.
                final router = GoRouter.of(context);
                Future.delayed(const Duration(milliseconds: 850), () {
                  if (mounted) router.go('/login');
                });
                break;
              case ResetStatus.resent:
                _showSnack(l10n.newCodeSent);
                break;
              case ResetStatus.error:
                final isPasswordErr = state.errorKey == 'validPasswordMin' ||
                    state.errorKey == 'validPasswordMismatch';
                setState(() => _pinError = !isPasswordErr);
                _showSnack(_mapError(l10n, state.errorKey), isError: true);
                break;
              case ResetStatus.idle:
              case ResetStatus.loading:
                break;
            }
          },
          builder: (ctx, state) {
            final isLoading = state.isLoading;

            return SafeArea(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 12),

                    // ── Lock illustration ─────────────────────────────────
                    Container(
                      width: 62,
                      height: 62,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.08),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.18),
                          width: 1.5,
                        ),
                      ),
                      child: const Icon(
                        LucideIcons.lock,
                        color: AppColors.primary,
                        size: 28,
                      ),
                    ),

                    const SizedBox(height: 20),

                    // ── Title + subtitle ──────────────────────────────────
                    AuthHeader(
                      title: l10n.resetPasswordTitle,
                      subtitle: l10n.resetPasswordSubtitle,
                    ),

                    const SizedBox(height: 6),

                    // ── Email label (always LTR) ──────────────────────────
                    Text(
                      widget.email,
                      textAlign: TextAlign.center,
                      textDirection: TextDirection.ltr,
                      style: const TextStyle(
                        fontFamily: 'Tajawal',
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),

                    const SizedBox(height: 28),

                    // ── OTP code ──────────────────────────────────────────
                    Pinput(
                      controller: _pinCtrl,
                      length: 6,
                      keyboardType: TextInputType.number,
                      enabled: !isLoading,
                      defaultPinTheme: _ResetPinThemes.defaultTheme,
                      focusedPinTheme: _ResetPinThemes.focusedTheme,
                      submittedPinTheme: _ResetPinThemes.submittedTheme,
                      errorPinTheme:
                          _pinError ? _ResetPinThemes.errorTheme : null,
                      separatorBuilder: (_) => const SizedBox(width: 8),
                      onChanged: (_) {
                        if (_pinError) setState(() => _pinError = false);
                      },
                    ),

                    const SizedBox(height: 28),

                    // ── New password ──────────────────────────────────────
                    CoreTextField(
                      controller: _passCtrl,
                      hintText: l10n.newPasswordHint,
                      obscureText: _obscurePass,
                      enabled: !isLoading,
                      suffixIcon: IconButton(
                        onPressed: () =>
                            setState(() => _obscurePass = !_obscurePass),
                        icon: Icon(
                          _obscurePass
                              ? LucideIcons.eyeOff
                              : LucideIcons.eye,
                          size: 20,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),

                    const SizedBox(height: 14),

                    // ── Confirm password ──────────────────────────────────
                    CoreTextField(
                      controller: _confirmCtrl,
                      hintText: l10n.confirmPasswordHint,
                      obscureText: _obscureConfirm,
                      enabled: !isLoading,
                      suffixIcon: IconButton(
                        onPressed: () => setState(
                            () => _obscureConfirm = !_obscureConfirm),
                        icon: Icon(
                          _obscureConfirm
                              ? LucideIcons.eyeOff
                              : LucideIcons.eye,
                          size: 20,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),

                    const SizedBox(height: 28),

                    // ── Submit ────────────────────────────────────────────
                    CorePrimaryButton(
                      label: l10n.changePassword,
                      isLoading: isLoading,
                      onPressed: _submit,
                    ),

                    const SizedBox(height: 18),

                    // ── Resend ────────────────────────────────────────────
                    _ResendSection(
                      canResend: _canResend && !isLoading,
                      timerLabel: _timerLabel,
                      onResend: _resend,
                    ),

                    const SizedBox(height: 32),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

// =============================================================================
// SECTION 5 — RESEND SECTION
// =============================================================================

class _ResendSection extends StatelessWidget {
  final bool canResend;
  final String timerLabel;
  final VoidCallback onResend;

  const _ResendSection({
    required this.canResend,
    required this.timerLabel,
    required this.onResend,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return GestureDetector(
      onTap: canResend ? onResend : null,
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

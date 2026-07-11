// =============================================================================
// MUBTAATH APP — LOGIN PAGE
// =============================================================================
// File Path  : lib/features/auth/presentation/pages/login_page.dart
// Design Ref : تطبيق_مبتعث.pdf — Page 3
// State Mgmt : flutter_bloc (AuthCubit)
// Navigation : GoRouter — success → /home | register → /register
// Brand      : Primary #305544 | Secondary #B19369 | BG #F9F7F5
// Fonts      : Cairo (headings/buttons) | Tajawal (body/hints)
// =============================================================================
//
// FOLDER STRUCTURE — place each section in its correct path:
//
//  lib/features/auth/
//  ├── presentation/
//  │   ├── pages/
//  │   │   └── login_page.dart           ← THIS FILE
//  │   ├── cubit/
//  │   │   ├── auth_cubit.dart           ← AuthCubit class (section below)
//  │   │   └── auth_state.dart           ← AuthState sealed class
//  │   └── widgets/
//  │       ├── app_text_field.dart       ← AppTextField widget
//  │       └── main_button.dart          ← MainButton widget
//
// NOTE: All sections are combined here for single-artifact delivery.
//       Split into separate files as shown above when integrating.
// =============================================================================

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/gestures.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mubtaath/core/auth_notifier.dart';
import 'package:mubtaath/core/bloc/language_cubit.dart';
import 'package:mubtaath/core/services/dio_client.dart';
import 'package:mubtaath/core/services/language_sync_service.dart';
import 'package:mubtaath/core/services/secure_storage_service.dart';
import 'package:mubtaath/core/theme/app_colors.dart';
import 'package:mubtaath/core/l10n/app_localizations.dart';
import 'package:mubtaath/core/widgets/language_picker.dart';
import 'package:mubtaath/core/widgets/shared_widgets.dart';

// =============================================================================
// SECTION 2 — AUTH STATE
// Move to: lib/features/auth/presentation/cubit/auth_state.dart
// =============================================================================

abstract class AuthState {
  const AuthState();
}

/// Default state — form is idle
class AuthInitial extends AuthState {
  const AuthInitial();
}

/// API call in progress — button shows spinner
class AuthLoading extends AuthState {
  const AuthLoading();
}

/// Login succeeded — navigate to /home
class AuthSuccess extends AuthState {
  const AuthSuccess();
}

/// Login failed — show error message
class AuthFailure extends AuthState {
  final String message;
  const AuthFailure(this.message);
}

// =============================================================================
// SECTION 3 — AUTH CUBIT
// Move to: lib/features/auth/presentation/cubit/auth_cubit.dart
// =============================================================================

class AuthCubit extends Cubit<AuthState> {
  AuthCubit() : super(const AuthInitial());

  /// Simulates an async login call.
  /// Replace body with real UseCase injection when backend is ready:
  ///   final result = await _loginUseCase(email: email, password: password);
  Future<void> login({
    required String email,
    required String password,
  }) async {
    // Guard: prevent double-tap while loading
    if (state is AuthLoading) return;

    emit(const AuthLoading());

    try {
      final response = await appDio.post('/auth/login', data: {
        'email':    email.trim(),
        'password': password,
      });
      final token = response.data['data']['accessToken'] as String;
      await SecureStorageService.saveAuthToken(token);
      emit(const AuthSuccess());
    } on DioException catch (e) {
      final msg = e.response?.data?['message'] as String?;
      emit(AuthFailure(msg ?? 'loginError'));
    } catch (e, stackTrace) {
      debugPrint('[AuthCubit] UNEXPECTED ERROR: $e');
      debugPrint(stackTrace.toString());
      emit(const AuthFailure('genericError'));
    }
  }

  void resetState() => emit(const AuthInitial());
}

// =============================================================================
// SECTION 6 — GOOGLE SIGN-IN BUTTON
// Outlined variant — used only on login screen
// =============================================================================

class _GoogleButton extends StatelessWidget {
  final VoidCallback? onPressed;

  const _GoogleButton({this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: AppColors.surface,
          side: const BorderSide(color: AppColors.fieldBorder, width: 1.2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 18),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Google logo from asset with fallback
            Image.asset(
              'images/google_logo.png',
              width: 24,
              height: 24,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  width: 24,
                  height: 24,
                  decoration: const BoxDecoration(shape: BoxShape.circle),
                  child: const Center(
                    child: Text(
                      'G',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF4285F4),
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(width: 10),
            Text(
              AppLocalizations.of(context)!.signInWithGoogle,
              style: const TextStyle(
                fontFamily: 'Cairo',
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// SECTION 7 — OR DIVIDER WIDGET
// =============================================================================

class _OrDivider extends StatelessWidget {
  const _OrDivider();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(
          child: Divider(
            color: AppColors.divider,
            thickness: 1,
            endIndent: 12,
          ),
        ),
        Text(
          AppLocalizations.of(context)!.or,
          style: const TextStyle(
            fontFamily: 'Tajawal',
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: AppColors.textSecondary,
          ),
        ),
        const Expanded(
          child: Divider(
            color: AppColors.divider,
            thickness: 1,
            indent: 12,
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// SECTION 8 — LOGIN PAGE
// =============================================================================

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isPasswordVisible = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _onLoginPressed(AuthCubit cubit) {
    // Dismiss keyboard
    FocusScope.of(context).unfocus();

    cubit.login(
      email: _emailController.text.trim(),
      password: _passwordController.text,
    );
  }

  /// Shows a SnackBar for auth errors — matches brand style
  void _showErrorSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          textAlign: TextAlign.start,
          style: const TextStyle(
            fontFamily: 'Tajawal',
            fontSize: 14,
            color: Colors.white,
          ),
        ),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => AuthCubit(),
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: BlocConsumer<AuthCubit, AuthState>(
            listener: (context, state) {
              if (state is AuthSuccess) {
                // Token already saved to SecureStorage inside AuthCubit.login()
                authNotifier.value = true;
                // Push the user's chosen locale so notifications are localized.
                LanguageSyncService.syncLocale(
                  context.read<LanguageCubit>().state.languageCode,
                );
                context.go('/home');
              } else if (state is AuthFailure) {
                final l10n = AppLocalizations.of(context)!;
                final String msg;
                switch (state.message) {
                  case 'loginError':
                    msg = l10n.loginError;
                  case 'genericError':
                    msg = l10n.genericError;
                  default:
                    msg = state.message; // Arabic server message shown directly
                }
                _showErrorSnack(msg);
              }
            },
            builder: (context, state) {
              final cubit = context.read<AuthCubit>();
              final isLoading = state is AuthLoading;
              final l10n = AppLocalizations.of(context)!;

              return SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const SizedBox(height: 16),

                      // ── Language Toggle ───────────────────────────────
                      // Anchored to the leading edge so it follows the locale:
                      // start = right in Arabic (RTL), left in English (LTR).
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: Builder(
                          builder: (ctx) {
                            final code  = ctx.watch<LanguageCubit>().state.languageCode;
                            final label = code == 'ar' ? 'العربية' : 'English';
                            return GestureDetector(
                              onTap: () => showLanguagePicker(ctx),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color:        AppColors.surface,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: AppColors.cardBorder, width: 1.2,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      LucideIcons.languages,
                                      color: AppColors.primary, size: 15,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      label,
                                      style: const TextStyle(
                                        fontFamily: 'Cairo',
                                        fontSize:   12,
                                        fontWeight: FontWeight.w600,
                                        color:      AppColors.primary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),

                      const SizedBox(height: 32),

                      // ── Title ─────────────────────────────────────────
                      Text(
                        l10n.loginTitle,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 30,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary,
                          height: 1.3,
                        ),
                      ),

                      const SizedBox(height: 8),

                      // ── Subtitle ──────────────────────────────────────
                      Text(
                        l10n.loginSubtitle,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontFamily: 'Tajawal',
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                          color: AppColors.textSecondary,
                          height: 1.5,
                        ),
                      ),

                      const SizedBox(height: 48),

                      // ── Email Field ───────────────────────────────────
                      CoreTextField(
                        controller: _emailController,
                        hintText: l10n.email,
                        keyboardType: TextInputType.emailAddress,
                        enabled: !isLoading,
                        inputFormatters: [LengthLimitingTextInputFormatter(254)],
                      ),

                      const SizedBox(height: 16),

                      // ── Password Field ────────────────────────────────
                      CoreTextField(
                        controller: _passwordController,
                        hintText: l10n.password,
                        obscureText: !_isPasswordVisible,
                        enabled: !isLoading,
                        inputFormatters: [LengthLimitingTextInputFormatter(128)],
                        suffixIcon: GestureDetector(
                          onTap: isLoading
                              ? null
                              : () => setState(
                                    () => _isPasswordVisible =
                                        !_isPasswordVisible,
                                  ),
                          child: Icon(
                            _isPasswordVisible
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                            color: AppColors.textSecondary,
                            size: 22,
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),

                      // ── Forgot Password ───────────────────────────────
                      // Aligned to the right (RTL = leading edge)
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: GestureDetector(
                          onTap: isLoading
                              ? null
                              : () => context.push('/forgot-password'),
                          child: Text(
                            l10n.forgotPassword,
                            style: const TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 36),

                      // ── Login Button ──────────────────────────────────
                      CorePrimaryButton(
                        label: l10n.login,
                        isLoading: isLoading,
                        onPressed: () => _onLoginPressed(cubit),
                      ),

                      const SizedBox(height: 28),

                      // ── OR Divider ────────────────────────────────────
                      const _OrDivider(),

                      const SizedBox(height: 24),

                      // ── Google Login Button ───────────────────────────
                      _GoogleButton(
                        onPressed: isLoading
                            ? null
                            : () {
                                // TODO: Integrate Google Sign-In SDK
                              },
                      ),

                      const SizedBox(height: 40),

                      // ── Create Account Link ───────────────────────────
                      // Design: "ليس لديك حساب؟ إنشاء حساب"
                      // RTL: question appears on right, link on left
             // استبدل قسم الـ Row القديم بهذا الكود:

Center(
  child: RichText(
    text: TextSpan(
      style: const TextStyle(
        fontSize: 14.0, // توحيد الحجم للكل
        height: 1.0,    // لضمان عدم وجود مسافات عمودية زائدة
      ),
      children: [
        TextSpan(
          text: '${l10n.dontHaveAccount} ',
          style: const TextStyle(
            fontFamily: 'Tajawal',
            fontWeight: FontWeight.w400,
            color: AppColors.textSecondary,
          ),
        ),
        TextSpan(
          text: l10n.register,
          style: const TextStyle(
            fontFamily: 'Cairo',
            fontWeight: FontWeight.w700,
            color: AppColors.primary,
          ),
          recognizer: TapGestureRecognizer()
            ..onTap = isLoading
                ? null
                : () => context.push('/register'),
        ),
      ],
    ),
  ),
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
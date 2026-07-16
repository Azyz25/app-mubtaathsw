// =============================================================================
// MUBTAATH APP — REGISTER PAGE
// =============================================================================
// File Path  : lib/features/auth/presentation/pages/register_page.dart
// Design Ref : تطبيق_مبتعث.pdf — Page 4
// State Mgmt : flutter_bloc (RegisterCubit)
// Navigation : success → /otp | back → context.pop() → /login
// Brand      : Primary #305544 | Secondary #B19369 | BG #F9F7F5
// Fonts      : Cairo (headings/buttons/labels) | Tajawal (hints/body)
// =============================================================================
//
// FOLDER STRUCTURE — split into these paths when integrating:
//
//  lib/features/auth/
//  ├── presentation/
//  │   ├── pages/
//  │   │   └── register_page.dart              ← THIS FILE
//  │   ├── cubit/
//  │   │   ├── register_cubit.dart             ← RegisterCubit (Section 2)
//  │   │   └── register_state.dart             ← RegisterState (Section 1)
//  │   └── widgets/
//  │       ├── app_text_field.dart             ← AppTextField (reuse from login)
//  │       └── main_button.dart                ← MainButton (reuse from login)
//  └── domain/
//      └── utils/
//          └── form_validator.dart             ← FormValidator (Section 3)
//
// NOTE: AppColors, AppTextField, and MainButton are defined in login_page.dart.
//       They are re-declared here for standalone artifact delivery.
//       Remove duplicates when splitting into separate files.
// =============================================================================

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/gestures.dart';
import 'package:mubtaath/core/services/dio_client.dart';
import 'package:mubtaath/core/theme/app_colors.dart';
import 'package:mubtaath/core/l10n/app_localizations.dart';
import 'package:mubtaath/core/widgets/shared_widgets.dart';

// =============================================================================
// SECTION 1 — REGISTER STATE
// Move to: lib/features/auth/presentation/cubit/register_state.dart
// =============================================================================

abstract class RegisterState {
  const RegisterState();
}

class RegisterInitial extends RegisterState {
  const RegisterInitial();
}

class RegisterLoading extends RegisterState {
  const RegisterLoading();
}

/// Emitted after successful registration → navigate to OTP screen
class RegisterSuccess extends RegisterState {
  /// The email to display on the OTP screen
  final String email;
  const RegisterSuccess({required this.email});
}

/// Emitted on validation or server error
class RegisterFailure extends RegisterState {
  final String message;
  const RegisterFailure(this.message);
}

// =============================================================================
// SECTION 2 — REGISTER CUBIT
// Move to: lib/features/auth/presentation/cubit/register_cubit.dart
// =============================================================================

class RegisterCubit extends Cubit<RegisterState> {
  RegisterCubit() : super(const RegisterInitial());

  /// Validates inputs, then simulates an async registration call.
  /// Replace simulation with real UseCase injection when backend is ready:
  ///   final result = await _registerUseCase(params);
  Future<void> register({
    required String fullName,
    required String username,
    required String phone,
    required String email,
    required String password,
    required String confirmPassword,
    required bool acceptedTerms,
    String? countryCode,
    String? countryNameAr,
    String? countryNameEn,
    String? countryFlag,
  }) async {
    // Guard double-tap
    if (state is RegisterLoading) return;

    // ── Client-side validation ──────────────────────────────────────────────
    final validationError = FormValidator.validateRegister(
      fullName: fullName,
      username: username,
      phone: phone,
      email: email,
      password: password,
      confirmPassword: confirmPassword,
      acceptedTerms: acceptedTerms,
    );

    if (validationError != null) {
      emit(RegisterFailure(validationError));
      return;
    }

    emit(const RegisterLoading());

    try {
      await appDio.post('/auth/register', data: {
        'full_name':             fullName.trim(),
        'username':              username.trim(),
        'phone_number':          phone.trim(),
        'email':                 email.trim(),
        'password':              password,
        'password_confirmation': confirmPassword,
        if (countryCode != null)   'country_code':    countryCode,
        if (countryNameAr != null) 'country_name_ar': countryNameAr,
        if (countryNameEn != null) 'country_name_en': countryNameEn,
        if (countryFlag != null)   'country_flag':    countryFlag,
      });
      emit(RegisterSuccess(email: email.trim()));
    } on DioException catch (e) {
      final data   = e.response?.data as Map?;
      final errors = data?['errors'] as Map?;
      final first  = (errors?.values.first as List?)?.first as String?;
      emit(RegisterFailure(first ?? data?['message'] as String? ?? 'registerError'));
    } catch (e, stackTrace) {
      debugPrint('[RegisterCubit] UNEXPECTED ERROR: $e');
      debugPrint(stackTrace.toString());
      emit(const RegisterFailure('genericError'));
    }
  }

  void resetState() => emit(const RegisterInitial());
}

// =============================================================================
// SECTION 3 — FORM VALIDATOR
// Move to: lib/features/auth/domain/utils/form_validator.dart
// =============================================================================

abstract class FormValidator {
  /// Returns an l10n key string, or null if valid.
  static String? validateRegister({
    required String fullName,
    required String username,
    required String phone,
    required String email,
    required String password,
    required String confirmPassword,
    required bool acceptedTerms,
  }) {
    if (fullName.trim().isEmpty) {
      return 'validFullNameRequired';
    }
    if (fullName.trim().length < 3) {
      return 'validFullNameMin';
    }
    if (fullName.trim().length > 100) {
      return 'validFullNameMax';
    }
    if (username.trim().isEmpty) {
      return 'validUsernameRequired';
    }
    if (username.trim().length < 3) {
      return 'validUsernameMin';
    }
    if (username.trim().length > 30) {
      return 'validUsernameMax';
    }
    if (phone.trim().isEmpty) {
      return 'validPhoneRequired';
    }
    if (phone.trim().length < 9) {
      return 'validPhoneInvalid';
    }
    if (phone.trim().length > 20) {
      return 'validPhoneMax';
    }
    if (email.trim().isEmpty) {
      return 'validEmailRequired';
    }
    if (!RegExp(r'^[\w-.]+@([\w-]+\.)+[\w-]{2,4}$')
        .hasMatch(email.trim())) {
      return 'validEmailInvalid';
    }
    if (password.isEmpty) {
      return 'validPasswordRequired';
    }
    if (password.length < 8) {
      return 'validPasswordMin';
    }
    if (password.length > 128) {
      return 'validPasswordMax';
    }
    if (confirmPassword.isEmpty) {
      return 'validConfirmPasswordRequired';
    }
    if (password != confirmPassword) {
      return 'validPasswordMismatch';
    }
    if (!acceptedTerms) {
      return 'validTermsRequired';
    }
    return null; // all valid
  }
}

// =============================================================================
// SECTION 6 — REGISTER PAGE
// =============================================================================

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  // ── Controllers ────────────────────────────────────────────────────────────
  final TextEditingController _fullNameController    = TextEditingController();
  final TextEditingController _usernameController    = TextEditingController();
  final TextEditingController _phoneController       = TextEditingController();
  final TextEditingController _emailController       = TextEditingController();
  final TextEditingController _passwordController    = TextEditingController();
  final TextEditingController _confirmPassController = TextEditingController();

  // ── Visibility toggles ─────────────────────────────────────────────────────
  bool _isPasswordVisible        = false;
  bool _isConfirmPasswordVisible = false;

  // ── Terms checkbox ─────────────────────────────────────────────────────────
  bool _acceptedTerms = false;

  // ── Country selection ───────────────────────────────────────────────────────
  String? _selectedCountryCode;
  String? _selectedCountryNameAr;
  String? _selectedCountryNameEn;
  String? _selectedCountryFlag;

  @override
  void dispose() {
    _fullNameController.dispose();
    _usernameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPassController.dispose();
    super.dispose();
  }

  // ── Actions ────────────────────────────────────────────────────────────────

  void _onRegisterPressed(RegisterCubit cubit) {
    FocusScope.of(context).unfocus();
    cubit.register(
      fullName:        _fullNameController.text,
      username:        _usernameController.text,
      phone:           _phoneController.text,
      email:           _emailController.text,
      password:        _passwordController.text,
      confirmPassword: _confirmPassController.text,
      acceptedTerms:   _acceptedTerms,
      countryCode:     _selectedCountryCode,
      countryNameAr:   _selectedCountryNameAr,
      countryNameEn:   _selectedCountryNameEn,
      countryFlag:     _selectedCountryFlag,
    );
  }

  void _showCountryPicker(BuildContext context) {
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
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // drag handle
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
          // Flexible + SingleChildScrollView prevents overflow when the list
          // is taller than the available bottom sheet height.
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ..._kPickerCountries.map((c) => ListTile(
                    onTap: () {
                      setState(() {
                        _selectedCountryCode    = c.code;
                        _selectedCountryNameAr  = c.nameAr;
                        _selectedCountryNameEn  = c.nameEn;
                        _selectedCountryFlag    = c.flag;
                      });
                      Navigator.of(context).pop();
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
                    trailing: _selectedCountryCode == c.code
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

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => RegisterCubit(),
      child: Scaffold(
          backgroundColor: AppColors.background,
          body: BlocConsumer<RegisterCubit, RegisterState>(
            listener: (context, state) {
              if (state is RegisterSuccess) {
                // Navigate to OTP screen, passing email as extra param
                context.go('/otp', extra: state.email);
              } else if (state is RegisterFailure) {
                final l10n = AppLocalizations.of(context)!;
                final String msg;
                switch (state.message) {
                  case 'validFullNameRequired':
                    msg = l10n.validFullNameRequired;
                    break;
                  case 'validFullNameMin':
                    msg = l10n.validFullNameMin;
                    break;
                  case 'validUsernameRequired':
                    msg = l10n.validUsernameRequired;
                    break;
                  case 'validUsernameMin':
                    msg = l10n.validUsernameMin;
                    break;
                  case 'validPhoneRequired':
                    msg = l10n.validPhoneRequired;
                    break;
                  case 'validPhoneInvalid':
                    msg = l10n.validPhoneInvalid;
                    break;
                  case 'validEmailRequired':
                    msg = l10n.validEmailRequired;
                    break;
                  case 'validEmailInvalid':
                    msg = l10n.validEmailInvalid;
                    break;
                  case 'validPasswordRequired':
                    msg = l10n.validPasswordRequired;
                    break;
                  case 'validPasswordMin':
                    msg = l10n.validPasswordMin;
                    break;
                  case 'validConfirmPasswordRequired':
                    msg = l10n.validConfirmPasswordRequired;
                    break;
                  case 'validPasswordMismatch':
                    msg = l10n.validPasswordMismatch;
                    break;
                  case 'validTermsRequired':
                    msg = l10n.validTermsRequired;
                    break;
                  case 'registerError':
                    msg = l10n.registerError;
                    break;
                  default:
                    msg = state.message;
                }
                _showErrorSnack(msg);
              }
            },
            builder: (context, state) {
              final cubit     = context.read<RegisterCubit>();
              final isLoading = state is RegisterLoading;
              final l10n = AppLocalizations.of(context)!;

              return SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const SizedBox(height: 48),

                      // ── Title ────────────────────────────────────────
                      Text(
                        l10n.registerTitle,
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

                      // ── Subtitle ─────────────────────────────────────
                      Text(
                        l10n.registerEnterDetails,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontFamily: 'Tajawal',
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textSecondary,
                          height: 1.5,
                        ),
                      ),

                      const SizedBox(height: 36),

                      // ── Field 1: Full Name ────────────────────────────
                      CoreTextField(
                        controller: _fullNameController,
                        hintText: l10n.fullNameHint,
                        keyboardType: TextInputType.name,
                        enabled: !isLoading,
                      ),

                      const SizedBox(height: 14),

                      // ── Field 2: Username ─────────────────────────────
                      CoreTextField(
                        controller: _usernameController,
                        hintText: l10n.usernameHint,
                        keyboardType: TextInputType.text,
                        enabled: !isLoading,
                        // Restrict to latin + arabic alphanumeric + underscore
                        inputFormatters: [
                          FilteringTextInputFormatter.deny(RegExp(r'\s')),
                        ],
                      ),

                      const SizedBox(height: 14),

                      // ── Field 3: Phone ────────────────────────────────
                      CoreTextField(
                        controller: _phoneController,
                        hintText: l10n.phoneHint,
                        keyboardType: TextInputType.phone,
                        enabled: !isLoading,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(15),
                        ],
                      ),

                      const SizedBox(height: 14),

                      // ── Field 3b: Country ─────────────────────────────
                      GestureDetector(
                        onTap: isLoading ? null : () => _showCountryPicker(context),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 17,
                          ),
                          decoration: BoxDecoration(
                            color:        AppColors.surface,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: AppColors.fieldBorder, width: 1.2,
                            ),
                          ),
                          child: Row(
                            children: [
                              if (_selectedCountryFlag != null) ...[
                                Text(
                                  _selectedCountryFlag!,
                                  style: const TextStyle(fontSize: 20),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  _selectedCountryNameAr!,
                                  style: const TextStyle(
                                    fontFamily: 'Cairo',
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.darkText,
                                  ),
                                ),
                                const Spacer(),
                              ] else ...[
                                Expanded(
                                  child: Text(
                                    l10n.selectYourCountry,
                                    style: const TextStyle(
                                      fontFamily: 'Tajawal',
                                      fontSize: 14,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ),
                              ],
                              const Icon(
                                Icons.keyboard_arrow_down_rounded,
                                color: AppColors.textSecondary,
                                size: 20,
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 14),

                      // ── Field 4: Email ────────────────────────────────
                      CoreTextField(
                        controller: _emailController,
                        hintText: l10n.emailHint,
                        keyboardType: TextInputType.emailAddress,
                        enabled: !isLoading,
                      ),

                      const SizedBox(height: 14),

                      // ── Field 5: Password ─────────────────────────────
                      CoreTextField(
                        controller: _passwordController,
                        hintText: l10n.passwordHint,
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
                          child: _EyeIcon(visible: _isPasswordVisible),
                        ),
                      ),

                      const SizedBox(height: 14),

                      // ── Field 6: Confirm Password ─────────────────────
                      CoreTextField(
                        controller: _confirmPassController,
                        hintText: l10n.confirmPasswordHint,
                        obscureText: !_isConfirmPasswordVisible,
                        enabled: !isLoading,
                        inputFormatters: [LengthLimitingTextInputFormatter(128)],
                        suffixIcon: GestureDetector(
                          onTap: isLoading
                              ? null
                              : () => setState(
                                    () => _isConfirmPasswordVisible =
                                        !_isConfirmPasswordVisible,
                                  ),
                          child: _EyeIcon(
                              visible: _isConfirmPasswordVisible),
                        ),
                      ),

                      const SizedBox(height: 22),

                      // ── Terms & Conditions Checkbox ───────────────────
                      _TermsCheckbox(
                        value: _acceptedTerms,
                        enabled: !isLoading,
                        onChanged: (val) =>
                            setState(() => _acceptedTerms = val ?? false),
                        onTermsTap: () => context.push('/legal/terms'),
                        onPrivacyTap: () => context.push('/legal/privacy'),
                      ),

                      const SizedBox(height: 28),

                      // ── Create Account Button ─────────────────────────
                      CorePrimaryButton(
                        label: l10n.register,
                        isLoading: isLoading,
                        onPressed: () => _onRegisterPressed(cubit),
                      ),

                      const SizedBox(height: 28),

                      // ── Already have account? ─────────────────────────
                    Center(
  child: RichText(
    text: TextSpan(
      style: const TextStyle(
        fontSize: 14.0, 
        height: 1.0, // توحيد خط القاعدة لضمان محاذاة النصين تماماً
      ),
      children: [
        TextSpan(
          text: '${l10n.alreadyHaveAccountFull} ',
          style: const TextStyle(
            fontFamily: 'Tajawal',
            fontWeight: FontWeight.w400,
            color: AppColors.textSecondary,
          ),
        ),
        TextSpan(
          text: l10n.login,
          style: const TextStyle(
            fontFamily: 'Cairo',
            fontWeight: FontWeight.w700,
            color: AppColors.primary,
            decoration: TextDecoration.none, // التأكد من عدم وجود خط سفلي
          ),
          recognizer: TapGestureRecognizer()
            ..onTap = isLoading
                ? null
                : () {
                    if (context.canPop()) {
                      context.pop();
                    } else {
                      context.go('/login');
                    }
                  },
        ),
      ],
    ),
  ),
),

const SizedBox(height: 36),
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
// SECTION 7 — EYE ICON  (private sub-widget)
// =============================================================================

class _EyeIcon extends StatelessWidget {
  final bool visible;

  const _EyeIcon({required this.visible});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Icon(
        visible
            ? Icons.visibility_outlined
            : Icons.visibility_off_outlined,
        color: AppColors.textSecondary,
        size: 22,
      ),
    );
  }
}

// =============================================================================
// SECTION 8 — TERMS & CONDITIONS CHECKBOX  (private sub-widget)
// =============================================================================

class _TermsCheckbox extends StatelessWidget {
  final bool value;
  final bool enabled;
  final ValueChanged<bool?> onChanged;
  final VoidCallback onTermsTap;
  final VoidCallback onPrivacyTap;

  const _TermsCheckbox({
    required this.value,
    required this.enabled,
    required this.onChanged,
    required this.onTermsTap,
    required this.onPrivacyTap,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
 return Row(
      // RTL: checkbox on the left = leading
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // ── Text ────────────────────────────────────────────────────────
        Expanded(
          child: GestureDetector(
            onTap: enabled ? () => onChanged(!value) : null,
            child: RichText(
              textAlign: TextAlign.start,
              text: TextSpan(
                style: const TextStyle(
                  fontFamily: 'Tajawal',
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  color: AppColors.textSecondary,
                  height: 1.0, // توحيد المستوى لجميع النصوص
                ),
                children: [
                  TextSpan(text: l10n.iAgreeToThe),
                  TextSpan(
                    text: l10n.termsAndConditions,
                    style: const TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                      decoration: TextDecoration.none, // إزالة الخط السفلي
                    ),
                    recognizer: TapGestureRecognizer()
                      ..onTap = enabled ? onTermsTap : null,
                  ),
                  TextSpan(
                    text: l10n.andPrivacyPolicy,
                    style: const TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                      decoration: TextDecoration.none,
                    ),
                    recognizer: TapGestureRecognizer()
                      ..onTap = enabled ? onPrivacyTap : null,
                  ),
                ],
              ),
            ),
          ),
        ),

        const SizedBox(width: 10),

        // ── Checkbox ─────────────────────────────────────────────────────
        GestureDetector(
          onTap: enabled ? () => onChanged(!value) : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: value ? AppColors.primary : Colors.transparent,
              border: Border.all(
                color: value
                    ? AppColors.primary
                    : AppColors.fieldBorder,
                width: 1.6,
              ),
              borderRadius: BorderRadius.circular(6),
            ),
            child: value
                ? const Icon(
                    Icons.check,
                    size: 14,
                    color: Colors.white,
                  )
                : null,
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// SECTION 9 — COUNTRY PICKER DATA
// =============================================================================

class _CountryEntry {
  final String nameAr;
  final String nameEn;
  final String code;
  final String flag;
  const _CountryEntry(this.nameAr, this.nameEn, this.code, this.flag);
}

const _kPickerCountries = <_CountryEntry>[
  _CountryEntry('بريطانيا',  'United Kingdom', 'GB', '🇬🇧'),
  _CountryEntry('أستراليا',  'Australia',      'AU', '🇦🇺'),
  _CountryEntry('أمريكا',    'United States',  'US', '🇺🇸'),
  _CountryEntry('كندا',      'Canada',         'CA', '🇨🇦'),
];

// =============================================================================
// MUBTAATH — FORGOT PASSWORD PAGE
// =============================================================================
// File  : lib/features/auth/presentation/pages/forgot_password_page.dart
//
// COMPONENT STRATEGY — shared widgets (no duplication):
//
//   ┌─────────────────────────────────────────────────────────┐
//   │  auth_shared_widgets.dart  (place in auth/widgets/)     │
//   │  ─────────────────────────────────────────────────────  │
//   │  • MubtaathLogo        — logo + app name               │
//   │  • AuthFormCard        — white card, shadow, radius 24 │
//   │  • AuthTextField       — unified RTL input field       │
//   │  • AuthPrimaryButton   — green full-width button       │
//   │  • AuthHeaderText      — title + subtitle pair         │
//   └─────────────────────────────────────────────────────────┘
//
//   All shared widgets live in Section 2 of this file for
//   single-artifact delivery. Extract them when integrating.
//
// ANIMATION PIPELINE:
//   Controller duration: 700ms
//   Stage 1 (0.00→0.55): Logo   → FadeTransition + SlideTransition (top)
//   Stage 2 (0.35→1.00): Card   → FadeTransition + SlideTransition (bottom)
//   Curve: easeOutCubic
//
// FORGOT PASSWORD STATES:
//   idle    → email input form
//   loading → button spinner
//   success → confirmation card (email sent illustration)
//   error   → snackbar error message
//
// DESIGN SYSTEM (matches Login exactly):
//   Background:  #F8F9FA
//   Card:        white | radius 24 | shadow black 3% blur 10 offset (0,4)
//   Card border: black 5%
//   H-padding:   24px
//   Heading:     Cairo Bold   #305544
//   Body:        Tajawal Med  #707070
//   Button:      #305544 | height 56 | radius 14
// =============================================================================

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mubtaath/core/l10n/app_localizations.dart';
import 'package:mubtaath/core/services/dio_client.dart';
import 'package:mubtaath/core/theme/app_colors.dart';
import 'package:mubtaath/core/widgets/shared_widgets.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SECTION 0 — DESIGN TOKENS
// ─────────────────────────────────────────────────────────────────────────────
abstract class _D {
  static const Color primary      = Color(0xFF305544);
  static const Color secondary    = Color(0xFFB19369);
  static const Color cardBg       = Colors.white;
  static const Color heading      = Color(0xFF305544);
  static const Color body         = Color(0xFF707070);
  static const Color bodyLight    = Color(0xFFAAAAAA);
  static const double hPad        = 24.0;
  static const double cardRadius  = 24.0;
}

// ─────────────────────────────────────────────────────────────────────────────
// SECTION 1 — CUBIT
// ─────────────────────────────────────────────────────────────────────────────
enum ForgotStatus { idle, loading, success, error }

class ForgotState {
  final ForgotStatus status;
  final String       email;
  final String?      errorMsg;

  const ForgotState({
    this.status   = ForgotStatus.idle,
    this.email    = '',
    this.errorMsg,
  });

  bool get isLoading => status == ForgotStatus.loading;
  bool get isSuccess => status == ForgotStatus.success;
  bool get canSubmit => email.trim().isNotEmpty && !isLoading;

  ForgotState copyWith({
    ForgotStatus? status,
    String?       email,
    String?       errorMsg,
  }) =>
      ForgotState(
        status:   status   ?? this.status,
        email:    email    ?? this.email,
        errorMsg: errorMsg ?? this.errorMsg,
      );
}

class ForgotCubit extends Cubit<ForgotState> {
  ForgotCubit() : super(const ForgotState());

  void updateEmail(String v) =>
      emit(state.copyWith(email: v, status: ForgotStatus.idle));

  Future<void> sendReset() async {
    if (!state.canSubmit) return;

    // Basic email validation
    final emailRx = RegExp(r'^[\w-.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRx.hasMatch(state.email.trim())) {
      emit(state.copyWith(
        status:   ForgotStatus.error,
        errorMsg: 'invalidEmailError',
      ));
      return;
    }

    emit(state.copyWith(status: ForgotStatus.loading));

    try {
      // Backend always answers generically (no user enumeration): a 200
      // means "if the email exists, a reset code was sent". We then move
      // the user to the reset screen to enter that code.
      await appDio.post(
        '/auth/forgot-password',
        data: {'email': state.email.trim()},
      );
      emit(state.copyWith(status: ForgotStatus.success));
    } on DioException catch (e) {
      // 422 = invalid email format; anything else is a generic failure.
      final msg =
          e.response?.statusCode == 422 ? 'invalidEmailError' : 'genericError';
      emit(state.copyWith(status: ForgotStatus.error, errorMsg: msg));
    } catch (_) {
      emit(state.copyWith(
        status:   ForgotStatus.error,
        errorMsg: 'genericError',
      ));
    }
  }

  void retry() => emit(state.copyWith(
        status: ForgotStatus.idle, errorMsg: null,
      ));
}

// ─────────────────────────────────────────────────────────────────────────────
// SECTION 2 — SHARED AUTH WIDGETS
// Extract to: lib/features/auth/presentation/widgets/auth_shared_widgets.dart
// ─────────────────────────────────────────────────────────────────────────────

// ── 2A. MubtaathLogo ─────────────────────────────────────────────────────────
/// App logo + name — used on Login, ForgotPassword, Splash
class MubtaathLogo extends StatelessWidget {
  final double logoSize;
  final bool   showLabel;

  const MubtaathLogo({
    super.key,
    this.logoSize  = 72,
    this.showLabel = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── Logo image ───────────────────────────────────────────────
        SizedBox(
          width:  logoSize,
          height: logoSize,
          child: Image.asset(
            'assets/images/logo.png',
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => _FallbackLogo(size: logoSize),
          ),
        ),

        if (showLabel) ...[
          const SizedBox(height: 12),
          // App name
          Text(
            AppLocalizations.of(context)!.appTitle,
            style: const TextStyle(
              fontFamily:   'Cairo',
              fontSize:     28,
              fontWeight:   FontWeight.w800,
              color:        _D.heading,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          // Gold divider
          Container(
            width: 40, height: 3,
            decoration: BoxDecoration(
              color:        _D.secondary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
      ],
    );
  }
}

// Pure-Flutter fallback for logo (renders without asset)
class _FallbackLogo extends StatelessWidget {
  final double size;
  const _FallbackLogo({required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(
        color:        _D.primary,
        borderRadius: BorderRadius.circular(size * 0.26),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Inner ring
          Container(
            width: size * 0.76, height: size * 0.76,
            decoration: BoxDecoration(
              shape:  BoxShape.circle,
              border: Border.all(
                color: _D.secondary.withOpacity(0.55), width: 1.5,
              ),
            ),
          ),
          // Chat + people icon
          Icon(LucideIcons.users, color: Colors.white, size: size * 0.38),
          // Airplane top-right
          Positioned(
            top: size * 0.08, right: size * 0.10,
            child: Transform.rotate(
              angle: -0.5,
              child: Icon(
                LucideIcons.plane,
                color: _D.secondary, size: size * 0.20,
              ),
            ),
          ),
        ],
      ),
    );
  }
}


// ── 2C. AuthFormCard ─────────────────────────────────────────────────────────
/// White rounded card — wraps form content on all auth screens
class AuthFormCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;

  const AuthFormCard({
    super.key,
    required this.child,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding ??
          const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      decoration: BoxDecoration(
        color:        _D.cardBg,
        borderRadius: BorderRadius.circular(_D.cardRadius),
        border: Border.all(
          color: Colors.black.withOpacity(0.05),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color:      Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset:     const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}


// ─────────────────────────────────────────────────────────────────────────────
// SECTION 4 — FORGOT PASSWORD PAGE
// ─────────────────────────────────────────────────────────────────────────────
class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage>
    with SingleTickerProviderStateMixin {
  // ── Controllers ────────────────────────────────────────────────────────────
  final TextEditingController _emailCtrl = TextEditingController();
  late final AnimationController _animCtrl;

  // ── Logo animation: fades + slides from top ────────────────────────────────
  late final Animation<double> _logoOpacity;
  late final Animation<Offset> _logoSlide;

  // ── Card animation: fades + slides from bottom ─────────────────────────────
  late final Animation<double> _cardOpacity;
  late final Animation<Offset> _cardSlide;

  @override
  void initState() {
    super.initState();

    _animCtrl = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 700),
    );

    // Stage 1: Logo 0.00 → 0.55
    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animCtrl,
        curve:  const Interval(0.00, 0.55, curve: Curves.easeOutCubic),
      ),
    );
    _logoSlide = Tween<Offset>(
      begin: const Offset(0, -0.30),
      end:   Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animCtrl,
      curve:  const Interval(0.00, 0.55, curve: Curves.easeOutCubic),
    ));

    // Stage 2: Card 0.35 → 1.00
    _cardOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animCtrl,
        curve:  const Interval(0.35, 1.00, curve: Curves.easeOutCubic),
      ),
    );
    _cardSlide = Tween<Offset>(
      begin: const Offset(0, 0.30),
      end:   Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animCtrl,
      curve:  const Interval(0.35, 1.00, curve: Curves.easeOutCubic),
    ));

    // Kick off the animation on first frame
    WidgetsBinding.instance.addPostFrameCallback((_) => _animCtrl.forward());
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  void _showError(BuildContext context, String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
          SnackBar(
            content: Text(
              msg,
              textAlign: TextAlign.start,
              style: const TextStyle(
                fontFamily: 'Tajawal', fontSize: 14, color: Colors.white,
              ),
            ),
            backgroundColor: _D.primary,
            behavior:        SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            margin:   const EdgeInsets.all(16),
            duration: const Duration(seconds: 3),
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => ForgotCubit(),
      child: Scaffold(
          backgroundColor: AppColors.background,
          // ── automaticallyImplyLeading: true → back to Login ──────────
          // (default behavior — RTL-safe back arrow shown by Flutter)
appBar: AppBar(
            toolbarHeight: 64, // مساحة مريحة ليتنفس الزر عمودياً
            backgroundColor: Colors.transparent,
            elevation: 0,
            scrolledUnderElevation: 0,
            automaticallyImplyLeading: false,
            leadingWidth: 80, // مساحة عرض كافية لدف الزر بدون انضغاط
            leading: const Align(
              alignment: AlignmentDirectional.centerStart,
              child: Padding(
                padding: EdgeInsetsDirectional.only(start: 24), // مسافة جانبية أنيقة وموحدة
                child: CoreBackButton(), // 👈 استدعاء الوجت الموحد مباشرة بجودة عالية
              ),
            ),
          ),    
          
          
             body: BlocConsumer<ForgotCubit, ForgotState>(
            listener: (context, state) {
              if (state.status == ForgotStatus.success) {
                // A code was sent (if the email exists) — move to the reset
                // screen. Reset the cubit to idle so returning shows the form.
                final email = state.email.trim();
                context.read<ForgotCubit>().retry();
                context.push('/reset-password', extra: email);
              } else if (state.status == ForgotStatus.error &&
                  state.errorMsg != null) {
                final l10n = AppLocalizations.of(context)!;
                final msg = state.errorMsg == 'invalidEmailError'
                    ? l10n.invalidEmailError
                    : l10n.genericError;
                _showError(context, msg);
              }
            },
            builder: (context, state) {
              final cubit = context.read<ForgotCubit>();

              return SafeArea(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: _D.hPad),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const SizedBox(height: 20),

                      // ── LOGO (animated slide from top) ─────────────
 // ── LOGO (animated slide from top) ─────────────
FadeTransition(
  opacity: _logoOpacity,
  child: SlideTransition(
    position: _logoSlide,
    child: const MubtaathLogo(
      logoSize: 68, 
      showLabel: false,
    ),
  ),
),
                      const SizedBox(height: 32),

                      // ── CARD (animated slide from bottom) ──────────
                      FadeTransition(
                        opacity: _cardOpacity,
                        child: SlideTransition(
                          position: _cardSlide,
                          child: _ForgotForm(
                            cubit:     cubit,
                            state:     state,
                            emailCtrl: _emailCtrl,
                          ),
                        ),
                      ),

                      const SizedBox(height: 32),

                      // ── Bottom: "تذكرتها؟ تسجيل الدخول" ─────────
                      if (!state.isSuccess)
                        FadeTransition(
                          opacity: _cardOpacity,
                          child: _RememberPasswordRow(
                            onLogin: () {
                              if (context.canPop()) context.pop();
                            },
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

// ─────────────────────────────────────────────────────────────────────────────
// SECTION 5 — FORGOT FORM WIDGET
// ─────────────────────────────────────────────────────────────────────────────
class _ForgotForm extends StatelessWidget {
  final ForgotCubit           cubit;
  final ForgotState           state;
  final TextEditingController emailCtrl;

  const _ForgotForm({
    required this.cubit,
    required this.state,
    required this.emailCtrl,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AuthFormCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [

          // ── Lock illustration ─────────────────────────────────────
          Container(
            width:  60, height: 60,
            decoration: BoxDecoration(
              color:        _D.primary.withOpacity(0.08),
              shape:        BoxShape.circle,
              border: Border.all(
                color: _D.primary.withOpacity(0.18), width: 1.5,
              ),
            ),
            child: const Icon(
              LucideIcons.lock,
              color: _D.primary, size: 28,
            ),
          ),

          const SizedBox(height: 20),

          // ── Header title + subtitle ───────────────────────────────
          AuthHeader(
            title:    l10n.forgotPasswordTitle,
            subtitle: l10n.forgotPasswordSubtitle,
          ),

          const SizedBox(height: 24),

          // ── Email field ───────────────────────────────────────────
          CoreTextField(
            controller:  emailCtrl,
            hintText:    l10n.emailHint,
            keyboardType: TextInputType.emailAddress,
            enabled:     !state.isLoading,
            onChanged:   cubit.updateEmail,
          ),

          const SizedBox(height: 20),

          // ── Send button ───────────────────────────────────────────
          CorePrimaryButton(
            label:     l10n.sendCode,
            isLoading: state.isLoading,
            onPressed: state.canSubmit ? cubit.sendReset : null,
          ),

          const SizedBox(height: 16),

          // ── Security note ─────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                l10n.resetLinkExpiry,
                style: const TextStyle(
                  fontFamily: 'Tajawal',
                  fontSize:   12,
                  color:      _D.bodyLight,
                ),
              ),
              const SizedBox(width: 5),
              const Icon(
                LucideIcons.shieldCheck,
                size: 13, color: _D.bodyLight,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SECTION 6 — "Remember password?" ROW
// ─────────────────────────────────────────────────────────────────────────────
class _RememberPasswordRow extends StatelessWidget {
  final VoidCallback onLogin;
  const _RememberPasswordRow({required this.onLogin});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.baseline, 
      textBaseline: TextBaseline.alphabetic, 
      children: [
        // 1. السؤال أولاً: "تذكرتها؟" (راح يجي يمين بالعربي، ويسار بالإنجليزي)
        Text(
          l10n.rememberPassword,
          style: const TextStyle(
            fontFamily: 'Tajawal',
            fontSize:   14,
            fontWeight: FontWeight.w500,
            color:      _D.body,
            height: 1.0,
          ),
        ),
        const SizedBox(width: 4),
        // 2. الإجراء ثانياً: "تسجيل الدخول" (راح يجي يسار بالعربي، ويمين بالإنجليزي)
        GestureDetector(
          onTap: onLogin,
          child: Text(
            l10n.login,
            style: const TextStyle(
              fontFamily: 'Cairo',
              fontSize:   14,
              fontWeight: FontWeight.w700,
              color:      _D.primary,
              height: 1.0, 
            ),
          ),
        ),
      ],
    );
  }
}
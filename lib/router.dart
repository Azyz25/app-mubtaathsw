import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:mubtaath/core/auth_notifier.dart';
import 'package:mubtaath/core/l10n/app_localizations.dart';
import 'package:mubtaath/splash_page.dart';
import 'package:mubtaath/login_page.dart';
import 'package:mubtaath/home_page.dart';
import 'package:mubtaath/register_page.dart';
import 'package:mubtaath/otp_verification_page.dart';
import 'package:mubtaath/room_details_page.dart';
import 'package:mubtaath/profile_page.dart';
import 'package:mubtaath/settings_page.dart';
import 'package:mubtaath/prayer_times_page.dart';
import 'package:mubtaath/student_guide_page.dart';
import 'package:mubtaath/forgot_password_page.dart';
import 'package:mubtaath/reset_password_page.dart';
import 'package:mubtaath/notifications_page.dart';
import 'package:mubtaath/qibla_screen.dart';
import 'package:mubtaath/features/audio_room/presentation/cubit/audio_room_cubit.dart';
import 'package:mubtaath/features/audio_room/presentation/pages/audio_room_page.dart';
import 'package:mubtaath/features/reports/presentation/pages/support_page.dart';
import 'package:mubtaath/features/legal/presentation/pages/legal_page_screen.dart';
import 'package:mubtaath/account_suspended_page.dart';

// Mubtaath premium transition:
//   Entrance  → fade-in + subtle slide from bottom (offset 0.05), 450ms easeOutCubic
//   Exit/back → soft fade only (no slide)
//   Secondary → slight fade when pushed to background (preserves Hero flights)
CustomTransitionPage<void> _mubtaathPage(LocalKey key, Widget child) {
  return CustomTransitionPage<void>(
    key: key,
    child: _EdgeSwipeBack(child: child),
    transitionDuration: const Duration(milliseconds: 450),
    reverseTransitionDuration: const Duration(milliseconds: 450),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final isReversing = animation.status == AnimationStatus.reverse;

      final curvedAnim = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
      );

      // Entrance: fade + slide. Exit: fade only.
      Widget page = FadeTransition(opacity: curvedAnim, child: child);

      if (!isReversing) {
        page = SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0.0, 0.05),
            end: Offset.zero,
          ).animate(curvedAnim),
          child: page,
        );
      }

      // Soft fade when this page goes to background (preserves RTL + Hero).
      return FadeTransition(
        opacity: Tween<double>(begin: 1.0, end: 0.92).animate(
          CurvedAnimation(
            parent: secondaryAnimation,
            curve: Curves.easeOutCubic,
          ),
        ),
        child: page,
      );
    },
  );
}

// =============================================================================
// EDGE-SWIPE-BACK — CustomTransitionPage doesn't get Cupertino's built-in
// interactive back gesture (that only ships with CupertinoPageRoute/Page, and
// switching to it would replace the fade+slide transition above). This adds
// the same "swipe from the leading screen edge to go back" behaviour on top
// of the custom transition, direction-aware so it starts from the right edge
// in RTL (Arabic) and the left edge in LTR (English) — matching each
// platform's own convention rather than a fixed side.
// =============================================================================
class _EdgeSwipeBack extends StatefulWidget {
  final Widget child;
  const _EdgeSwipeBack({required this.child});

  @override
  State<_EdgeSwipeBack> createState() => _EdgeSwipeBackState();
}

class _EdgeSwipeBackState extends State<_EdgeSwipeBack> {
  static const _edgeWidth = 24.0;
  static const _popDistanceThreshold = 60.0;

  bool   _trackingFromEdge = false;
  double _startX = 0;
  double _cumulativeDx = 0;

  // Raw pointer tracking (Listener), not a GestureDetector — this never
  // enters the gesture arena, so it can't compete with a page's own
  // horizontal scrollables (PageView, horizontal lists) for the drag.
  void _onPointerDown(PointerDownEvent event, double screenWidth, bool isRtl) {
    final x = event.position.dx;
    final withinStartEdge =
        isRtl ? x >= screenWidth - _edgeWidth : x <= _edgeWidth;
    _trackingFromEdge = withinStartEdge && Navigator.of(context).canPop();
    _startX = x;
    _cumulativeDx = 0;
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (!_trackingFromEdge) return;
    _cumulativeDx = event.position.dx - _startX;
  }

  void _onPointerUp(PointerUpEvent event, bool isRtl) {
    if (!_trackingFromEdge) return;
    _trackingFromEdge = false;

    // "Back" motion is toward the trailing edge: negative dx in RTL
    // (dragging right-to-left), positive dx in LTR (dragging left-to-right).
    final backDistance = isRtl ? -_cumulativeDx : _cumulativeDx;
    if (backDistance > _popDistanceThreshold) {
      Navigator.of(context).maybePop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    final screenWidth = MediaQuery.of(context).size.width;

    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (e) => _onPointerDown(e, screenWidth, isRtl),
      onPointerMove: _onPointerMove,
      onPointerUp: (e) => _onPointerUp(e, isRtl),
      onPointerCancel: (_) => _trackingFromEdge = false,
      child: widget.child,
    );
  }
}

const _protectedRoutes = {
  '/home', '/notifications', '/profile',
  '/settings', '/prayer-times', '/qibla', '/student-guide', '/support',
};

// Listenable that fires on either auth or suspended state changes.
class _CombinedNotifier extends ChangeNotifier {
  _CombinedNotifier() {
    authNotifier.addListener(notifyListeners);
    suspendedNotifier.addListener(notifyListeners);
  }

  @override
  void dispose() {
    authNotifier.removeListener(notifyListeners);
    suspendedNotifier.removeListener(notifyListeners);
    super.dispose();
  }
}

final _routerListenable = _CombinedNotifier();

final GoRouter appRouter = GoRouter(
  initialLocation: '/',
  refreshListenable: _routerListenable,
  redirect: (context, state) {
    final loc         = state.matchedLocation;
    final isLoggedIn  = authNotifier.value;
    final isSuspended = suspendedNotifier.value;

    // Suspended users are confined to the suspended screen and the support
    // page (so they can appeal) — every other route bounces back. This makes
    // home unreachable even if a stray back-navigation targets it.
    if (isSuspended && loc != '/suspended' && loc != '/support') {
      return '/suspended';
    }

    final isProtected =
        _protectedRoutes.contains(loc) || loc.startsWith('/room/');
    if (isProtected && !isLoggedIn) return '/login';
    return null;
  },
  routes: [
    GoRoute(
      path: '/',
      name: 'splash',
      pageBuilder: (context, state) =>
          _mubtaathPage(state.pageKey, const SplashPage()),
    ),

    GoRoute(
      path: '/login',
      name: 'login',
      pageBuilder: (context, state) =>
          _mubtaathPage(state.pageKey, const LoginPage()),
    ),

    GoRoute(
      path: '/register',
      name: 'register',
      pageBuilder: (context, state) =>
          _mubtaathPage(state.pageKey, const RegisterPage()),
    ),

    GoRoute(
      path: '/forgot-password',
      name: 'forgot_password',
      pageBuilder: (context, state) =>
          _mubtaathPage(state.pageKey, const ForgotPasswordPage()),
    ),

    GoRoute(
      path: '/reset-password',
      name: 'reset_password',
      pageBuilder: (context, state) => _mubtaathPage(
        state.pageKey,
        ResetPasswordPage(email: state.extra as String? ?? ''),
      ),
    ),

    GoRoute(
      path: '/otp',
      name: 'otp',
      pageBuilder: (context, state) =>
          _mubtaathPage(state.pageKey, OtpVerificationPage(email: state.extra as String? ?? '')),
    ),

    GoRoute(
      path: '/home',
      name: 'home',
      pageBuilder: (context, state) =>
          _mubtaathPage(state.pageKey, const HomePage()),
    ),

    GoRoute(
      path: '/notifications',
      name: 'notifications',
      pageBuilder: (context, state) =>
          _mubtaathPage(state.pageKey, const NotificationsPage()),
    ),

    GoRoute(
      path: '/room/:id',
      pageBuilder: (context, state) => _mubtaathPage(
        state.pageKey,
        RoomDetailsPage(roomId: state.pathParameters['id'] ?? ''),
      ),
    ),

    // Audio room powered by Agora RTC.
    // Navigate with just the room UUID — the cubit fetches the token itself:
    //   context.push('/audio-room/$channelId');
    GoRoute(
      path: '/audio-room/:channel',
      pageBuilder: (context, state) => _mubtaathPage(
        state.pageKey,
        BlocProvider(
          create: (_) => AudioRoomCubit(),
          child: AudioRoomPage(
            channelId: state.pathParameters['channel'] ?? '',
          ),
        ),
      ),
    ),

    GoRoute(
      path: '/student-guide',
      name: 'student_guide',
      pageBuilder: (context, state) =>
          _mubtaathPage(state.pageKey, const StudentGuidePage()),
    ),

    GoRoute(
      path: '/profile',
      name: 'profile',
      pageBuilder: (context, state) =>
          _mubtaathPage(state.pageKey, const ProfilePage()),
    ),

    GoRoute(
      path: '/prayer-times',
      name: 'prayer_times',
      pageBuilder: (context, state) =>
          _mubtaathPage(state.pageKey, const PrayerTimesPage()),
    ),

    GoRoute(
      path: '/qibla',
      name: 'qibla',
      pageBuilder: (context, state) =>
          _mubtaathPage(state.pageKey, const QiblaScreen()),
    ),

    GoRoute(
      path: '/support',
      name: 'support',
      pageBuilder: (context, state) =>
          _mubtaathPage(state.pageKey, const SupportPage()),
    ),

    // Terms of Service / Privacy Policy — dashboard-editable content.
    // Deliberately NOT in _protectedRoutes: reachable pre-auth from the
    // registration checkbox as well as post-auth from Settings.
    GoRoute(
      path: '/legal/:slug',
      name: 'legal',
      pageBuilder: (context, state) {
        final slug = state.pathParameters['slug'] ?? 'terms';
        final l10n = AppLocalizations.of(context)!;
        final fallbackTitle = switch (slug) {
          'privacy' => l10n.privacyPolicy,
          'about' => l10n.aboutApp,
          _ => l10n.termsAndConditions,
        };
        return _mubtaathPage(
          state.pageKey,
          LegalPageScreen(slug: slug, fallbackTitle: fallbackTitle),
        );
      },
    ),

    // Settings — not in the target list, keep default transition.
    GoRoute(
      path: '/settings',
      name: 'settings',
      builder: (context, state) => const SettingsPage(),
    ),

    GoRoute(
      path: '/suspended',
      name: 'suspended',
      pageBuilder: (context, state) =>
          _mubtaathPage(state.pageKey, const AccountSuspendedPage()),
    ),
  ],
  errorBuilder: (context, state) => Scaffold(
    body: Center(child: Text(AppLocalizations.of(context)!.pageNotFound)),
  ),
);

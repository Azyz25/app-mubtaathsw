// =============================================================================
// MUBTAATH APP — SPLASH PAGE  (v3 — corrected white theme)
// =============================================================================
// File Path  : lib/features/auth/presentation/pages/splash_page.dart
// Design Ref : User_Flow.jpg — leftmost screen
//
// VISUAL SPEC (extracted from User_Flow.jpg):
//   • Background  : #F9F7F5 (off-white / same as ALL app screens)
//   • Logo        : centered, green version (assets/images/logo.png)
//   • Bottom art  : city skyline illustration + green wave
//                   anchored at bottom, bleeds edge-to-edge
//   • No text or tagline visible on splash
//
// ANIMATION PIPELINE:
//   Stage 1  t=0→1200ms  Logo   : opacity 0→1  +  scale 0.90→1.00
//                                  curve: easeOutQuart
//   Stage 2  t=300→1400ms Bottom : opacity 0→1
//                                  curve: easeOut
//   Hold     1400→2500ms  (static — user reads the screen)
//   Navigate t=2500ms     FadeTransition via PageRouteBuilder
//
// TRANSITION:
//   PageRouteBuilder — pure FadeTransition only (no slide, no zoom-out)
//   Duration: 450ms | Curve: easeInOut
//
// Assets:
//   assets/images/logo.png       — brand logo (green version)
//   assets/images/splash_bg.png  — city skyline bottom illustration
//
// NOTE: Both assets have pure Flutter fallbacks so the page renders
//       even before assets are wired up in pubspec.yaml.
// =============================================================================

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:mubtaath/core/auth_notifier.dart';
import 'package:mubtaath/core/services/secure_storage_service.dart';

// ============================F=================================================
// SECTION 0 — BRAND COLORS
// =============================================================================

abstract class _C {
  // Background — same off-white used across every app screen
  static const Color background = Color(0xFFF9F7F5);
  static const Color primary = Color(0xFF305544);
  static const Color primaryDark = Color(0xFF1E3A2D);
  static const Color secondary = Color(0xFFB19369);
  static const Color waveLight = Color(0xFFEFE8E0); // aux-2 from brand
}

// =============================================================================
// SECTION 2 — AUTH STATE (stub — replace with your real AuthCubit)
// =============================================================================

// When integrating, import your real AuthCubit instead of this stub.
// The splash checks auth state BEFORE navigating.
abstract class _AuthResult {
  const _AuthResult();
}

class _AuthLoggedIn extends _AuthResult {
  const _AuthLoggedIn();
}

class _AuthGuest extends _AuthResult {
  const _AuthGuest();
}

Future<_AuthResult> _checkAuth() async {
  final token = await SecureStorageService.readAuthToken();
  if (token != null) {
    authNotifier.value = true;
    return const _AuthLoggedIn();
  }
  return const _AuthGuest();
}

// =============================================================================
// SECTION 3 — SPLASH PAGE
// =============================================================================

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  // ── Logo: scale + opacity ────────────────────────────────────────────────────
  late final Animation<double> _logoScale;
  late final Animation<double> _logoOpacity;

  // ── Bottom illustration: opacity only ────────────────────────────────────────
  late final Animation<double> _bottomOpacity;

  // Auth result stored for navigation
  _AuthResult? _authResult;
  bool _navigated = false;

  // ── Total animation timeline: 1400ms
  static const _animDuration = Duration(milliseconds: 1400);
  static const _splashDuration = Duration(milliseconds: 2500);
  static const _navDuration = Duration(milliseconds: 450);

  @override
  void initState() {
    super.initState();
    _setSystemUI();
    _buildAnimations();
    _runSequence();
  }

  void _setSystemUI() {
    // Light status bar icons on off-white background
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: _C.background,
      systemNavigationBarIconBrightness: Brightness.dark,
    ));
  }

  void _buildAnimations() {
    _ctrl = AnimationController(vsync: this, duration: _animDuration);

    // Stage 1 — Logo: 0ms → 800ms (0.00 → 0.57 of total)
    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.00, 0.52, curve: Curves.easeOut),
      ),
    );

    _logoScale = Tween<double>(begin: 0.90, end: 1.00).animate(
      CurvedAnimation(
        parent: _ctrl,
        // Slightly longer than opacity for satisfying deceleration feel
        curve: const Interval(0.00, 0.65, curve: Curves.easeOutQuart),
      ),
    );

    // Stage 2 — Bottom art: 300ms → 1300ms (0.21 → 0.93 of total)
    _bottomOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.21, 0.93, curve: Curves.easeOut),
      ),
    );
  }

  void _runSequence() {
    // Fire auth check in parallel — don't block animation
    _checkAuth().then((result) {
      _authResult = result;
    });

    // Start animation immediately
    _ctrl.forward();

    // Navigate after total splash duration
    Future.delayed(_splashDuration, _navigate);
  }

  void _navigate() {
    if (_navigated || !mounted) return;
    _navigated = true;
    // Country selection is handled during registration — unauthenticated
    // launches go straight to the login/welcome screen.
    context.go(
      (_authResult is _AuthLoggedIn) ? '/home' : '/login',
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    // Restore system UI when leaving splash
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarIconBrightness: Brightness.dark,
    ));
    super.dispose();
  }

  // ── Build ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      // Off-white — exact same background as every other app screen
      backgroundColor: _C.background,
      body: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, _) {
          return Stack(
            fit: StackFit.expand,
            children: [
              // ── Bottom Illustration ─────────────────────────────────────
              // Anchored at the very bottom, bleeds edge to edge
              // Matches User_Flow.jpg: city skyline + green wave base
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: _BottomIllustration(
                  opacity: _bottomOpacity.value,
                  screenWidth: size.width,
                ),
              ),

              // ── Centered Logo ───────────────────────────────────────────
              // Positioned in the center of the screen
              // Offset slightly upward (center of upper 60%) to leave
              // visual breathing room above the bottom art
              Positioned.fill(
                bottom: size.height * 0.30, // push logo up from dead center
                child: Align(
                  alignment: Alignment.center,
                  child: _LogoWidget(
                    opacity: _logoOpacity.value,
                    scale: _logoScale.value,
                    size: size.width * 0.40,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// =============================================================================
// SECTION 4 — LOGO WIDGET
// =============================================================================

class _LogoWidget extends StatelessWidget {
  final double opacity;
  final double scale;
  final double size;

  const _LogoWidget({
    required this.opacity,
    required this.scale,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: opacity.clamp(0.0, 1.0),
      child: Transform.scale(
        scale: scale,
        child: SizedBox(
          width: size,
          height: size,
          child: Image.asset(
            'assets/images/logo.png',
            fit: BoxFit.contain,
            // Fallback if asset not yet configured
            errorBuilder: (_, __, ___) => _FallbackLogo(size: size),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// SECTION 5 — BOTTOM ILLUSTRATION WIDGET
// =============================================================================

class _BottomIllustration extends StatelessWidget {
  final double opacity;
  final double screenWidth;

  const _BottomIllustration({
    required this.opacity,
    required this.screenWidth,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    // Bottom art takes up the bottom 38% of the screen — matches User_Flow
    final artHeight = size.height * 0.38;

    return Opacity(
      opacity: opacity.clamp(0.0, 1.0),
      child: SizedBox(
        width: screenWidth,
        height: artHeight,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // City skyline image — bleeds edge to edge
            Image.asset(
              'assets/images/splash_bg.png',
              width: screenWidth,
              height: artHeight,
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
              errorBuilder: (_, __, ___) => _FallbackSkyline(
                width: screenWidth,
                height: artHeight,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// SECTION 6 — FALLBACK LOGO  (pure Flutter — renders without asset)
// =============================================================================

class _FallbackLogo extends StatelessWidget {
  final double size;
  const _FallbackLogo({required this.size});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _LogoPainter()),
    );
  }
}

class _LogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width / 2;

    // Outer ring
    canvas.drawCircle(
      Offset(cx, cy),
      r - 2,
      Paint()
        ..color = _C.primary.withOpacity(0.15)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    // Inner secondary ring
    canvas.drawCircle(
      Offset(cx, cy),
      r * 0.75,
      Paint()
        ..color = _C.primary.withOpacity(0.10)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );

    // Main circle fill
    canvas.drawCircle(
      Offset(cx, cy),
      r * 0.58,
      Paint()
        ..color = _C.waveLight
        ..style = PaintingStyle.fill,
    );

    // Chat bubble icon (simplified)
    final bubblePaint = Paint()
      ..color = _C.primary
      ..style = PaintingStyle.fill;

    // Main bubble
    final bubblePath = Path()
      ..addRRect(RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(cx, cy - r * 0.06),
          width: r * 0.80,
          height: r * 0.58,
        ),
        Radius.circular(r * 0.18),
      ));
    canvas.drawPath(bubblePath, bubblePaint);

    // Sound waves (left side)
    final wavePaint = Paint()
      ..color = _C.secondary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    for (var i = 1; i <= 2; i++) {
      final waveR = r * (0.62 + i * 0.12);
      canvas.drawArc(
        Rect.fromCenter(
            center: Offset(cx, cy), width: waveR * 2, height: waveR * 2),
        math.pi * 0.62,
        math.pi * 0.26,
        false,
        wavePaint..color = _C.secondary.withOpacity(1.0 - i * 0.25),
      );
      canvas.drawArc(
        Rect.fromCenter(
            center: Offset(cx, cy), width: waveR * 2, height: waveR * 2),
        math.pi * 1.62,
        math.pi * 0.26,
        false,
        wavePaint..color = _C.secondary.withOpacity(1.0 - i * 0.25),
      );
    }

    // 3 person dots inside bubble
    final dotPaint = Paint()
      ..color = _C.waveLight
      ..style = PaintingStyle.fill;
    final dotY = cy - r * 0.06;
    for (var i = -1; i <= 1; i++) {
      canvas.drawCircle(
        Offset(cx + i * r * 0.20, dotY),
        r * 0.07,
        dotPaint,
      );
    }

    // Airplane top-right
    final planePaint = Paint()
      ..color = _C.secondary
      ..style = PaintingStyle.fill;
    final planeX = cx + r * 0.42;
    final planeY = cy - r * 0.62;
    canvas.save();
    canvas.translate(planeX, planeY);
    canvas.rotate(-math.pi * 0.22);
    // Simple airplane shape
    final planePath = Path()
      ..moveTo(0, -8)
      ..lineTo(3, 0)
      ..lineTo(0, 2)
      ..lineTo(-3, 0)
      ..close();
    canvas.drawPath(planePath, planePaint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_LogoPainter _) => false;
}

// =============================================================================
// SECTION 7 — FALLBACK SKYLINE PAINTER  (renders without asset)
// Matches the visual style from ChatGPT_Image (beige/gold city on green wave)
// =============================================================================

class _FallbackSkyline extends StatelessWidget {
  final double width;
  final double height;

  const _FallbackSkyline({required this.width, required this.height});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(width, height),
      painter: _SkylinePainter(),
    );
  }
}

class _SkylinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // ── Green wave base (bottom portion) ────────────────────────────────────
    final wavePaint = Paint()
      ..color = _C.primary
      ..style = PaintingStyle.fill;

    final wavePath = Path();
    final waveTop = h * 0.52;

    wavePath.moveTo(0, waveTop + 18);
    wavePath.cubicTo(
        w * 0.12, waveTop - 10, w * 0.28, waveTop + 28, w * 0.50, waveTop + 4);
    wavePath.cubicTo(
        w * 0.70, waveTop - 18, w * 0.85, waveTop + 22, w, waveTop + 8);
    wavePath.lineTo(w, h);
    wavePath.lineTo(0, h);
    wavePath.close();
    canvas.drawPath(wavePath, wavePaint);

    // Lighter wave layer for depth
    final wave2Paint = Paint()
      ..color = _C.primaryDark
      ..style = PaintingStyle.fill;

    final wave2Path = Path();
    final wave2Top = h * 0.62;
    wave2Path.moveTo(0, wave2Top + 10);
    wave2Path.cubicTo(w * 0.20, wave2Top - 8, w * 0.45, wave2Top + 20, w * 0.65,
        wave2Top - 5);
    wave2Path.cubicTo(
        w * 0.80, wave2Top - 18, w * 0.92, wave2Top + 10, w, wave2Top + 3);
    wave2Path.lineTo(w, h);
    wave2Path.lineTo(0, h);
    wave2Path.close();
    canvas.drawPath(wave2Path, wave2Paint);

    // ── City silhouette buildings ────────────────────────────────────────────
    final buildPaint = Paint()
      ..color = _C.waveLight
      ..style = PaintingStyle.fill;

    final accentPaint = Paint()
      ..color = _C.secondary.withOpacity(0.70)
      ..style = PaintingStyle.fill;

    // Ground baseline where buildings sit
    final groundY = h * 0.50;

    // [x_ratio, w_ratio, h_ratio, isAccent]
    final buildings = <List<double>>[
      [0.02, 0.05, 0.38, 0], // left edge
      [0.08, 0.11, 0.22, 0],
      [0.13, 0.05, 0.30, 0], // Big Ben style
      [0.20, 0.08, 0.18, 0],
      [0.30, 0.04, 0.26, 0],
      [0.36, 0.13, 0.15, 0],
      [0.44, 0.05, 0.44, 1], // Eiffel-style center
      [0.51, 0.10, 0.20, 0],
      [0.60, 0.06, 0.32, 0],
      [0.67, 0.04, 0.22, 0],
      [0.72, 0.09, 0.34, 1], // Dubai tower style
      [0.82, 0.05, 0.19, 0],
      [0.88, 0.07, 0.28, 0],
      [0.94, 0.05, 0.16, 0],
    ];

    for (final b in buildings) {
      final bx = w * b[0];
      final bw = w * b[1];
      final bh = h * b[2];
      final isAc = b[3] == 1.0;

      canvas.drawRRect(
        RRect.fromRectAndCorners(
          Rect.fromLTWH(bx, groundY - bh, bw, bh),
          topLeft: const Radius.circular(2),
          topRight: const Radius.circular(2),
        ),
        isAc ? accentPaint : buildPaint,
      );

      // Windows
      if (!isAc && bw > w * 0.06) {
        final winPaint = Paint()
          ..color = _C.primary.withOpacity(0.25)
          ..style = PaintingStyle.fill;
        const winW = 3.0;
        const winH = 3.5;
        const winGapX = 6.0;
        const winGapY = 7.0;

        var wy = groundY - bh + 8;
        while (wy < groundY - 8) {
          var wx = bx + 5;
          while (wx < bx + bw - 8) {
            canvas.drawRect(Rect.fromLTWH(wx, wy, winW, winH), winPaint);
            wx += winGapX;
          }
          wy += winGapY;
        }
      }
    }

    // Palm trees (left + right)
    _drawPalmTree(canvas, Offset(w * 0.07, groundY - 2), h * 0.18, buildPaint);
    _drawPalmTree(canvas, Offset(w * 0.93, groundY - 2), h * 0.14, buildPaint);
  }

  void _drawPalmTree(Canvas canvas, Offset base, double height, Paint paint) {
    // Trunk
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(base.dx - 2, base.dy - height, 4, height),
        const Radius.circular(2),
      ),
      paint,
    );

    // Leaves
    final leafPaint = Paint()
      ..color = paint.color
      ..style = PaintingStyle.fill;
    final top = Offset(base.dx, base.dy - height);
    final leafPath = Path()
      ..moveTo(top.dx, top.dy)
      ..quadraticBezierTo(top.dx - 18, top.dy - 10, top.dx - 26, top.dy - 4)
      ..quadraticBezierTo(top.dx - 14, top.dy - 6, top.dx, top.dy)
      ..moveTo(top.dx, top.dy)
      ..quadraticBezierTo(top.dx + 18, top.dy - 10, top.dx + 26, top.dy - 4)
      ..quadraticBezierTo(top.dx + 14, top.dy - 6, top.dx, top.dy)
      ..moveTo(top.dx, top.dy)
      ..quadraticBezierTo(top.dx - 8, top.dy - 20, top.dx - 4, top.dy - 28)
      ..quadraticBezierTo(top.dx - 2, top.dy - 14, top.dx, top.dy);
    canvas.drawPath(leafPath, leafPaint);
  }

  @override
  bool shouldRepaint(_SkylinePainter _) => false;
}

// =============================================================================
// SECTION 8 — NAVIGATION COMPLETE
// Authenticated users route to HomePage; guests route straight to LoginPage
// (country selection now happens during registration).
// =============================================================================

// =============================================================================
// MUBTAATH — QIBLA SCREEN  (v4 — sensor timeout + static fallback for web/sim)
// =============================================================================
// Fixes v4:
//   • kIsWeb → immediate static card (no SmoothCompass attempt on web).
//   • 4-second timeout on native: if sensor delivers no data, switch to the
//     static _StaticQiblaFallback showing the calculated bearing + fixed dial.
//   • Live compass unchanged for real devices with a working magnetometer.
// =============================================================================

import 'dart:async';
import 'dart:math' as math;

import 'package:adhan/adhan.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geocoding/geocoding.dart' as geo;
import 'package:geolocator/geolocator.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mubtaath/core/l10n/app_localizations.dart';
import 'package:mubtaath/core/services/location_cache_service.dart';
import 'package:mubtaath/core/utils/nominatim_geocoder.dart';
import 'package:mubtaath/core/theme/app_colors.dart';
import 'package:mubtaath/core/widgets/shared_widgets.dart';
import 'package:smooth_compass/utils/src/compass_ui.dart';

// =============================================================================
// SECTION 1 — QIBLA STATE
// =============================================================================

enum QiblaStatus { loading, loaded, permissionDenied, serviceDisabled, error }

class QiblaState {
  final QiblaStatus status;
  final double      qiblaAngle;
  final String      locationLabel;

  const QiblaState({
    this.status        = QiblaStatus.loading,
    this.qiblaAngle    = 0.0,
    this.locationLabel = '',
  });

  bool get isLoaded        => status == QiblaStatus.loaded;
  bool get isLoading       => status == QiblaStatus.loading;
  bool get hasError        => !isLoading && !isLoaded;
  bool get isPermissionErr => status == QiblaStatus.permissionDenied ||
                              status == QiblaStatus.serviceDisabled;
}

// =============================================================================
// SECTION 2 — QIBLA CUBIT
// =============================================================================

class QiblaCubit extends Cubit<QiblaState> {
  QiblaCubit() : super(_seedState()) {
    _init();
  }

  double? _lat;
  double? _lng;

  // ── Synchronous seed for the very first frame ───────────────────────────
  // Even a fast SharedPreferences read is still `await`ed (at least one
  // microtask tick), which is enough for the first frame to paint the
  // loading spinner before it resolves. If Prayer Times (or an earlier
  // Qibla visit) already warmed LocationCacheService's in-memory copy this
  // session, start straight from `loaded` instead — no flash.
  static QiblaState _seedState() {
    final mem = LocationCacheService.instance.memorySync;
    if (mem == null) return const QiblaState();
    final angle = Qibla(Coordinates(mem.lat, mem.lng)).direction;
    return QiblaState(
      status:        QiblaStatus.loaded,
      qiblaAngle:    angle,
      locationLabel: mem.cityAr.isNotEmpty ? mem.cityAr : mem.cityEn,
    );
  }

  // ── Init: instant from cache when available, GPS only the first time ───────
  // Mirrors PrayerCubit's approach — opening the page should never block on
  // a fresh GPS fix + reverse-geocode if we already know where the device is.
  Future<void> _init() async {
    if (isClosed) return;

    final mem = LocationCacheService.instance.memorySync;
    if (mem != null) {
      // Constructor already seeded the state from this — just track the
      // coordinates and let the background check confirm/refresh silently.
      _lat = mem.lat;
      _lng = mem.lng;
      unawaited(_refreshLocationInBackground());
      return;
    }

    final cached = await LocationCacheService.instance.read();
    if (isClosed) return;

    if (cached != null) {
      _lat = cached.lat;
      _lng = cached.lng;
      final coords = Coordinates(cached.lat, cached.lng);
      final angle  = Qibla(coords).direction;
      emit(QiblaState(
        status:        QiblaStatus.loaded,
        qiblaAngle:    angle,
        locationLabel: cached.cityAr.isNotEmpty ? cached.cityAr : cached.cityEn,
      ));
      unawaited(_refreshLocationInBackground());
      return;
    }

    await _load();
  }

  // ── Full GPS fetch + geocode + cache write (cold start, retry, or the
  //    background check finding a real move). ────────────────────────────────
  Future<void> _load() async {
    if (isClosed) return;
    emit(const QiblaState(status: QiblaStatus.loading));

    final svcEnabled = await Geolocator.isLocationServiceEnabled();
    if (isClosed) return;
    if (!svcEnabled) {
      emit(const QiblaState(status: QiblaStatus.serviceDisabled));
      return;
    }

    LocationPermission perm = await Geolocator.checkPermission();
    if (isClosed) return;
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
      if (isClosed) return;
    }
    if (perm == LocationPermission.denied ||
        perm == LocationPermission.deniedForever) {
      emit(const QiblaState(status: QiblaStatus.permissionDenied));
      return;
    }

    Position pos;
    try {
      pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
        timeLimit: const Duration(seconds: 20),
      );
    } catch (_) {
      if (isClosed) return;
      emit(const QiblaState(status: QiblaStatus.error));
      return;
    }
    if (isClosed) return;

    _lat = pos.latitude;
    _lng = pos.longitude;

    String labelAr = '';
    String labelEn = '';
    String isoCode = 'GB';

    // 1. Local geocoding — fast on real devices, fails silently on web/simulators.
    try {
      final places = await geo.placemarkFromCoordinates(
        pos.latitude, pos.longitude,
      );
      if (isClosed) return;
      if (places.isNotEmpty) {
        final p = places.first;
        isoCode = p.isoCountryCode ?? 'GB';
        String local = '';
        if (p.locality?.isNotEmpty == true) {
          local = p.locality!;
        } else if (p.subAdministrativeArea?.isNotEmpty == true) {
          local = p.subAdministrativeArea!;
        } else {
          local = p.administrativeArea ?? '';
        }
        labelEn = local;
        labelAr = local;
      }
    } catch (_) {
      if (isClosed) return;
    }

    // 2. Nominatim fallback for bilingual names when local geocoding returns empty.
    if (labelEn.isEmpty) {
      final (:ar, :en) = await nominatimReverse(pos.latitude, pos.longitude);
      if (isClosed) return;
      if (ar.isNotEmpty) labelAr = ar;
      if (en.isNotEmpty) labelEn = en;
    }

    if (isClosed) return;
    final coords = Coordinates(pos.latitude, pos.longitude);
    final angle  = Qibla(coords).direction;

    await LocationCacheService.instance.write(CachedLocation(
      lat: pos.latitude, lng: pos.longitude, isoCode: isoCode,
      cityAr: labelAr, cityEn: labelEn,
    ));
    if (isClosed) return;

    emit(QiblaState(
      status:        QiblaStatus.loaded,
      qiblaAngle:    angle,
      locationLabel: labelAr.isNotEmpty ? labelAr : labelEn,
    ));
  }

  // ── Silent background check — only touches the UI if the device has
  //    actually moved a meaningful distance since the cached fix. ───────────
  Future<void> _refreshLocationInBackground() async {
    try {
      final svcEnabled = await Geolocator.isLocationServiceEnabled();
      if (!svcEnabled || isClosed) return;

      final perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
        timeLimit: const Duration(seconds: 20),
      );
      if (isClosed) return;

      final movedMeters = (_lat != null && _lng != null)
          ? Geolocator.distanceBetween(_lat!, _lng!, pos.latitude, pos.longitude)
          : double.infinity;
      if (movedMeters < LocationCacheService.significantMoveMeters) return;

      // A real move — re-fetch properly (re-geocodes + re-caches + re-emits).
      await _load();
    } catch (_) {
      // Silent — the cached data already on screen remains valid either way.
    }
  }

  void retry() => _load();
}

// =============================================================================
// SECTION 3 — COMPASS DIAL PAINTER  (pure vector)
// =============================================================================

class _QiblaDialPainter extends CustomPainter {
  final double heading;      // smoothed device heading (degrees from north)
  final double qiblaAngle;   // qibla bearing from north (degrees)
  final bool   isAligned;    // true when the phone is facing the Qibla
  final Color  primaryColor;
  final Color  accentColor;  // Kaaba marker riding the needle tip
  final Color  bgColor;
  final Color  borderColor;
  final Color  alignedColor; // fills the whole dial when facing the Qibla

  const _QiblaDialPainter({
    required this.heading,
    required this.qiblaAngle,
    required this.isAligned,
    required this.primaryColor,
    required this.accentColor,
    required this.bgColor,
    required this.borderColor,
    required this.alignedColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width  / 2;
    final cy = size.height / 2;
    final r  = size.width  / 2 - 2;
    final center = Offset(cx, cy);

    final needleRad = (qiblaAngle - heading) * math.pi / 180;

    // ── Dial background — turns SOLID GREEN when facing the Qibla ──────────────
    canvas.drawCircle(
      center, r,
      Paint()
        ..style = PaintingStyle.fill
        ..color = isAligned ? alignedColor : bgColor,
    );
    canvas.drawCircle(
      center, r,
      Paint()
        ..style       = PaintingStyle.stroke
        ..strokeWidth = isAligned ? 2.6 : 1.8
        ..color       = isAligned ? alignedColor : borderColor,
    );
    if (!isAligned) {
      canvas.drawCircle(
        center, r * 0.88,
        Paint()
          ..color       = primaryColor.withValues(alpha: 0.08)
          ..style       = PaintingStyle.stroke
          ..strokeWidth = 1.0,
      );
    }

    // ── Compass rose (ticks + cardinals) — screen-fixed, does not rotate ──────
    final minorTick = isAligned ? AppColors.white.withValues(alpha: 0.45) : borderColor;
    final majorTick = isAligned ? AppColors.white : primaryColor.withValues(alpha: 0.55);
    for (var i = 0; i < 72; i++) {
      final a     = i * 5 * math.pi / 180;
      final isMaj = i % 18 == 0;
      final isMed = i % 9 == 0;
      final inner = r - (isMaj ? 16 : isMed ? 10 : 6);
      canvas.drawLine(
        Offset(cx + inner   * math.sin(a), cy - inner   * math.cos(a)),
        Offset(cx + (r - 3) * math.sin(a), cy - (r - 3) * math.cos(a)),
        Paint()
          ..color = isMaj
              ? majorTick
              : minorTick.withValues(alpha: isMed ? 0.70 : 0.40)
          ..strokeWidth = isMaj ? 1.8 : isMed ? 1.2 : 0.7,
      );
    }

    final cardinals = <String, double>{'N': 0, 'E': 90, 'S': 180, 'W': 270};
    for (final e in cardinals.entries) {
      final a  = e.value * math.pi / 180;
      final dx = cx + (r - 28) * math.sin(a);
      final dy = cy - (r - 28) * math.cos(a);
      final tp = TextPainter(
        text: TextSpan(
          text: e.key,
          style: TextStyle(
            fontSize: 13, fontWeight: FontWeight.w800,
            color: isAligned
                ? AppColors.white.withValues(alpha: e.key == 'N' ? 1.0 : 0.72)
                : (e.key == 'N'
                    ? primaryColor
                    : borderColor.withValues(alpha: 200 / 255)),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(dx - tp.width / 2, dy - tp.height / 2));
    }

    // ── Needle — ONE colour, same big length on BOTH ends ─────────────────────
    final needleColor = isAligned ? AppColors.white : primaryColor;
    final len = r - 42;
    canvas.save();
    canvas.translate(cx, cy);
    canvas.rotate(needleRad);
    // Qibla-pointing end (solid).
    canvas.drawPath(
      Path()..moveTo(0, -len)..lineTo(-8, 0)..lineTo(8, 0)..close(),
      Paint()
        ..color      = needleColor
        ..style      = PaintingStyle.fill
        ..strokeJoin = StrokeJoin.round,
    );
    // Opposite end — SAME big length, faded (still one colour).
    canvas.drawPath(
      Path()..moveTo(0, len)..lineTo(-8, 0)..lineTo(8, 0)..close(),
      Paint()
        ..color      = needleColor.withValues(alpha: 0.32)
        ..style      = PaintingStyle.fill
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.restore();

    // ── Outline Kaaba marker riding the Qibla-pointing tip ─────────────────────
    final kx = cx + (r - 30) * math.sin(needleRad);
    final ky = cy - (r - 30) * math.cos(needleRad);
    paintKaabaGlyph(
      canvas, Offset(kx, ky), 16,
      isAligned ? AppColors.white : accentColor,
      strokeWidth: 2,
    );

    // ── Center hub ────────────────────────────────────────────────────────────
    canvas.drawCircle(center, 7, Paint()..color = needleColor);
    canvas.drawCircle(
      center, 3,
      Paint()..color = isAligned ? alignedColor : AppColors.white,
    );
  }

  @override
  bool shouldRepaint(_QiblaDialPainter old) =>
      old.heading    != heading    ||
      old.qiblaAngle != qiblaAngle ||
      old.isAligned  != isAligned;
}

// =============================================================================
// SECTION 4 — VALUE PILL
// =============================================================================

class _ValuePill extends StatelessWidget {
  final String label;
  final String value;
  final bool   isHighlighted;

  const _ValuePill({
    required this.label,
    required this.value,
    this.isHighlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    // Clean, solid chips — no light-tint-with-matching-border look.
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
      decoration: BoxDecoration(
        color:        isHighlighted ? AppColors.secondary : AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: (isHighlighted ? AppColors.secondary : AppColors.primary)
                .withValues(alpha: isHighlighted ? 0.28 : 0.08),
            blurRadius: 12,
            offset:     const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: TextStyle(
              fontFamily: 'Cairo', fontSize: 17, fontWeight: FontWeight.w800,
              color: isHighlighted ? AppColors.white : AppColors.primary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Tajawal', fontSize: 11,
              color: isHighlighted
                  ? AppColors.white.withValues(alpha: 0.85)
                  : AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// SECTION 5 — STATIC QIBLA FALLBACK
// Shown when: web platform, simulator, or any device without a magnetometer.
// Displays the mathematically calculated Qibla bearing with a fixed compass dial.
// =============================================================================

class _StaticQiblaFallback extends StatelessWidget {
  final double qiblaAngle;
  const _StaticQiblaFallback({required this.qiblaAngle});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width:  240,
          height: 240,
          child: CustomPaint(
            // No live heading here — north-up dial, needle at the Qibla bearing.
            painter: _QiblaDialPainter(
              heading:      0,
              qiblaAngle:   qiblaAngle,
              isAligned:    false,
              primaryColor: AppColors.primary,
              accentColor:  AppColors.secondary,
              bgColor:      AppColors.background,
              borderColor:  AppColors.cardBorder,
              alignedColor: AppColors.primary,
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Info card — clean surface, soft shadow (no tinted-border box)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
          decoration: BoxDecoration(
            color:        AppColors.surface,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color:      AppColors.primary.withValues(alpha: 0.08),
                blurRadius: 16,
                offset:     const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l10n.staticCompassNote,
                style: const TextStyle(
                  fontFamily: 'Cairo', fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.secondary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.degreeFromNorth(qiblaAngle.toStringAsFixed(1)),
                style: const TextStyle(
                  fontFamily: 'Cairo', fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),

        // Degree pill
        _ValuePill(
          label:         l10n.qiblaLabel,
          value:         '${qiblaAngle.toStringAsFixed(1)}°',
          isHighlighted: true,
        ),
      ],
    );
  }
}

// =============================================================================
// SECTION 6 — LIVE COMPASS WIDGET
// StatefulWidget with a 4-second sensor timeout.
// Falls back to _StaticQiblaFallback if no magnetometer data arrives.
// =============================================================================

class _LiveQiblaCompass extends StatefulWidget {
  final double qiblaAngle;
  const _LiveQiblaCompass({required this.qiblaAngle});

  @override
  State<_LiveQiblaCompass> createState() => _LiveQiblaCompassState();
}

class _LiveQiblaCompassState extends State<_LiveQiblaCompass>
    with SingleTickerProviderStateMixin {
  bool   _sensorTimedOut  = false;
  bool   _hasReceivedData = false;
  Timer? _timeoutTimer;

  late final AnimationController _ticker;

  // smooth_compass polls the native sensor on a fixed ~200ms interval — that
  // is a hard floor on how often the true heading can change, regardless of
  // anything on our side. Rather than low-pass filtering on top of that
  // (which *adds* extra lag chasing an ever-moving target), we linearly
  // interpolate between consecutive raw samples over exactly that interval:
  // the displayed heading always reaches the real value by the time the next
  // sample arrives, so perceived lag never exceeds one sample (~200ms) — and
  // motion between samples is still perfectly smooth.
  static const int _sampleIntervalMs = 200;
  double?   _segFrom;    // heading at the start of the current segment
  double?   _segTo;      // latest raw sample — the segment's target
  DateTime? _segStartAt; // wall-clock time the current segment began
  double    _displayHeading = 0;
  bool      _wasAligned = false;

  static const double _alignThresholdDeg = 5;

  // ── Calibration-needed detection ────────────────────────────────────────
  // smooth_compass exposes no sensor-accuracy signal at all (it reads
  // Android's fused ROTATION_VECTOR sensor with no accuracy callback), so we
  // infer "needs calibration" ourselves: a magnetometer confused by nearby
  // interference makes the heading reverse direction sharply and repeatedly
  // (jumps back and forth) — unlike a real hand rotation, which accelerates
  // and decelerates smoothly in ONE direction. Two such reversals in the
  // last 8 samples (~1.6s) is a strong tell.
  double?          _lastRawHeading;
  final List<double> _recentDeltas = [];
  static const int   _deltaWindowSize = 8;
  static const double _bigJumpDeg = 25;
  bool _needsCalibration = false;

  // Shown once per screen visit, the moment interference is first detected —
  // never on a compass that was accurate from the start, and never spammed
  // again if it flips true a second time after the user already dismissed it.
  bool _calibrationSheetShown = false;

  double _lerpAngle(double a, double b, double t) {
    var diff = b - a;
    while (diff > 180)  { diff -= 360; }
    while (diff < -180) { diff += 360; }
    var result = (a + diff * t) % 360;
    if (result < 0) result += 360;
    return result;
  }

  void _trackStability(double rawHeading) {
    final prev = _lastRawHeading;
    _lastRawHeading = rawHeading;
    if (prev == null) return;

    var diff = rawHeading - prev;
    while (diff > 180)  { diff -= 360; }
    while (diff < -180) { diff += 360; }

    _recentDeltas.add(diff);
    if (_recentDeltas.length > _deltaWindowSize) _recentDeltas.removeAt(0);

    var reversals = 0;
    for (var i = 1; i < _recentDeltas.length; i++) {
      final a = _recentDeltas[i - 1];
      final b = _recentDeltas[i];
      if (a.abs() > _bigJumpDeg && b.abs() > _bigJumpDeg && (a > 0) != (b > 0)) {
        reversals++;
      }
    }

    final wasNeeded = _needsCalibration;
    _needsCalibration = reversals >= 2;

    // Fire the sheet on the false→true transition only, and only once ever
    // per visit. This runs mid-build (called from compassBuilder), so the
    // sheet itself must wait for the frame to finish.
    if (_needsCalibration && !wasNeeded && !_calibrationSheetShown) {
      _calibrationSheetShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showCalibrationSheet();
      });
    }
  }

  void _showCalibrationSheet() {
    final l10n = AppLocalizations.of(context)!;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetCtx) => Container(
        padding: EdgeInsets.fromLTRB(
          24, 12, 24, MediaQuery.of(sheetCtx).padding.bottom + 24,
        ),
        decoration: const BoxDecoration(
          color:        AppColors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color:        AppColors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Container(
              width: 56, height: 56,
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              child: const Icon(LucideIcons.infinity,
                  size: 28, color: AppColors.warning),
            ),
            const SizedBox(height: 16),
            Text(
              l10n.compassNeedsCalibration,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Cairo', fontSize: 16,
                fontWeight: FontWeight.w800, color: AppColors.deepDark,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.compassCalibrationHint,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Tajawal', fontSize: 13.5,
                color: AppColors.textSecondary, height: 1.6,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.of(sheetCtx).pop(),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  l10n.gotIt,
                  style: const TextStyle(
                    fontFamily: 'Cairo', fontWeight: FontWeight.w700,
                    color: AppColors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    // A free-running 60fps clock. We ignore its value and use each tick to
    // nudge the displayed heading toward the sensor target — this decouples
    // rendering from the (sporadic) sensor events so the needle GLIDES rather
    // than stepping between frames.
    _ticker = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat();

    if (!kIsWeb) {
      _timeoutTimer = Timer(const Duration(seconds: 4), () {
        if (mounted && !_hasReceivedData) {
          setState(() => _sensorTimedOut = true);
        }
      });
    }
  }

  @override
  void dispose() {
    _timeoutTimer?.cancel();
    _ticker.dispose();
    super.dispose();
  }

  // Called on every new raw sensor sample (~every 200ms) — starts a fresh
  // interpolation segment FROM wherever the needle currently is TO the new
  // reading, timed to finish exactly when the next sample is due.
  void _onNewSample(double rawHeading) {
    _segFrom    = _displayHeading;
    _segTo      = rawHeading;
    _segStartAt = DateTime.now();
    _trackStability(rawHeading);
  }

  // Called every animation frame (~60fps) — advances the display along the
  // current segment. Bounded lag: never more than one sample interval behind.
  void _advance() {
    final from = _segFrom;
    final to   = _segTo;
    final startAt = _segStartAt;
    if (to == null) return;
    if (from == null || startAt == null) {
      _displayHeading = to;
      return;
    }
    final elapsedMs = DateTime.now().difference(startAt).inMilliseconds;
    final t = (elapsedMs / _sampleIntervalMs).clamp(0.0, 1.0);
    _displayHeading = _lerpAngle(from, to, t);
  }

  double _alignmentDelta() {
    var d = widget.qiblaAngle - _displayHeading;
    while (d > 180)  { d -= 360; }
    while (d < -180) { d += 360; }
    return d;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    // Web or timed-out simulator → static bearing card.
    if (kIsWeb || _sensorTimedOut) {
      return _StaticQiblaFallback(qiblaAngle: widget.qiblaAngle);
    }

    return SmoothCompass(
      // Note: rotationSpeed only affects the package's own AnimatedRotation
      // path (used when a `compassAsset` is supplied); we drive our own
      // custom-painted needle via `compassBuilder` instead, so it's unused.
      isQiblahCompass: false,
      compassBuilder: (BuildContext ctx, AsyncSnapshot<CompassModel>? snapshot, Widget _) {
        final rawHeading = snapshot?.data?.angle;

        // No sensor data yet — show calibrating spinner.
        if (rawHeading == null) {
          return SizedBox(
            width: 240, height: 300,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const MubtaathLoader(
                  color: AppColors.primary, strokeWidth: 2.5,
                ),
                const SizedBox(height: 14),
                Text(
                  l10n.calibrating,
                  style: const TextStyle(
                    fontFamily: 'Tajawal', fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          );
        }

        // Sensor is working — start a new interpolation segment toward this
        // fresh reading, and cancel the timeout.
        _onNewSample(rawHeading);
        if (!_hasReceivedData) {
          _hasReceivedData = true;
          _timeoutTimer?.cancel();
        }

        // Repaint every frame from the ticker (independent of sensor events).
        return AnimatedBuilder(
          animation: _ticker,
          builder: (context, _) {
            _advance();
            final aligned = _alignmentDelta().abs() <= _alignThresholdDeg;
            if (aligned && !_wasAligned) {
              HapticFeedback.mediumImpact();
            }
            _wasAligned = aligned;

            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width:  240,
                  height: 240,
                  child: CustomPaint(
                    painter: _QiblaDialPainter(
                      heading:      _displayHeading,
                      qiblaAngle:   widget.qiblaAngle,
                      isAligned:    aligned,
                      primaryColor: AppColors.primary,
                      accentColor:  AppColors.secondary,
                      bgColor:      AppColors.background,
                      borderColor:  AppColors.cardBorder,
                      alignedColor: AppColors.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  height: 20,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 200),
                    opacity:  aligned ? 1 : 0,
                    child: Text(
                      l10n.facingQibla,
                      style: const TextStyle(
                        fontFamily: 'Cairo', fontSize: 14,
                        fontWeight: FontWeight.w800, color: AppColors.primary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _ValuePill(
                      label: l10n.directionLabel,
                      value: '${_displayHeading.toStringAsFixed(0)}°',
                    ),
                    const SizedBox(width: 12),
                    _ValuePill(
                      label:         l10n.qiblaLabel,
                      value:         '${widget.qiblaAngle.toStringAsFixed(0)}°',
                      isHighlighted: true,
                    ),
                  ],
                ),
              ],
            );
          },
        );
      },
    );
  }
}

// =============================================================================
// SECTION 7 — ERROR VIEW
// =============================================================================

class _QiblaErrorView extends StatelessWidget {
  final QiblaState state;
  const _QiblaErrorView({required this.state});

  @override
  Widget build(BuildContext context) {
    final l10n  = AppLocalizations.of(context)!;
    final cubit = context.read<QiblaCubit>();

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                state.isPermissionErr ? LucideIcons.mapPinOff : LucideIcons.wifiOff,
                size: 36, color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              state.isPermissionErr
                  ? l10n.locationPermissionMsg
                  : l10n.locationError,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Tajawal', fontSize: 14,
                color: AppColors.textSecondary, height: 1.6,
              ),
            ),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: state.isPermissionErr
                  ? () => Geolocator.openAppSettings()
                  : cubit.retry,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 13),
                decoration: BoxDecoration(
                  color: AppColors.primary, borderRadius: BorderRadius.circular(24),
                ),
                child: Text(
                  state.isPermissionErr ? l10n.openSettings : l10n.tryAgain,
                  style: const TextStyle(
                    fontFamily: 'Cairo', fontSize: 14,
                    fontWeight: FontWeight.w700, color: AppColors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// SECTION 8 — QIBLA SCREEN (full page)
// =============================================================================

class QiblaScreen extends StatelessWidget {
  const QiblaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => QiblaCubit(),
      child: const _QiblaScreenContent(),
    );
  }
}

class _QiblaScreenContent extends StatelessWidget {
  const _QiblaScreenContent();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: CoreAppBar(title: l10n.qiblaDirection, showBack: true),
      body: BlocBuilder<QiblaCubit, QiblaState>(
        builder: (context, state) {
          // ── Loading ────────────────────────────────────────────────────────
          if (state.isLoading) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const MubtaathLoader(
                    color: AppColors.primary, strokeWidth: 2.5,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    l10n.loadingLocation,
                    style: const TextStyle(
                      fontFamily: 'Tajawal', fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            );
          }

          // ── Error ──────────────────────────────────────────────────────────
          if (state.hasError) {
            return _QiblaErrorView(state: state);
          }

          // ── Loaded ─────────────────────────────────────────────────────────
          return SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 24),

                MubtaethCard(
                  padding:           const EdgeInsets.all(20),
                  borderRadiusValue: 20,
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            LucideIcons.compass,
                            color: AppColors.primary, size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            l10n.liveCompass,
                            style: const TextStyle(
                              fontFamily: 'Cairo', fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),

                      if (state.locationLabel.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              LucideIcons.mapPin,
                              size: 13, color: AppColors.textSecondary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              state.locationLabel,
                              style: const TextStyle(
                                fontFamily: 'Tajawal', fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ],

                      const SizedBox(height: 6),
                      Text(
                        l10n.compassInstruction,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontFamily: 'Tajawal', fontSize: 13,
                          color: AppColors.textSecondary, height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Live compass — or static fallback on web/simulator
                      _LiveQiblaCompass(qiblaAngle: state.qiblaAngle),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color:        AppColors.surface,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color:      AppColors.primary.withValues(alpha: 0.06),
                        blurRadius: 14,
                        offset:     const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(LucideIcons.info,
                              size: 16, color: AppColors.primary),
                          const SizedBox(width: 8),
                          Text(
                            l10n.howToUse,
                            style: const TextStyle(
                              fontFamily: 'Cairo', fontSize: 14,
                              fontWeight: FontWeight.w700, color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        l10n.qiblaInstructions,
                        style: const TextStyle(
                          fontFamily: 'Tajawal', fontSize: 13,
                          color: AppColors.textSecondary, height: 1.7,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 40),
              ],
            ),
          );
        },
      ),
    );
  }
}

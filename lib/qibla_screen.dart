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
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geocoding/geocoding.dart' as geo;
import 'package:geolocator/geolocator.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mubtaath/core/l10n/app_localizations.dart';
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
  QiblaCubit() : super(const QiblaState()) {
    _load();
  }

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
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 20),
      );
    } catch (_) {
      if (isClosed) return;
      emit(const QiblaState(status: QiblaStatus.error));
      return;
    }
    if (isClosed) return;

    String labelAr = '';
    String labelEn = '';

    // 1. Local geocoding — fast on real devices, fails silently on web/simulators.
    try {
      final places = await geo.placemarkFromCoordinates(
        pos.latitude, pos.longitude,
      );
      if (isClosed) return;
      if (places.isNotEmpty) {
        final p = places.first;
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

    emit(QiblaState(
      status:        QiblaStatus.loaded,
      qiblaAngle:    angle,
      locationLabel: labelAr.isNotEmpty ? labelAr : labelEn,
    ));
  }

  void retry() => _load();
}

// =============================================================================
// SECTION 3 — COMPASS DIAL PAINTER  (pure vector)
// =============================================================================

class _QiblaDialPainter extends CustomPainter {
  final double needleAngleRad;
  final Color  primaryColor;
  final Color  secondaryColor;
  final Color  bgColor;
  final Color  borderColor;

  const _QiblaDialPainter({
    required this.needleAngleRad,
    required this.primaryColor,
    required this.secondaryColor,
    required this.bgColor,
    required this.borderColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width  / 2;
    final cy = size.height / 2;
    final r  = size.width  / 2 - 2;

    canvas.drawCircle(
      Offset(cx, cy), r,
      Paint()..color = bgColor..style = PaintingStyle.fill,
    );
    canvas.drawCircle(
      Offset(cx, cy), r,
      Paint()
        ..color       = borderColor
        ..style       = PaintingStyle.stroke
        ..strokeWidth = 1.8,
    );
    canvas.drawCircle(
      Offset(cx, cy), r * 0.88,
      Paint()
        ..color       = primaryColor.withValues(alpha: 0.08)
        ..style       = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );

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
              ? primaryColor.withValues(alpha: 0.55)
              : borderColor.withValues(alpha: isMed ? 0.70 : 0.40)
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
            color: e.key == 'N'
                ? primaryColor
                : borderColor.withValues(alpha: 200 / 255),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(dx - tp.width / 2, dy - tp.height / 2));
    }

    canvas.save();
    canvas.translate(cx, cy);
    canvas.rotate(needleAngleRad);

    final goldPath = Path()
      ..moveTo(0, -(r - 26))
      ..lineTo(-7, -6)
      ..lineTo(0, 10)
      ..lineTo(7, -6)
      ..close();
    canvas.drawPath(
      goldPath,
      Paint()..color = secondaryColor..style = PaintingStyle.fill,
    );
    canvas.drawPath(
      goldPath,
      Paint()
        ..color       = AppColors.black.withValues(alpha: 0.12)
        ..style       = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );

    final greenPath = Path()
      ..moveTo(0, 10)
      ..lineTo(-5, 0)
      ..lineTo(0, -(r - 46))
      ..lineTo(5, 0)
      ..close();
    canvas.drawPath(
      greenPath,
      Paint()
        ..color = primaryColor.withValues(alpha: 0.50)
        ..style = PaintingStyle.fill,
    );

    canvas.restore();

    final kx  = cx + (r - 34) * math.sin(needleAngleRad);
    final ky  = cy - (r - 34) * math.cos(needleAngleRad);
    final ktp = TextPainter(
      text: const TextSpan(text: '🕋', style: TextStyle(fontSize: 16)),
      textDirection: TextDirection.ltr,
    )..layout();
    ktp.paint(canvas, Offset(kx - ktp.width / 2, ky - ktp.height / 2));

    canvas.drawCircle(
      Offset(cx, cy), 9,
      Paint()..color = primaryColor..style = PaintingStyle.fill,
    );
    canvas.drawCircle(
      Offset(cx, cy), 4,
      Paint()..color = AppColors.white..style = PaintingStyle.fill,
    );
    canvas.drawCircle(
      Offset(cx, cy), 9,
      Paint()
        ..color       = secondaryColor.withValues(alpha: 0.40)
        ..style       = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(_QiblaDialPainter old) =>
      old.needleAngleRad != needleAngleRad;
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color:        isHighlighted
            ? AppColors.secondary.withValues(alpha: 0.12)
            : AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isHighlighted
              ? AppColors.secondary.withValues(alpha: 0.35)
              : AppColors.primary.withValues(alpha: 0.20),
          width: 1.0,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: TextStyle(
              fontFamily: 'Cairo', fontSize: 16, fontWeight: FontWeight.w800,
              color: isHighlighted ? AppColors.secondary : AppColors.primary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'Tajawal', fontSize: 11,
              color: AppColors.textSecondary,
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
    // Needle points at the Qibla bearing from True North (fixed, no device heading)
    final needleRad = qiblaAngle * (math.pi / 180);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width:  220,
          height: 220,
          child: CustomPaint(
            painter: _QiblaDialPainter(
              needleAngleRad: needleRad,
              primaryColor:   AppColors.primary,
              secondaryColor: AppColors.secondary,
              bgColor:        AppColors.background,
              borderColor:    AppColors.cardBorder,
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Info card
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.secondary.withValues(alpha: 0.10),
                AppColors.primary.withValues(alpha: 0.06),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.secondary.withValues(alpha: 0.28),
              width: 1.0,
            ),
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

class _LiveQiblaCompassState extends State<_LiveQiblaCompass> {
  bool   _sensorTimedOut   = false;
  bool   _hasReceivedData  = false;
  Timer? _timeoutTimer;

  @override
  void initState() {
    super.initState();
    // On web there is no magnetometer — skip SmoothCompass entirely.
    // On native, give the sensor 4 seconds to deliver a first reading.
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    // Web or timed-out simulator → static bearing card
    if (kIsWeb || _sensorTimedOut) {
      return _StaticQiblaFallback(qiblaAngle: widget.qiblaAngle);
    }

    return SmoothCompass(
      rotationSpeed:   200,
      isQiblahCompass: false,
      compassBuilder: (BuildContext ctx, AsyncSnapshot<CompassModel>? snapshot, Widget _) {
        final heading = snapshot?.data?.angle;

        // No sensor data yet — show calibrating spinner
        if (heading == null) {
          return SizedBox(
            width: 220, height: 258,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(
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

        // Sensor is working — cancel the timeout and mark data received
        if (!_hasReceivedData) {
          _hasReceivedData = true;
          _timeoutTimer?.cancel();
        }

        final needleRad = (widget.qiblaAngle - heading) * (math.pi / 180);

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width:  220,
              height: 220,
              child: CustomPaint(
                painter: _QiblaDialPainter(
                  needleAngleRad: needleRad,
                  primaryColor:   AppColors.primary,
                  secondaryColor: AppColors.secondary,
                  bgColor:        AppColors.background,
                  borderColor:    AppColors.cardBorder,
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _ValuePill(
                  label: l10n.directionLabel,
                  value: '${heading.toStringAsFixed(1)}°',
                ),
                const SizedBox(width: 12),
                _ValuePill(
                  label:         l10n.qiblaLabel,
                  value:         '${widget.qiblaAngle.toStringAsFixed(1)}°',
                  isHighlighted: true,
                ),
              ],
            ),
          ],
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
                  const CircularProgressIndicator(
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
                    color:        AppColors.primary.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      width: 1.0,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.howToUse,
                        style: const TextStyle(
                          fontFamily: 'Cairo', fontSize: 14,
                          fontWeight: FontWeight.w700, color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: 8),
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

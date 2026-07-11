// =============================================================================
// MUBTAATH — PRAYER TIMES PAGE  (v5 — bug-fixed, premium hero card)
// =============================================================================
// Fixes v5:
//   • Infinite-loop eliminated: coords cached after first GPS fix.
//     Timer calls _recalculate() (instant, no GPS) instead of _init().
//   • Hero card redesigned: deep gradient + gold border (no solid green block).
//   • Hero card shows: current prayer badge, city, next prayer + time, countdown.
// =============================================================================

import 'dart:async';

import 'package:adhan/adhan.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geocoding/geocoding.dart' as geo;
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mubtaath/core/l10n/app_localizations.dart';
import 'package:mubtaath/core/utils/nominatim_geocoder.dart';
import 'package:mubtaath/core/theme/app_colors.dart';
import 'package:mubtaath/core/widgets/shared_widgets.dart';

// =============================================================================
// SECTION 1 — ENUMS
// =============================================================================

enum PrayerStatus { initial, loading, loaded, permissionDenied, serviceDisabled, error }

enum PrayerName { fajr, sunrise, dhuhr, asr, maghrib, isha }

extension PrayerNameX on PrayerName {
  String label(AppLocalizations l10n) => switch (this) {
        PrayerName.fajr    => l10n.fajr,
        PrayerName.sunrise => l10n.sunrise,
        PrayerName.dhuhr   => l10n.dhuhr,
        PrayerName.asr     => l10n.asr,
        PrayerName.maghrib => l10n.maghrib,
        PrayerName.isha    => l10n.isha,
      };

  IconData get icon => switch (this) {
        PrayerName.fajr    => LucideIcons.sunrise,
        PrayerName.sunrise => LucideIcons.sun,
        PrayerName.dhuhr   => LucideIcons.sun,
        PrayerName.asr     => LucideIcons.cloudSun,
        PrayerName.maghrib => LucideIcons.sunset,
        PrayerName.isha    => LucideIcons.moon,
      };
}

// =============================================================================
// SECTION 2 — PRAYER TIME MODEL
// =============================================================================

class PrayerTime {
  final PrayerName name;
  final DateTime   dateTime;
  final bool       isNext;
  final bool       isPast;
  final bool       isAdhan;

  const PrayerTime({
    required this.name,
    required this.dateTime,
    this.isNext  = false,
    this.isPast  = false,
    this.isAdhan = true,
  });

  TimeOfDay get time => TimeOfDay.fromDateTime(dateTime);

  String formatted({AppLocalizations? l10n}) {
    final tod = time;
    final h   = tod.hourOfPeriod == 0 ? 12 : tod.hourOfPeriod;
    final m   = tod.minute.toString().padLeft(2, '0');
    final per = l10n != null
        ? (tod.period == DayPeriod.am ? l10n.timePeriodAm : l10n.timePeriodPm)
        : (tod.period == DayPeriod.am ? 'AM' : 'PM');
    return '$h:$m $per';
  }
}

// =============================================================================
// SECTION 3 — STATE
// =============================================================================

class PrayerState {
  final PrayerStatus     status;
  final List<PrayerTime> prayers;
  final Duration         countdown;
  final String           cityAr;
  final String           cityEn;
  final String           hijriDate;
  final double           qiblaAngle;

  const PrayerState({
    this.status     = PrayerStatus.initial,
    this.prayers    = const [],
    this.countdown  = Duration.zero,
    this.cityAr     = '',
    this.cityEn     = '',
    this.hijriDate  = '',
    this.qiblaAngle = 0.0,
  });

  bool get isLoading        => status == PrayerStatus.initial || status == PrayerStatus.loading;
  bool get isLoaded         => status == PrayerStatus.loaded;
  bool get hasError         => status == PrayerStatus.error ||
                               status == PrayerStatus.permissionDenied ||
                               status == PrayerStatus.serviceDisabled;
  bool get isPermissionError => status == PrayerStatus.permissionDenied ||
                                status == PrayerStatus.serviceDisabled;

  // The upcoming prayer (isNext flag)
  PrayerTime? get nextPrayer => prayers.where((p) => p.isNext).firstOrNull;

  // The most recently started prayer (last past isAdhan prayer)
  PrayerTime? get currentPrayer {
    PrayerTime? last;
    for (final p in prayers) {
      if (p.isPast && p.isAdhan) last = p;
    }
    return last;
  }

  PrayerState copyWith({
    PrayerStatus?     status,
    List<PrayerTime>? prayers,
    Duration?         countdown,
    String?           cityAr,
    String?           cityEn,
    String?           hijriDate,
    double?           qiblaAngle,
  }) =>
      PrayerState(
        status:     status     ?? this.status,
        prayers:    prayers    ?? this.prayers,
        countdown:  countdown  ?? this.countdown,
        cityAr:     cityAr     ?? this.cityAr,
        cityEn:     cityEn     ?? this.cityEn,
        hijriDate:  hijriDate  ?? this.hijriDate,
        qiblaAngle: qiblaAngle ?? this.qiblaAngle,
      );
}

// =============================================================================
// SECTION 4 — HIJRI DATE COMPUTATION  (Meeus algorithm, no external package)
// =============================================================================

String _computeHijriDate(DateTime g, {bool arabic = true}) {
  int y = g.year, m = g.month, d = g.day;
  if (m <= 2) { y--; m += 12; }
  final a  = y ~/ 100;
  final b  = 2 - a + a ~/ 4;
  final jd = (365.25 * (y + 4716)).floor() +
             (30.6001 * (m + 1)).floor() +
             d + b - 1524;

  final l  = jd - 1948440 + 10632;
  final n  = (l - 1) ~/ 10631;
  final l2 = l - 10631 * n + 354;
  final j  = ((10985 - l2) ~/ 5316) * ((50 * l2) ~/ 17719) +
             (l2 ~/ 5670) * ((43 * l2) ~/ 15238);
  final l3 = l2 -
             ((30 - j) ~/ 15) * ((17719 * j) ~/ 50) -
             (j ~/ 16) * ((15238 * j) ~/ 43) +
             29;
  final hM = (24 * l3) ~/ 709;
  final hD = l3 - (709 * hM) ~/ 24;
  final hY = 30 * n + j - 30;

  const ar = [
    'محرم', 'صفر', 'ربيع الأول', 'ربيع الثاني',
    'جمادى الأولى', 'جمادى الآخرة', 'رجب', 'شعبان',
    'رمضان', 'شوال', 'ذو القعدة', 'ذو الحجة',
  ];
  const en = [
    'Muharram', 'Safar', 'Rabi Al-Awwal', 'Rabi Al-Thani',
    'Jumada Al-Awwal', 'Jumada Al-Akhirah', 'Rajab', "Sha'ban",
    'Ramadan', 'Shawwal', "Dhul Qi'dah", 'Dhul Hijjah',
  ];

  final idx       = (hM - 1).clamp(0, 11);
  final monthName = arabic ? ar[idx] : en[idx];

  if (arabic) {
    String toAr(int v) => v
        .toString()
        .replaceAll('0', '٠').replaceAll('1', '١').replaceAll('2', '٢')
        .replaceAll('3', '٣').replaceAll('4', '٤').replaceAll('5', '٥')
        .replaceAll('6', '٦').replaceAll('7', '٧').replaceAll('8', '٨')
        .replaceAll('9', '٩');
    return '${toAr(hD)} $monthName ${toAr(hY)}';
  }
  return '$hD $monthName $hY';
}

String _bestPlacemarkLabel(geo.Placemark p) {
  if (p.locality?.isNotEmpty == true)              return p.locality!;
  if (p.subAdministrativeArea?.isNotEmpty == true) return p.subAdministrativeArea!;
  if (p.administrativeArea?.isNotEmpty == true)    return p.administrativeArea!;
  return '';
}

// =============================================================================
// SECTION 5 — CUBIT  (coords cached — timer never re-fetches GPS)
// =============================================================================

class PrayerCubit extends Cubit<PrayerState> {
  PrayerCubit() : super(const PrayerState()) {
    _init();
  }

  Timer?   _timer;
  double?  _lat;
  double?  _lng;
  String   _isoCode  = 'GB';
  String   _cityAr   = '';
  String   _cityEn   = '';
  DateTime? _calcDay; // date on which prayers were last calculated

  CalculationParameters _paramsForCountry(String iso) {
    switch (iso.toUpperCase()) {
      case 'SA': case 'YE': case 'JO': case 'SY':
        return CalculationMethod.umm_al_qura.getParameters();
      case 'US': case 'CA': case 'MX':
        return CalculationMethod.north_america.getParameters();
      case 'AE':
        return CalculationMethod.dubai.getParameters();
      case 'KW':
        return CalculationMethod.kuwait.getParameters();
      case 'QA':
        return CalculationMethod.qatar.getParameters();
      case 'EG':
        return CalculationMethod.egyptian.getParameters();
      case 'PK': case 'BD': case 'AF': case 'IN':
        return CalculationMethod.karachi.getParameters();
      case 'TR':
        return CalculationMethod.turkey.getParameters();
      case 'SG': case 'MY':
        return CalculationMethod.singapore.getParameters();
      default:
        return CalculationMethod.muslim_world_league.getParameters();
    }
  }

  // ── Full init: GPS fetch + geocode + calculate ──────────────────────────────
  Future<void> _init() async {
    _timer?.cancel();
    if (isClosed) return;
    emit(state.copyWith(status: PrayerStatus.loading));

    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (isClosed) return;
    if (!serviceEnabled) {
      emit(state.copyWith(status: PrayerStatus.serviceDisabled));
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
      emit(state.copyWith(status: PrayerStatus.permissionDenied));
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
      emit(state.copyWith(status: PrayerStatus.error));
      return;
    }
    if (isClosed) return;

    _lat = pos.latitude;
    _lng = pos.longitude;

    // 1. Local geocoding — fast on real devices, fails silently on web/simulators.
    try {
      final places = await geo.placemarkFromCoordinates(_lat!, _lng!);
      if (isClosed) return;
      if (places.isNotEmpty) {
        final p = places.first;
        _isoCode = p.isoCountryCode ?? 'GB';
        final label = _bestPlacemarkLabel(p);
        _cityEn = label;
        _cityAr = label;
      }
    } catch (_) {
      if (isClosed) return;
    }

    // 2. Nominatim fallback — fires when local geocoding returns empty
    //    (web, simulators, or devices without the geocoding service).
    //    Returns bilingual "City، Country" / "City, Country" labels.
    if (_cityEn.isEmpty) {
      final (:ar, :en) = await nominatimReverse(_lat!, _lng!);
      if (isClosed) return;
      if (ar.isNotEmpty) _cityAr = ar;
      if (en.isNotEmpty) _cityEn = en;
    }

    _recalculate();
    _startTimer();
  }

  // ── Fast recalculate using cached coords (no GPS, no loading flash) ─────────
  void _recalculate() {
    if (_lat == null || _lng == null || isClosed) return;

    final now    = DateTime.now();
    final coords = Coordinates(_lat!, _lng!);
    final params = _paramsForCountry(_isoCode);
    final pt     = PrayerTimes(coords, DateComponents.from(now), params);
    final qibla  = Qibla(coords).direction;
    final hijri  = _computeHijriDate(now);
    final prayers = _buildPrayers(pt);
    _calcDay = DateTime(now.year, now.month, now.day);

    final next = prayers.where((p) => p.isNext).firstOrNull;

    emit(PrayerState(
      status:     PrayerStatus.loaded,
      prayers:    prayers,
      countdown:  next != null ? _remaining(next) : Duration.zero,
      cityAr:     _cityAr,
      cityEn:     _cityEn,
      hijriDate:  hijri,
      qiblaAngle: qibla,
    ));
  }

  List<PrayerTime> _buildPrayers(PrayerTimes pt) {
    final now = DateTime.now();
    final raw = [
      (PrayerName.fajr,    pt.fajr.toLocal(),    true),
      (PrayerName.sunrise, pt.sunrise.toLocal(),  false),
      (PrayerName.dhuhr,   pt.dhuhr.toLocal(),    true),
      (PrayerName.asr,     pt.asr.toLocal(),      true),
      (PrayerName.maghrib, pt.maghrib.toLocal(),  true),
      (PrayerName.isha,    pt.isha.toLocal(),     true),
    ];

    bool foundNext = false;
    return raw.map((t) {
      final isPast = t.$2.isBefore(now);
      final isNext = !foundNext && !isPast && t.$3;
      if (isNext) foundNext = true;
      return PrayerTime(
        name: t.$1, dateTime: t.$2,
        isNext: isNext, isPast: isPast, isAdhan: t.$3,
      );
    }).toList();
  }

  Duration _remaining(PrayerTime p) {
    final diff = p.dateTime.difference(DateTime.now());
    return diff.isNegative ? Duration.zero : diff;
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (isClosed || !state.isLoaded) return;

      final now   = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      // New calendar day → recalculate for today's prayer schedule
      if (_calcDay != null && today.isAfter(_calcDay!)) {
        _recalculate();
        return;
      }

      final next = state.nextPrayer;

      // All prayers done for today — keep countdown at zero, nothing to do
      if (next == null) return;

      final rem = next.dateTime.difference(now);
      if (rem.isNegative) {
        // This prayer just passed — recalculate to pick the new next prayer
        // (uses cached coords, no GPS fetch, no loading state)
        _recalculate();
        return;
      }

      emit(state.copyWith(countdown: rem));
    });
  }

  void refresh() => _init();

  @override
  Future<void> close() async {
    _timer?.cancel();
    return super.close();
  }
}

// =============================================================================
// SECTION 6 — HELPERS
// =============================================================================

String _fmtDuration(Duration d) {
  if (d <= Duration.zero) return '00:00:00';
  final h = d.inHours.toString().padLeft(2, '0');
  final m = (d.inMinutes % 60).toString().padLeft(2, '0');
  final s = (d.inSeconds % 60).toString().padLeft(2, '0');
  return '$h:$m:$s';
}

// =============================================================================
// SECTION 7 — NEXT PRAYER HERO CARD  (premium gradient design)
// =============================================================================

class _NextPrayerHero extends StatelessWidget {
  final PrayerTime? nextPrayer;    // null = all prayers done for the day
  final PrayerTime? currentPrayer; // null = before Fajr
  final Duration    countdown;
  final String      cityLabel;

  const _NextPrayerHero({
    required this.nextPrayer,
    required this.currentPrayer,
    required this.countdown,
    required this.cityLabel,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primaryDark,
            AppColors.primary,
            AppColors.primaryLight,
          ],
          stops: [0.0, 0.55, 1.0],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: AppColors.secondary.withValues(alpha: 0.28),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color:      AppColors.primaryDark.withValues(alpha: 0.35),
            blurRadius: 24,
            offset:     const Offset(0, 10),
          ),
          BoxShadow(
            color:       AppColors.secondary.withValues(alpha: 0.08),
            blurRadius:  40,
            spreadRadius: 2,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            // Decorative gold orb — top right
            Positioned(
              top: -40, right: -30,
              child: Container(
                width: 120, height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.secondary.withValues(alpha: 0.10),
                ),
              ),
            ),
            // Decorative white orb — bottom left
            Positioned(
              bottom: -25, left: -20,
              child: Container(
                width: 90, height: 90,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.white.withValues(alpha: 0.05),
                ),
              ),
            ),

            // ── Content ──────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  // Row: current-prayer badge  +  city pin
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Current prayer badge
                      if (currentPrayer != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.secondary.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: AppColors.secondary.withValues(alpha: 0.40),
                              width: 1.0,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                currentPrayer!.name.icon,
                                color: AppColors.secondary, size: 13,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                currentPrayer!.name.label(l10n),
                                style: const TextStyle(
                                  fontFamily: 'Cairo', fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.secondary,
                                ),
                              ),
                            ],
                          ),
                        ),

                      const Spacer(),

                      // City label
                      if (cityLabel.isNotEmpty)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              LucideIcons.mapPin,
                              color: AppColors.white.withValues(alpha: 0.55),
                              size: 12,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              cityLabel,
                              style: TextStyle(
                                fontFamily: 'Tajawal', fontSize: 12,
                                color: AppColors.white.withValues(alpha: 0.60),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),

                  const SizedBox(height: 16),
                  Divider(color: AppColors.white.withValues(alpha: 0.10)),
                  const SizedBox(height: 14),

                  // Next prayer label
                  Text(
                    l10n.nextPrayer,
                    style: TextStyle(
                      fontFamily: 'Tajawal', fontSize: 12,
                      color: AppColors.white.withValues(alpha: 0.55),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Prayer name + time row
                  if (nextPrayer != null)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Icon(
                          nextPrayer!.name.icon,
                          color: AppColors.secondary, size: 22,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          nextPrayer!.name.label(l10n),
                          style: const TextStyle(
                            fontFamily: 'Cairo', fontSize: 24,
                            fontWeight: FontWeight.w800, color: AppColors.white,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          nextPrayer!.formatted(l10n: l10n),
                          style: TextStyle(
                            fontFamily: 'Tajawal', fontSize: 15,
                            color: AppColors.white.withValues(alpha: 0.80),
                          ),
                        ),
                      ],
                    )
                  else
                    Text(
                      l10n.prayersComplete,
                      style: TextStyle(
                        fontFamily: 'Cairo', fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppColors.white.withValues(alpha: 0.75),
                      ),
                    ),

                  const SizedBox(height: 20),

                  // Countdown
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          l10n.timeRemaining,
                          style: TextStyle(
                            fontFamily: 'Tajawal', fontSize: 11,
                            color: AppColors.white.withValues(alpha: 0.50),
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _fmtDuration(countdown),
                          style: const TextStyle(
                            fontFamily:    'Cairo', fontSize: 36,
                            fontWeight:    FontWeight.w800,
                            color:         AppColors.white,
                            letterSpacing: 4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// SECTION 8 — PRAYER ROW CARD
// =============================================================================

class _PrayerCard extends StatelessWidget {
  final PrayerTime prayer;
  const _PrayerCard({required this.prayer});

  @override
  Widget build(BuildContext context) {
    final l10n   = AppLocalizations.of(context)!;
    final isNext = prayer.isNext;
    final isPast = prayer.isPast && !isNext;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 280),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color:        AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isNext ? AppColors.secondary : AppColors.cardBorder,
          width: isNext ? 1.8 : 1.2,
        ),
        boxShadow: isNext
            ? [
                BoxShadow(
                  color:      AppColors.secondary.withValues(alpha: 0.18),
                  blurRadius: 14,
                  offset:     const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Row(
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: isNext
                  ? AppColors.secondary.withValues(alpha: 0.12)
                  : isPast
                      ? AppColors.cardBorder.withValues(alpha: 0.40)
                      : AppColors.primary.withValues(alpha: 0.09),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              prayer.name.icon, size: 20,
              color: isPast
                  ? AppColors.textSecondary
                  : isNext ? AppColors.secondary : AppColors.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              prayer.name.label(l10n),
              textAlign: TextAlign.start,
              style: TextStyle(
                fontFamily: 'Cairo', fontSize: 16,
                fontWeight: isNext ? FontWeight.w800 : FontWeight.w700,
                color: isPast ? AppColors.textSecondary : AppColors.darkText,
              ),
            ),
          ),
          Text(
            prayer.formatted(l10n: l10n),
            style: TextStyle(
              fontFamily: 'Tajawal', fontSize: 15, fontWeight: FontWeight.w600,
              color: isPast
                  ? AppColors.textSecondary
                  : isNext ? AppColors.secondary : AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// SECTION 9 — QIBLA ACCESS CARD
// =============================================================================

class _QiblaAccessCard extends StatelessWidget {
  const _QiblaAccessCard();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return GestureDetector(
      onTap: () => context.push('/qibla'),
      child: Container(
        width:   double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        decoration: BoxDecoration(
          color:        AppColors.primary,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color:      AppColors.primary.withValues(alpha: 0.30),
              blurRadius: 20,
              offset:     const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 52, height: 52,
              decoration: BoxDecoration(
                color:        AppColors.secondary.withValues(alpha: 0.22),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppColors.secondary.withValues(alpha: 0.40), width: 1.5,
                ),
              ),
              child: const Icon(
                LucideIcons.compass, color: AppColors.secondary, size: 28,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    l10n.qiblaDirection,
                    style: const TextStyle(
                      fontFamily: 'Cairo', fontSize: 18,
                      fontWeight: FontWeight.w800, color: AppColors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l10n.knowKaabaDirection,
                    style: TextStyle(
                      fontFamily: 'Tajawal', fontSize: 13,
                      color: AppColors.white.withValues(alpha: 0.75),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color:        AppColors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Directionality.of(context) == TextDirection.rtl
                    ? LucideIcons.chevronLeft
                    : LucideIcons.chevronRight,
                color: AppColors.white, size: 20,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// SECTION 10 — DATE ROW
// =============================================================================

class _DateRow extends StatelessWidget {
  final String cityAr;
  final String cityEn;
  final String hijri;
  const _DateRow({required this.cityAr, required this.cityEn, required this.hijri});

  @override
  Widget build(BuildContext context) {
    final lang  = Localizations.localeOf(context).languageCode;
    final city  = lang == 'ar'
        ? (cityAr.isNotEmpty ? cityAr : '—')
        : (cityEn.isNotEmpty ? cityEn : '—');
    final dateStr = lang == 'ar'
        ? (hijri.isNotEmpty ? hijri : _gregorianFallback())
        : _gregorianFallback();

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              city,
              style: const TextStyle(
                fontFamily: 'Cairo', fontSize: 15,
                fontWeight: FontWeight.w700, color: AppColors.darkText,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                color:        AppColors.primary.withValues(alpha: 0.09),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(LucideIcons.mapPin, color: AppColors.primary, size: 16),
            ),
          ],
        ),
        Text(
          dateStr,
          style: const TextStyle(
            fontFamily: 'Tajawal', fontSize: 13, color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  static String _gregorianFallback() {
    final t = DateTime.now();
    return '${t.day}/${t.month}/${t.year}';
  }
}

// =============================================================================
// SECTION 11 — STATIC QIBLA BEARING PREVIEW
// =============================================================================

class _StaticQiblaPreview extends StatelessWidget {
  final double qiblaAngle;
  const _StaticQiblaPreview({required this.qiblaAngle});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color:        AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.cardBorder, width: 1.2),
        boxShadow: [
          BoxShadow(
            color:      AppColors.primary.withValues(alpha: 0.05),
            blurRadius: 10, offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🕋', style: TextStyle(fontSize: 28)),
              const SizedBox(height: 4),
              Text(
                l10n.kaabaDirection,
                style: const TextStyle(
                  fontFamily: 'Cairo', fontSize: 13,
                  fontWeight: FontWeight.w700, color: AppColors.darkText,
                ),
              ),
            ],
          ),
          const Spacer(),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${qiblaAngle.toStringAsFixed(1)}°',
                style: const TextStyle(
                  fontFamily: 'Cairo', fontSize: 22,
                  fontWeight: FontWeight.w800, color: AppColors.secondary,
                ),
              ),
              Text(
                l10n.fromNorth,
                style: const TextStyle(
                  fontFamily: 'Tajawal', fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// SECTION 12 — ERROR STATE VIEW
// =============================================================================

class _ErrorStateView extends StatelessWidget {
  final PrayerState state;
  final VoidCallback onRetry;

  const _ErrorStateView({required this.state, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final l10n   = AppLocalizations.of(context)!;
    final isPerm = state.isPermissionError;

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
                isPerm ? LucideIcons.mapPinOff : LucideIcons.wifiOff,
                size: 36, color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              isPerm ? l10n.locationPermissionMsg : l10n.locationError,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Tajawal', fontSize: 14,
                color: AppColors.textSecondary, height: 1.6,
              ),
            ),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: isPerm ? () => Geolocator.openAppSettings() : onRetry,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 13),
                decoration: BoxDecoration(
                  color:        AppColors.primary,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Text(
                  isPerm ? l10n.openSettings : l10n.tryAgain,
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
// SECTION 13 — PRAYER TIMES PAGE
// =============================================================================

class PrayerTimesPage extends StatefulWidget {
  const PrayerTimesPage({super.key});

  @override
  State<PrayerTimesPage> createState() => _PrayerTimesPageState();
}

class _PrayerTimesPageState extends State<PrayerTimesPage> {
  late final PrayerCubit _cubit;

  @override
  void initState() {
    super.initState();
    _cubit = PrayerCubit();
  }

  @override
  void dispose() {
    _cubit.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _cubit,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: BlocBuilder<PrayerCubit, PrayerState>(
          builder: (context, state) {
            final l10n = AppLocalizations.of(context)!;
            final lang = Localizations.localeOf(context).languageCode;

            final header = SharedHeader(
              title: l10n.prayerTimesTitle,
              trailing: [
                GestureDetector(
                  onTap: _cubit.refresh,
                  child: Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      color:        AppColors.primary.withValues(alpha: 0.09),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      LucideIcons.refreshCw, color: AppColors.primary, size: 18,
                    ),
                  ),
                ),
              ],
            );

            // ── Loading ────────────────────────────────────────────────────
            if (state.isLoading) {
              return SafeArea(
                bottom: false,
                child: Column(
                  children: [
                    header,
                    const SizedBox(height: 12),
                    Expanded(
                      child: Center(
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
                      ),
                    ),
                  ],
                ),
              );
            }

            // ── Error ──────────────────────────────────────────────────────
            if (state.hasError) {
              return SafeArea(
                bottom: false,
                child: Column(
                  children: [
                    header,
                    Expanded(
                      child: _ErrorStateView(
                        state:   state,
                        onRetry: _cubit.refresh,
                      ),
                    ),
                  ],
                ),
              );
            }

            // ── Loaded ─────────────────────────────────────────────────────
            final cityLabel = lang == 'ar'
                ? (state.cityAr.isNotEmpty ? state.cityAr : state.cityEn)
                : (state.cityEn.isNotEmpty ? state.cityEn : state.cityAr);

            return SafeArea(
              bottom: false,
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    header,
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _DateRow(
                            cityAr: state.cityAr,
                            cityEn: state.cityEn,
                            hijri:  state.hijriDate,
                          ),
                          const SizedBox(height: 18),

                          // Premium countdown hero card (always shown when loaded)
                          _NextPrayerHero(
                            nextPrayer:    state.nextPrayer,
                            currentPrayer: state.currentPrayer,
                            countdown:     state.countdown,
                            cityLabel:     cityLabel,
                          ),
                          const SizedBox(height: 24),

                          Text(
                            l10n.prayerTimesTitle,
                            textAlign: TextAlign.start,
                            style: const TextStyle(
                              fontFamily: 'Cairo', fontSize: 18,
                              fontWeight: FontWeight.w800, color: AppColors.darkText,
                            ),
                          ),
                          const SizedBox(height: 12),

                          ...state.prayers.map(
                            (p) => Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _PrayerCard(prayer: p),
                            ),
                          ),

                          const SizedBox(height: 24),

                          const _QiblaAccessCard(),
                          const SizedBox(height: 16),

                          _StaticQiblaPreview(qiblaAngle: state.qiblaAngle),

                          SizedBox(
                            height: MediaQuery.of(context).padding.bottom + 40,
                          ),
                        ],
                      ),
                    ),
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

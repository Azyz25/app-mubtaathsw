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
import 'package:mubtaath/core/services/location_cache_service.dart';
import 'package:mubtaath/core/services/prayer_notification_service.dart';
import 'package:mubtaath/core/utils/nominatim_geocoder.dart';
import 'package:mubtaath/core/theme/app_colors.dart';
import 'package:mubtaath/core/widgets/mubtaath_refresh.dart';
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
  final DateTime?        ishaYesterday;     // yesterday's Isha adhan
  final DateTime?        yesterdayMidnight; // Islamic midnight — end of yesterday's Isha window
  final DateTime?        todayMidnight;     // Islamic midnight — end of tonight's Isha window
  final DateTime?        tomorrowFajr;      // countdown target once today's Isha window has closed

  const PrayerState({
    this.status        = PrayerStatus.initial,
    this.prayers       = const [],
    this.countdown     = Duration.zero,
    this.cityAr        = '',
    this.cityEn        = '',
    this.hijriDate     = '',
    this.qiblaAngle    = 0.0,
    this.ishaYesterday,
    this.yesterdayMidnight,
    this.todayMidnight,
    this.tomorrowFajr,
  });

  bool get isLoading        => status == PrayerStatus.initial || status == PrayerStatus.loading;
  bool get isLoaded         => status == PrayerStatus.loaded;
  bool get hasError         => status == PrayerStatus.error ||
                               status == PrayerStatus.permissionDenied ||
                               status == PrayerStatus.serviceDisabled;
  bool get isPermissionError => status == PrayerStatus.permissionDenied ||
                                status == PrayerStatus.serviceDisabled;

  // The upcoming prayer (isNext flag) — null once Isha has passed for today.
  PrayerTime? get nextPrayer => prayers.where((p) => p.isNext).firstOrNull;

  // Same, but falls back to tomorrow's Fajr overnight (after Isha, before the
  // next day's prayers are computed) so the countdown UI always has a target.
  PrayerTime? get effectiveNextPrayer {
    final next = nextPrayer;
    if (next != null) return next;
    final fajr = tomorrowFajr;
    if (fajr == null) return null;
    return PrayerTime(name: PrayerName.fajr, dateTime: fajr, isNext: true);
  }

  PrayerTime? _byName(PrayerName n) => prayers.where((p) => p.name == n).firstOrNull;

  // A prayer's display is only shown as "elapsed since adhan" for up to this
  // long — after that (or once the window itself ends, whichever is sooner)
  // the hero switches to counting down to the next prayer instead. Adapts
  // automatically to short gaps (e.g. Maghrib→Isha in some countries can be
  // well under 45 min) since it's capped by the real window length too.
  static const int _elapsedCapMinutes = 45;

  /// Which prayer's Shar'i time window `now` currently falls in, per the
  /// standard fiqh boundaries:
  ///   Fajr    → ends at sunrise
  ///   Dhuhr   → ends when Asr begins (shadow = object length)
  ///   Asr     → ends at Maghrib (sunset)
  ///   Maghrib → ends when Isha begins (the red twilight disappearing)
  ///   Isha    → ends at Islamic midnight (midpoint of Maghrib→Fajr), not the
  ///             next Fajr — after midnight there is no "current" prayer.
  /// Returns `prayer: null` both during the sunrise→dhuhr gap and once a
  /// window's on-screen display has run past its (capped) duration — either
  /// way the hero falls back to a countdown to [effectiveNextPrayer].
  ({PrayerName? prayer, DateTime? since}) get activeWindow {
    final fajr    = _byName(PrayerName.fajr);
    final sunrise = _byName(PrayerName.sunrise);
    final dhuhr   = _byName(PrayerName.dhuhr);
    final asr     = _byName(PrayerName.asr);
    final maghrib = _byName(PrayerName.maghrib);
    final isha    = _byName(PrayerName.isha);
    if (fajr == null || sunrise == null || dhuhr == null ||
        asr == null || maghrib == null || isha == null) {
      return (prayer: null, since: null);
    }

    final now = DateTime.now();
    PrayerName name;
    DateTime start;
    DateTime windowEnd;

    if (now.isBefore(fajr.dateTime)) {
      name      = PrayerName.isha;
      start     = ishaYesterday ?? isha.dateTime;
      windowEnd = yesterdayMidnight ?? fajr.dateTime;
    } else if (now.isBefore(sunrise.dateTime)) {
      name = PrayerName.fajr; start = fajr.dateTime; windowEnd = sunrise.dateTime;
    } else if (now.isBefore(dhuhr.dateTime)) {
      return (prayer: null, since: null); // sunrise→dhuhr gap
    } else if (now.isBefore(asr.dateTime)) {
      name = PrayerName.dhuhr; start = dhuhr.dateTime; windowEnd = asr.dateTime;
    } else if (now.isBefore(maghrib.dateTime)) {
      name = PrayerName.asr; start = asr.dateTime; windowEnd = maghrib.dateTime;
    } else if (now.isBefore(isha.dateTime)) {
      name = PrayerName.maghrib; start = maghrib.dateTime; windowEnd = isha.dateTime;
    } else {
      name      = PrayerName.isha;
      start     = isha.dateTime;
      windowEnd = todayMidnight ?? isha.dateTime;
    }

    final capMinutes = windowEnd.difference(start).inMinutes.clamp(0, _elapsedCapMinutes);
    if (now.isBefore(start.add(Duration(minutes: capMinutes)))) {
      return (prayer: name, since: start);
    }
    return (prayer: null, since: null); // past the on-screen cap → countdown mode
  }

  PrayerState copyWith({
    PrayerStatus?     status,
    List<PrayerTime>? prayers,
    Duration?         countdown,
    String?           cityAr,
    String?           cityEn,
    String?           hijriDate,
    double?           qiblaAngle,
    DateTime?         ishaYesterday,
    DateTime?         yesterdayMidnight,
    DateTime?         todayMidnight,
    DateTime?         tomorrowFajr,
  }) =>
      PrayerState(
        status:            status            ?? this.status,
        prayers:           prayers           ?? this.prayers,
        countdown:         countdown         ?? this.countdown,
        cityAr:            cityAr            ?? this.cityAr,
        cityEn:            cityEn            ?? this.cityEn,
        hijriDate:         hijriDate         ?? this.hijriDate,
        qiblaAngle:        qiblaAngle        ?? this.qiblaAngle,
        ishaYesterday:     ishaYesterday     ?? this.ishaYesterday,
        yesterdayMidnight: yesterdayMidnight ?? this.yesterdayMidnight,
        todayMidnight:     todayMidnight     ?? this.todayMidnight,
        tomorrowFajr:      tomorrowFajr      ?? this.tomorrowFajr,
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
    final code = iso.toUpperCase();

    // Official calculation authority per country → matches the local mosques.
    final CalculationParameters params;
    switch (code) {
      case 'SA': case 'YE': case 'JO': case 'SY':
        params = CalculationMethod.umm_al_qura.getParameters();
      case 'US': case 'CA': case 'MX':
        params = CalculationMethod.north_america.getParameters();
      case 'AE':
        params = CalculationMethod.dubai.getParameters();
      case 'KW':
        params = CalculationMethod.kuwait.getParameters();
      case 'QA':
        params = CalculationMethod.qatar.getParameters();
      case 'EG':
        params = CalculationMethod.egyptian.getParameters();
      case 'PK': case 'BD': case 'AF': case 'IN':
        params = CalculationMethod.karachi.getParameters();
      case 'TR':
        params = CalculationMethod.turkey.getParameters();
      case 'SG': case 'MY':
        params = CalculationMethod.singapore.getParameters();
      default:
        params = CalculationMethod.muslim_world_league.getParameters();
    }

    // Madhab governs the Asr calculation — Hanafi in South-Asian regions,
    // Shafi (the standard) everywhere else.
    params.madhab = switch (code) {
      'PK' || 'BD' || 'AF' || 'IN' => Madhab.hanafi,
      _                            => Madhab.shafi,
    };
    return params;
  }

  // ── Init: instant from cache when available, GPS only the first time ───────
  // Opening the page should never make the user wait on GPS+geocoding again
  // once a location has been fetched once. If a cached fix exists, show it
  // immediately and silently check for a real move in the background; only
  // a cold start (no cache yet) or the manual refresh button does a full,
  // loading-spinner GPS fetch.
  Future<void> _init() async {
    _timer?.cancel();
    if (isClosed) return;

    final cached = await LocationCacheService.instance.read();
    if (isClosed) return;

    if (cached != null) {
      _lat     = cached.lat;
      _lng     = cached.lng;
      _isoCode = cached.isoCode;
      _cityAr  = cached.cityAr;
      _cityEn  = cached.cityEn;
      _recalculate();
      _startTimer();
      unawaited(_refreshLocationInBackground());
      return;
    }

    emit(state.copyWith(status: PrayerStatus.loading));
    final ok = await _fetchAndCacheLocation();
    if (!ok || isClosed) return;
    _recalculate();
    _startTimer();
  }

  // ── Full GPS fetch + geocode + cache write. Mutates _lat/_lng/_isoCode/
  //    _cityAr/_cityEn on success. Returns false if it already emitted an
  //    error/permission state (caller should stop there). ───────────────────
  Future<bool> _fetchAndCacheLocation() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (isClosed) return false;
    if (!serviceEnabled) {
      emit(state.copyWith(status: PrayerStatus.serviceDisabled));
      return false;
    }

    LocationPermission perm = await Geolocator.checkPermission();
    if (isClosed) return false;
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
      if (isClosed) return false;
    }
    if (perm == LocationPermission.denied ||
        perm == LocationPermission.deniedForever) {
      emit(state.copyWith(status: PrayerStatus.permissionDenied));
      return false;
    }

    Position pos;
    try {
      // .best requests the highest-precision GPS fix the device can deliver
      // (as opposed to a coarser network/Wi-Fi-assisted fix) — prayer times
      // are computed from these exact coordinates, not a city lookup.
      pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
        timeLimit: const Duration(seconds: 20),
      );
    } catch (_) {
      if (isClosed) return false;
      emit(state.copyWith(status: PrayerStatus.error));
      return false;
    }
    if (isClosed) return false;

    _lat = pos.latitude;
    _lng = pos.longitude;

    // 1. Local geocoding — fast on real devices, fails silently on web/simulators.
    try {
      final places = await geo.placemarkFromCoordinates(_lat!, _lng!);
      if (isClosed) return false;
      if (places.isNotEmpty) {
        final p = places.first;
        _isoCode = p.isoCountryCode ?? 'GB';
        final label = _bestPlacemarkLabel(p);
        _cityEn = label;
        _cityAr = label;
      }
    } catch (_) {
      if (isClosed) return false;
    }

    // 2. Nominatim fallback — fires when local geocoding returns empty
    //    (web, simulators, or devices without the geocoding service).
    //    Returns bilingual "City، Country" / "City, Country" labels.
    if (_cityEn.isEmpty) {
      final (:ar, :en) = await nominatimReverse(_lat!, _lng!);
      if (isClosed) return false;
      if (ar.isNotEmpty) _cityAr = ar;
      if (en.isNotEmpty) _cityEn = en;
    }
    if (isClosed) return false;

    await LocationCacheService.instance.write(CachedLocation(
      lat: _lat!, lng: _lng!, isoCode: _isoCode, cityAr: _cityAr, cityEn: _cityEn,
    ));
    return true;
  }

  // ── Silent background check — only touches the UI if the device has
  //    actually moved a meaningful distance since the cached fix. ───────────
  Future<void> _refreshLocationInBackground() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled || isClosed) return;

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

      _lat = pos.latitude;
      _lng = pos.longitude;
      _cityAr = '';
      _cityEn = '';

      try {
        final places = await geo.placemarkFromCoordinates(_lat!, _lng!);
        if (isClosed) return;
        if (places.isNotEmpty) {
          final p = places.first;
          _isoCode = p.isoCountryCode ?? _isoCode;
          final label = _bestPlacemarkLabel(p);
          _cityEn = label;
          _cityAr = label;
        }
      } catch (_) {
        if (isClosed) return;
      }
      if (_cityEn.isEmpty) {
        final (:ar, :en) = await nominatimReverse(_lat!, _lng!);
        if (isClosed) return;
        if (ar.isNotEmpty) _cityAr = ar;
        if (en.isNotEmpty) _cityEn = en;
      }
      if (isClosed) return;

      await LocationCacheService.instance.write(CachedLocation(
        lat: _lat!, lng: _lng!, isoCode: _isoCode, cityAr: _cityAr, cityEn: _cityEn,
      ));
      _recalculate();
    } catch (_) {
      // Silent — the cached data already on screen remains valid either way.
    }
  }

  // ── Fast recalculate using cached coords (no GPS, no loading flash) ─────────
  void _recalculate() {
    if (_lat == null || _lng == null || isClosed) return;

    final now    = DateTime.now();
    final coords = Coordinates(_lat!, _lng!);
    final params = _paramsForCountry(_isoCode);

    // Far from the equator the sun may not reach the twilight angle, which
    // distorts Fajr/Isha. The seventh-of-the-night rule keeps them realistic.
    if (_lat!.abs() >= 48) {
      params.highLatitudeRule = HighLatitudeRule.seventh_of_the_night;
    }

    final pt     = PrayerTimes(coords, DateComponents.from(now), params);
    final qibla  = Qibla(coords).direction;
    final hijri  = _computeHijriDate(now);
    final prayers = _buildPrayers(pt);
    _calcDay = DateTime(now.year, now.month, now.day);

    // Islamic "midnight" — the fiqh-correct end of Isha's window — is the
    // midpoint between Maghrib and the FOLLOWING Fajr, not clock midnight and
    // not "whenever tomorrow's Fajr happens to be". Need yesterday's and
    // tomorrow's prayer times (pure math from cached coords — no GPS) to
    // bound both the overnight (pre-Fajr) and tonight's Isha windows.
    final yesterday   = DateTime(now.year, now.month, now.day - 1);
    final tomorrow    = DateTime(now.year, now.month, now.day + 1);
    final ptYesterday = PrayerTimes(coords, DateComponents.from(yesterday), params);
    final ptTomorrow  = PrayerTimes(coords, DateComponents.from(tomorrow), params);

    final ishaYesterday    = ptYesterday.isha.toLocal();
    final maghribYesterday = ptYesterday.maghrib.toLocal();
    final maghribToday     = pt.maghrib.toLocal();
    final fajrToday        = pt.fajr.toLocal();
    final fajrTomorrow     = ptTomorrow.fajr.toLocal();

    DateTime midpoint(DateTime a, DateTime b) =>
        a.add(Duration(milliseconds: b.difference(a).inMilliseconds ~/ 2));

    final yesterdayMidnight = midpoint(maghribYesterday, fajrToday);
    final todayMidnight     = midpoint(maghribToday, fajrTomorrow);

    final next = prayers.where((p) => p.isNext).firstOrNull;
    final effectiveNext = next ?? PrayerTime(name: PrayerName.fajr, dateTime: fajrTomorrow, isNext: true);

    emit(PrayerState(
      status:            PrayerStatus.loaded,
      prayers:           prayers,
      countdown:         _remaining(effectiveNext),
      cityAr:            _cityAr,
      cityEn:            _cityEn,
      hijriDate:         hijri,
      qiblaAngle:        qibla,
      ishaYesterday:     ishaYesterday,
      yesterdayMidnight: yesterdayMidnight,
      todayMidnight:     todayMidnight,
      tomorrowFajr:      fajrTomorrow,
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

  /// Future adhan-prayer instants for the next [days] days — used to schedule
  /// notifications ahead of time. Empty until GPS coords are known. Sunrise is
  /// excluded (it is not a prayer to be notified about).
  List<({PrayerName name, DateTime at})> upcomingPrayerInstants({int days = 5}) {
    if (_lat == null || _lng == null) return const [];

    final coords = Coordinates(_lat!, _lng!);
    final params = _paramsForCountry(_isoCode);
    if (_lat!.abs() >= 48) {
      params.highLatitudeRule = HighLatitudeRule.seventh_of_the_night;
    }

    final now = DateTime.now();
    final out = <({PrayerName name, DateTime at})>[];
    for (var d = 0; d < days; d++) {
      final day = DateTime(now.year, now.month, now.day + d);
      final pt  = PrayerTimes(coords, DateComponents.from(day), params);
      final slots = <(PrayerName, DateTime)>[
        (PrayerName.fajr,    pt.fajr.toLocal()),
        (PrayerName.dhuhr,   pt.dhuhr.toLocal()),
        (PrayerName.asr,     pt.asr.toLocal()),
        (PrayerName.maghrib, pt.maghrib.toLocal()),
        (PrayerName.isha,    pt.isha.toLocal()),
      ];
      for (final s in slots) {
        if (s.$2.isAfter(now)) out.add((name: s.$1, at: s.$2));
      }
    }
    return out;
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

      // effectiveNextPrayer falls back to tomorrow's Fajr once today's Isha
      // has passed, so the countdown keeps counting down through the night
      // instead of freezing at zero once nothing is left "today".
      final next = state.effectiveNextPrayer;
      if (next == null) {
        emit(state.copyWith(countdown: Duration.zero));
        return;
      }

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

  // Manual refresh (tap the toolbar icon) always forces a real GPS fetch —
  // unlike _init(), it deliberately bypasses the cache.
  Future<void> refresh() async {
    _timer?.cancel();
    if (isClosed) return;
    emit(state.copyWith(status: PrayerStatus.loading));
    final ok = await _fetchAndCacheLocation();
    if (!ok || isClosed) return;
    _recalculate();
    _startTimer();
  }

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
  final PrayerTime? nextPrayer; // used only in the gap (sunrise→dhuhr) state
  final ({PrayerName? prayer, DateTime? since}) activeWindow;
  final Duration    countdown;
  final String      cityLabel;

  const _NextPrayerHero({
    required this.nextPrayer,
    required this.activeWindow,
    required this.countdown,
    required this.cityLabel,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    final activePrayer = activeWindow.prayer;
    final since         = activeWindow.since;
    final elapsed = since != null
        ? DateTime.now().difference(since)
        : Duration.zero;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin:  Alignment.topRight,
          end:    Alignment.bottomLeft,
          colors: [AppColors.primaryDark, AppColors.primary],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color:      AppColors.primary.withValues(alpha: 0.30),
            blurRadius: 20,
            offset:     const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // City
          if (cityLabel.isNotEmpty)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(LucideIcons.mapPin,
                    color: AppColors.white.withValues(alpha: 0.75), size: 13),
                const SizedBox(width: 5),
                Text(
                  cityLabel,
                  style: TextStyle(
                    fontFamily: 'Tajawal', fontSize: 13,
                    color: AppColors.white.withValues(alpha: 0.75),
                  ),
                ),
              ],
            ),
          const SizedBox(height: 18),

          if (activePrayer != null) ...[
            // ── Inside a prayer's Shar'i window: count UP since its adhan ──
            Row(
              children: [
                Icon(activePrayer.icon, color: AppColors.accent, size: 24),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    l10n.elapsedSincePrayer(activePrayer.label(l10n)),
                    style: const TextStyle(
                      fontFamily: 'Cairo', fontSize: 20,
                      fontWeight: FontWeight.w800, color: AppColors.white,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            Center(
              child: Text(
                _fmtDuration(elapsed),
                style: const TextStyle(
                  fontFamily: 'Cairo', fontSize: 38,
                  fontWeight: FontWeight.w800, color: AppColors.white,
                  letterSpacing: 3,
                ),
              ),
            ),
          ] else ...[
            // ── Gap between Fajr's window and Dhuhr: countdown to Dhuhr ──
            Text(
              l10n.nextPrayer,
              style: TextStyle(
                fontFamily: 'Tajawal', fontSize: 12.5,
                color: AppColors.white.withValues(alpha: 0.65),
              ),
            ),
            const SizedBox(height: 8),
            if (nextPrayer != null)
              Row(
                children: [
                  Icon(nextPrayer!.name.icon, color: AppColors.accent, size: 24),
                  const SizedBox(width: 10),
                  Text(
                    nextPrayer!.name.label(l10n),
                    style: const TextStyle(
                      fontFamily: 'Cairo', fontSize: 26,
                      fontWeight: FontWeight.w800, color: AppColors.white,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    nextPrayer!.formatted(l10n: l10n),
                    style: TextStyle(
                      fontFamily: 'Tajawal', fontSize: 16, fontWeight: FontWeight.w600,
                      color: AppColors.white.withValues(alpha: 0.85),
                    ),
                  ),
                ],
              )
            else
              Text(
                l10n.prayersComplete,
                style: TextStyle(
                  fontFamily: 'Cairo', fontSize: 20, fontWeight: FontWeight.w700,
                  color: AppColors.white.withValues(alpha: 0.80),
                ),
              ),
            if (nextPrayer != null) ...[
              const SizedBox(height: 22),
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      l10n.timeRemaining,
                      style: TextStyle(
                        fontFamily: 'Tajawal', fontSize: 11,
                        color: AppColors.white.withValues(alpha: 0.55),
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _fmtDuration(countdown),
                      style: const TextStyle(
                        fontFamily: 'Cairo', fontSize: 38,
                        fontWeight: FontWeight.w800, color: AppColors.white,
                        letterSpacing: 3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ],
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
                color:        AppColors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                LucideIcons.compass, color: AppColors.primary, size: 28,
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
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                color:        AppColors.primary.withValues(alpha: 0.09),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(LucideIcons.mapPin, color: AppColors.primary, size: 16),
            ),
            const SizedBox(width: 6),
            Text(
              city,
              style: const TextStyle(
                fontFamily: 'Cairo', fontSize: 15,
                fontWeight: FontWeight.w700, color: AppColors.darkText,
              ),
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
              const KaabaOutlineIcon(
                size: 30, color: AppColors.primary, strokeWidth: 2,
              ),
              const SizedBox(height: 6),
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

  bool _notifEnabled = false;
  bool _notifBusy    = false;

  @override
  void initState() {
    super.initState();
    _cubit = PrayerCubit();
    _loadNotifPref();
  }

  @override
  void dispose() {
    _cubit.close();
    super.dispose();
  }

  // ── Notifications ───────────────────────────────────────────────────────────

  Future<void> _loadNotifPref() async {
    final enabled = await PrayerNotificationService.instance.isEnabled();
    if (!mounted) return;

    // The toggle may say "on" while the OS permission was actually revoked
    // from system settings since — zonedSchedule() would keep "succeeding"
    // while Android silently drops delivery. Catch that here instead of
    // letting the toggle lie about its state.
    if (enabled) {
      final stillGranted =
          await PrayerNotificationService.instance.hasNotificationPermission();
      if (!mounted) return;
      if (!stillGranted) {
        await PrayerNotificationService.instance.disable();
        if (!mounted) return;
        setState(() => _notifEnabled = false);
        return;
      }
    }

    setState(() => _notifEnabled = enabled);
    // If already enabled and prayers are ready, refresh the schedule on open.
    if (enabled && _cubit.state.isLoaded) {
      _reschedule(AppLocalizations.of(context)!);
    }
  }

  List<PrayerNotif> _buildNotifs(AppLocalizations l10n) {
    final instants = _cubit.upcomingPrayerInstants(days: 5);
    var id = 1000;
    return [
      for (final e in instants)
        PrayerNotif(
          id:       id++,
          dateTime: e.at,
          title:    e.name.label(l10n),
          body:     l10n.prayerTimeNow(e.name.label(l10n)),
        ),
    ];
  }

  Future<void> _reschedule(AppLocalizations l10n) =>
      PrayerNotificationService.instance.schedule(_buildNotifs(l10n));

  // Long-press the bell → fire a test notification now (+ one 12s out so
  // background delivery can be verified).
  Future<void> _sendTestNotif(AppLocalizations l10n) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await PrayerNotificationService.instance.sendTest(
      l10n.prayerNotifTestTitle,
      l10n.prayerNotifTestBody,
    );
    if (!mounted) return;
    messenger.showSnackBar(SnackBar(
      content: Text(ok ? l10n.prayerNotifTestSent : l10n.prayerNotifBlocked),
    ));
  }

  Future<void> _toggleNotif(AppLocalizations l10n) async {
    if (_notifBusy) return;
    setState(() => _notifBusy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      if (_notifEnabled) {
        await PrayerNotificationService.instance.disable();
        if (!mounted) return;
        setState(() => _notifEnabled = false);
        messenger.showSnackBar(SnackBar(content: Text(l10n.prayerNotifOff)));
      } else {
        // A real location failure means upcomingPrayerInstants() is always
        // empty — enable() would "succeed" having scheduled nothing, with
        // the toggle stuck showing on forever and no way to self-heal.
        // Refuse and say why instead of lying about the state.
        if (_cubit.state.hasError) {
          messenger.showSnackBar(
            SnackBar(content: Text(l10n.prayerNotifLocationError)),
          );
          return;
        }
        final ok = await PrayerNotificationService.instance
            .enable(_buildNotifs(l10n));
        if (!mounted) return;
        setState(() => _notifEnabled = ok);
        messenger.showSnackBar(SnackBar(
          content: Text(ok ? l10n.prayerNotifOn : l10n.prayerNotifBlocked),
        ));
      }
    } finally {
      if (mounted) setState(() => _notifBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _cubit,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: BlocConsumer<PrayerCubit, PrayerState>(
          // Reschedule only when the prayer TIMES change (not on every 1-second
          // countdown tick, which reuses the same prayers list reference).
          listenWhen: (prev, curr) =>
              curr.isLoaded && !identical(prev.prayers, curr.prayers),
          listener: (context, state) {
            if (_notifEnabled) _reschedule(AppLocalizations.of(context)!);
          },
          builder: (context, state) {
            final l10n = AppLocalizations.of(context)!;
            final lang = Localizations.localeOf(context).languageCode;

            final header = SharedHeader(
              title: l10n.prayerTimesTitle,
              trailing: [
                // Prayer-notification on/off toggle
                Tooltip(
                  message: l10n.prayerNotifTooltip,
                  child: GestureDetector(
                    onTap: _notifBusy ? null : () => _toggleNotif(l10n),
                    onLongPress: () => _sendTestNotif(l10n),
                    child: Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                        color: _notifEnabled
                            ? AppColors.primary.withValues(alpha: 0.14)
                            : AppColors.primary.withValues(alpha: 0.09),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        _notifEnabled ? LucideIcons.bell : LucideIcons.bellOff,
                        color: _notifEnabled
                            ? AppColors.primary
                            : AppColors.textSecondary,
                        size: 18,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
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
              child: MubtaathRefresh(
                onRefresh: () => context.read<PrayerCubit>().refresh(),
                child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
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
                            nextPrayer:   state.effectiveNextPrayer,
                            activeWindow: state.activeWindow,
                            countdown:    state.countdown,
                            cityLabel:    cityLabel,
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
              ),
            );
          },
        ),
      ),
    );
  }
}

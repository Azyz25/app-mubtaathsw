// =============================================================================
// MUBTAATH — STUDENT GUIDE PAGE  (v5 — dynamic country + API-driven tip)
// =============================================================================
// Data sources:
//   GET /api/directory/countries   → list of active guide countries
//   GET /api/user                  → user's country_code (best-effort)
//   GET /api/directory?country=XX  → categories + tip config for a country
//
// On init the Cubit:
//   1. Fetches all available countries.
//   2. Reads the authenticated user's country_code from /api/user.
//   3. Auto-selects the matching country; falls back to the first active one.
//   4. Loads the full guide for that country.
//
// The tip banner is fully API-driven (no l10n strings for tip content).
// The country chip in the header is tappable when multiple countries exist.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mubtaath/core/l10n/app_localizations.dart';
import 'package:mubtaath/core/services/dio_client.dart';
import 'package:mubtaath/core/theme/app_colors.dart';
import 'package:mubtaath/core/widgets/shared_widgets.dart';

// =============================================================================
// SECTION 1 — ICON + COLOR MAPPER
// Maps 'icon_key' strings (stored in DB) to Flutter LucideIcons and Colors.
// =============================================================================
class GuideIconMapper {
  static IconData fromKey(String key) {
    const map = <String, IconData>{
      'landmark':      LucideIcons.landmark,
      'phoneCall':     LucideIcons.phoneCall,
      'scale':         LucideIcons.scale,
      'home':          LucideIcons.home,
      'shield':        LucideIcons.shield,
      'train':         LucideIcons.train,
      'bus':           LucideIcons.bus,
      'car':           LucideIcons.car,
      'plane':         LucideIcons.plane,
      'building2':     LucideIcons.building2,
      'building':      LucideIcons.building,
      'school':        LucideIcons.school,
      'hospital':      LucideIcons.heartPulse,
      'briefcase':     LucideIcons.briefcase,
      'bookOpen':      LucideIcons.bookOpen,
      'heart':         LucideIcons.heart,
      'globe2':        LucideIcons.globe2,
      'globe':         LucideIcons.globe,
      'mail':          LucideIcons.mail,
      'phone':         LucideIcons.phone,
      'info':          LucideIcons.info,
      'star':          LucideIcons.star,
      'mapPin':        LucideIcons.mapPin,
      'map':           LucideIcons.map,
      'users':         LucideIcons.users,
      'lock':          LucideIcons.lock,
      'creditCard':    LucideIcons.creditCard,
      'alertTriangle': LucideIcons.alertTriangle,
      'checkCircle':   LucideIcons.checkCircle,
      'filePlus':      LucideIcons.filePlus,
      'helpCircle':    LucideIcons.helpCircle,
      'graduationCap': LucideIcons.graduationCap,
      'heartPulse':    LucideIcons.heartPulse,
      'brain':         LucideIcons.brain,
      'stethoscope':   LucideIcons.stethoscope,
      'pill':          LucideIcons.pill,
      'umbrella':      LucideIcons.umbrella,
      'music':         LucideIcons.music,
      'fileText':      LucideIcons.fileText,
      'bookMarked':    LucideIcons.bookMarked,
      'library':       LucideIcons.library,
      'wifi':          LucideIcons.wifi,
      'zap':           LucideIcons.zap,
      'banknote':      LucideIcons.banknote,
      'lightbulb':     LucideIcons.lightbulb,
      'utensils':      LucideIcons.utensils,
    };
    return map[key] ?? LucideIcons.info;
  }

  /// Parses '#RRGGBB' hex strings to Flutter Color. Falls back to primary.
  static Color colorFromHex(String? hex) {
    if (hex == null || hex.isEmpty) return AppColors.primary;
    final clean = hex.replaceAll('#', '');
    if (clean.length == 6) {
      return Color(int.parse('FF$clean', radix: 16));
    }
    return AppColors.primary;
  }
}

// =============================================================================
// SECTION 2 — UI MODELS
// =============================================================================

/// One country available in the guide (from GET /api/directory/countries).
class CountryOption {
  final int    id;
  final String code;
  final String nameAr;
  final String nameEn;
  final String flag;

  const CountryOption({
    required this.id,
    required this.code,
    required this.nameAr,
    required this.nameEn,
    required this.flag,
  });

  factory CountryOption.fromJson(Map<String, dynamic> j) => CountryOption(
    id:     (j['id']   as num).toInt(),
    code:   j['code']  as String? ?? '',
    nameAr: j['nameAr']as String? ?? '',
    nameEn: j['nameEn']as String? ?? '',
    flag:   j['flag']  as String? ?? '',
  );
}

/// API-driven tip banner. All fields come from guide_countries via the backend.
class GuideTip {
  final bool     visible;
  final String   titleAr;
  final String   titleEn;
  final String   bodyAr;
  final String   bodyEn;
  final IconData iconData;
  final Color    iconColor;
  final Color    iconBgColor;
  final Color    bgColor;

  const GuideTip({
    required this.visible,
    required this.titleAr,
    required this.titleEn,
    required this.bodyAr,
    required this.bodyEn,
    required this.iconData,
    required this.iconColor,
    required this.iconBgColor,
    required this.bgColor,
  });

  String localizedTitle(String lang) => lang == 'ar' ? titleAr : titleEn;
  String localizedBody(String lang)  => lang == 'ar' ? bodyAr  : bodyEn;

  factory GuideTip.fromJson(Map<String, dynamic> j) => GuideTip(
    visible:     j['tipVisible']     as bool?   ?? true,
    titleAr:     j['tipTitleAr']     as String? ?? 'نصيحة المبتعث',
    titleEn:     j['tipTitleEn']     as String? ?? 'Student Tip',
    bodyAr:      j['tipBodyAr']      as String? ?? '',
    bodyEn:      j['tipBodyEn']      as String? ?? '',
    iconData:    GuideIconMapper.fromKey(j['tipIconKey'] as String? ?? 'lightbulb'),
    iconColor:   GuideIconMapper.colorFromHex(j['tipIconColor']   as String?),
    iconBgColor: GuideIconMapper.colorFromHex(j['tipIconBgColor'] as String?),
    bgColor:     GuideIconMapper.colorFromHex(j['tipBgColor']     as String?),
  );
}

class GuideCategory {
  final int    id;
  final String titleAr;
  final String titleEn;
  final IconData icon;
  final Color    iconBg;
  final Color    iconColor;
  final List<GuideItem> items;

  const GuideCategory({
    required this.id,
    required this.titleAr,
    required this.titleEn,
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.items,
  });

  String title(String lang) => lang == 'ar' ? titleAr : titleEn;

  factory GuideCategory.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'] as List<dynamic>? ?? [];
    return GuideCategory(
      id:        json['id']           as int,
      titleAr:   json['titleAr']      as String? ?? '',
      titleEn:   json['titleEn']      as String? ?? '',
      icon:      GuideIconMapper.fromKey(json['iconKey'] as String? ?? 'info'),
      iconColor: GuideIconMapper.colorFromHex(json['iconColor']   as String?),
      iconBg:    GuideIconMapper.colorFromHex(json['iconBgColor'] as String?),
      items:     rawItems
          .whereType<Map<String, dynamic>>()
          .map(GuideItem.fromJson)
          .toList(),
    );
  }
}

class GuideItem {
  final int     id;
  final String  titleAr;
  final String  titleEn;
  final String  subtitleAr;
  final String  subtitleEn;
  final String? phone;
  final String? url;

  IconData get icon {
    if (phone != null && url == null) return LucideIcons.phone;
    if (url   != null && phone == null) return LucideIcons.externalLink;
    if (phone != null && url != null) return LucideIcons.link;
    return LucideIcons.fileText;
  }

  const GuideItem({
    required this.id,
    required this.titleAr,
    required this.titleEn,
    required this.subtitleAr,
    required this.subtitleEn,
    this.phone,
    this.url,
  });

  String localizedTitle(String lang)    => lang == 'ar' ? titleAr    : titleEn;
  String localizedSubtitle(String lang) => lang == 'ar' ? subtitleAr : subtitleEn;

  factory GuideItem.fromJson(Map<String, dynamic> json) => GuideItem(
    id:         json['id']         as int,
    titleAr:    json['titleAr']    as String? ?? '',
    titleEn:    json['titleEn']    as String? ?? '',
    subtitleAr: json['subtitleAr'] as String? ?? '',
    subtitleEn: json['subtitleEn'] as String? ?? '',
    phone:      json['phone']      as String?,
    url:        json['url']        as String?,
  );
}

// =============================================================================
// SECTION 3 — API SERVICE
// Thin wrappers around appDio — keeps the Cubit free of HTTP details.
// =============================================================================
class _GuideApiService {
  /// GET /api/directory/countries → active countries for the guide switcher.
  Future<List<CountryOption>> fetchCountries() async {
    final res  = await appDio.get('/directory/countries');
    final raw  = res.data['data'];
    final list = raw is List<dynamic> ? raw : <dynamic>[];
    return list
        .whereType<Map<String, dynamic>>()
        .map(CountryOption.fromJson)
        .toList();
  }

  /// GET /api/user → best-effort extraction of the user's country_code.
  /// Never throws; returns null on any failure so the guide still loads.
  Future<String?> fetchUserCountryCode() async {
    try {
      final res  = await appDio.get('/user');
      final data = (res.data['data'] ?? res.data) as Map<String, dynamic>?;
      return data?['countryCode']?.toString()
          ?? data?['country_code']?.toString();
    } catch (_) {
      return null;
    }
  }

  /// GET /api/directory?country=XX → full guide payload including tip fields.
  Future<Map<String, dynamic>> fetchGuideData(String countryCode) async {
    final res = await appDio.get(
      '/directory',
      queryParameters: {'country': countryCode},
    );
    return res.data['data'] as Map<String, dynamic>;
  }
}

// =============================================================================
// SECTION 4 — STATE + CUBIT
// =============================================================================
enum GuideStatus { loading, loaded, error }

class GuideState {
  final GuideStatus         status;
  final List<GuideCategory> all;
  final List<GuideCategory> filtered;
  final String              query;
  // Country metadata
  final List<CountryOption> countries;
  final String              selectedCountryCode;
  final String              selectedCountryFlag;
  final String              selectedCountryNameAr;
  final String              selectedCountryNameEn;
  // Tip banner
  final GuideTip?           tip;
  // The user's own country — locked during _init, never mutated by switchCountry
  final String              homeCountryCode;

  const GuideState({
    this.status                = GuideStatus.loading,
    this.all                   = const [],
    this.filtered              = const [],
    this.query                 = '',
    this.countries             = const [],
    this.selectedCountryCode   = '',
    this.selectedCountryFlag   = '',
    this.selectedCountryNameAr = '',
    this.selectedCountryNameEn = '',
    this.tip,
    this.homeCountryCode       = '',
  });

  GuideState copyWith({
    GuideStatus?         status,
    List<GuideCategory>? all,
    List<GuideCategory>? filtered,
    String?              query,
    List<CountryOption>? countries,
    String?              selectedCountryCode,
    String?              selectedCountryFlag,
    String?              selectedCountryNameAr,
    String?              selectedCountryNameEn,
    GuideTip?            tip,
    String?              homeCountryCode,
  }) =>
      GuideState(
        status:                  status               ?? this.status,
        all:                     all                  ?? this.all,
        filtered:                filtered             ?? this.filtered,
        query:                   query                ?? this.query,
        countries:               countries            ?? this.countries,
        selectedCountryCode:     selectedCountryCode  ?? this.selectedCountryCode,
        selectedCountryFlag:     selectedCountryFlag  ?? this.selectedCountryFlag,
        selectedCountryNameAr:   selectedCountryNameAr ?? this.selectedCountryNameAr,
        selectedCountryNameEn:   selectedCountryNameEn ?? this.selectedCountryNameEn,
        tip:                     tip                  ?? this.tip,
        homeCountryCode:         homeCountryCode      ?? this.homeCountryCode,
      );
}

class GuideCubit extends Cubit<GuideState> {
  GuideCubit() : super(const GuideState()) {
    _init();
  }

  final _api = _GuideApiService();

  /// Boot sequence: countries → user country → load guide.
  Future<void> _init() async {
    emit(state.copyWith(status: GuideStatus.loading, query: ''));
    try {
      final countries = await _api.fetchCountries();
      final userCode  = await _api.fetchUserCountryCode();

      // Prefer the user's country if it exists in DB, else first active country
      final codes    = {for (final c in countries) c.code};
      final bestCode = (userCode != null && codes.contains(userCode.toUpperCase()))
          ? userCode.toUpperCase()
          : (countries.isNotEmpty ? countries.first.code : 'GB');

      await _loadCountry(bestCode, countries, bestCode);
    } catch (_) {
      if (!isClosed) emit(state.copyWith(status: GuideStatus.error));
    }
  }

  Future<void> _loadCountry(
    String code, [
    List<CountryOption>? availableCountries,
    String? homeCode,
  ]) async {
    try {
      final data = await _api.fetchGuideData(code);
      final cats = _parseCategories(data);
      if (!isClosed) {
        emit(GuideState(
          status:                GuideStatus.loaded,
          countries:             availableCountries ?? state.countries,
          selectedCountryCode:   data['countryCode']   as String? ?? code,
          selectedCountryFlag:   data['countryFlag']   as String? ?? '',
          selectedCountryNameAr: data['countryNameAr'] as String? ?? '',
          selectedCountryNameEn: data['countryNameEn'] as String? ?? '',
          all:                   cats,
          filtered:              cats,
          tip:                   GuideTip.fromJson(data),
          homeCountryCode:       homeCode ?? state.homeCountryCode,
        ));
      }
    } catch (_) {
      if (!isClosed) emit(state.copyWith(status: GuideStatus.error));
    }
  }

  /// Called from the country switcher sheet.
  Future<void> switchCountry(String code) async {
    emit(state.copyWith(status: GuideStatus.loading, query: ''));
    await _loadCountry(code);
  }

  /// Called on every page entry — snaps back to the user's own country.
  /// No-ops if already showing the home country in loaded state.
  Future<void> resetToHome() async {
    if (state.homeCountryCode.isEmpty) {
      await _init();
      return;
    }
    if (state.homeCountryCode == state.selectedCountryCode &&
        state.status == GuideStatus.loaded) {
      return;
    }
    emit(state.copyWith(status: GuideStatus.loading, query: ''));
    await _loadCountry(state.homeCountryCode);
  }

  /// Pull-to-refresh — reloads the currently selected country.
  Future<void> reload() async {
    emit(state.copyWith(status: GuideStatus.loading, query: ''));
    await _loadCountry(state.selectedCountryCode);
  }

  void search(String q) {
    final lq = q.trim().toLowerCase();
    emit(state.copyWith(
      query:    q,
      filtered: lq.isEmpty
          ? state.all
          : state.all.where((c) =>
              c.titleAr.toLowerCase().contains(lq) ||
              c.titleEn.toLowerCase().contains(lq) ||
              c.items.any((i) =>
                  i.titleAr.toLowerCase().contains(lq)    ||
                  i.titleEn.toLowerCase().contains(lq)    ||
                  i.subtitleAr.toLowerCase().contains(lq) ||
                  i.subtitleEn.toLowerCase().contains(lq))).toList(),
    ));
  }

  void clearSearch() => emit(state.copyWith(query: '', filtered: state.all));

  static List<GuideCategory> _parseCategories(Map<String, dynamic> data) {
    final raw = data['categories'];
    if (raw is! List) return [];
    return raw.whereType<Map<String, dynamic>>().map(GuideCategory.fromJson).toList();
  }
}

// =============================================================================
// SECTION 5 — CATEGORY TILE
// =============================================================================
class _CategoryTile extends StatelessWidget {
  final GuideCategory cat;
  final VoidCallback  onTap;
  const _CategoryTile({required this.cat, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final lang = Localizations.localeOf(context).languageCode;
    return GestureDetector(
      onTap: onTap,
      child: MubtaethCard(
        padding: EdgeInsets.zero,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 52, height: 52,
              decoration: BoxDecoration(
                color:        cat.iconBg,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(cat.icon, color: cat.iconColor, size: 26),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                cat.title(lang),
                textAlign: TextAlign.center,
                maxLines:  2,
                overflow:  TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: 'Cairo', fontSize: 13,
                  fontWeight: FontWeight.w700, color: AppColors.darkText,
                  height: 1.3,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color:        AppColors.primary.withValues(alpha: 0.09),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                l10n.linksCount(cat.items.length),
                style: const TextStyle(
                  fontFamily: 'Cairo', fontSize: 11,
                  fontWeight: FontWeight.w600, color: AppColors.primary,
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
// SECTION 6 — GUIDE ITEM ROW (inside bottom sheet)
// =============================================================================
class _GuideItemRow extends StatelessWidget {
  final GuideItem item;
  const _GuideItemRow({required this.item});

  @override
  Widget build(BuildContext context) {
    final lang = Localizations.localeOf(context).languageCode;
    return CoreCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color:        AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(item.icon, color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  item.localizedTitle(lang),
                  textAlign: TextAlign.start,
                  style: const TextStyle(
                    fontFamily: 'Cairo', fontSize: 14,
                    fontWeight: FontWeight.w700, color: AppColors.darkText,
                    height: 1.3,
                  ),
                ),
                if (item.localizedSubtitle(lang).isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    item.localizedSubtitle(lang),
                    textAlign: TextAlign.start,
                    style: const TextStyle(
                      fontFamily: 'Tajawal', fontSize: 12,
                      color: AppColors.textSecondary, height: 1.4,
                    ),
                  ),
                ],
                if (item.phone != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    item.phone!,
                    textAlign:     TextAlign.start,
                    textDirection: TextDirection.ltr,
                    style: const TextStyle(
                      fontFamily: 'Cairo', fontSize: 13,
                      fontWeight: FontWeight.w600, color: AppColors.primary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (item.phone != null || item.url != null) ...[
            const SizedBox(width: 12),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (item.phone != null)
                  GestureDetector(
                    onTap: () { /* TODO: url_launcher tel:${item.phone} */ },
                    child: Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                        color:        AppColors.primary.withValues(alpha: 0.09),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(LucideIcons.phone,
                          color: AppColors.primary, size: 16),
                    ),
                  ),
                if (item.phone != null && item.url != null)
                  const SizedBox(width: 8),
                if (item.url != null)
                  GestureDetector(
                    onTap: () { /* TODO: url_launcher ${item.url} */ },
                    child: Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                        color:        AppColors.secondary.withValues(alpha: 0.09),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(LucideIcons.externalLink,
                          color: AppColors.secondary, size: 16),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// =============================================================================
// SECTION 7 — CATEGORY BOTTOM SHEET
// =============================================================================
void _showSheet(BuildContext ctx, GuideCategory cat) {
  final l10n = AppLocalizations.of(ctx)!;
  final lang = Localizations.localeOf(ctx).languageCode;
  showModalBottomSheet(
    context:            ctx,
    backgroundColor:    Colors.transparent,
    isScrollControlled: true,
    showDragHandle:     false,
    builder: (_) => DraggableScrollableSheet(
      initialChildSize: 0.60,
      minChildSize:     0.40,
      maxChildSize:     0.92,
      expand:           false,
      builder: (_, ctrl) => Container(
        decoration: const BoxDecoration(
          color:        AppColors.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 38, height: 4,
              decoration: BoxDecoration(
                color:        AppColors.cardBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 18),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  Container(
                    width: 38, height: 38,
                    decoration: BoxDecoration(
                      color:        cat.iconBg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(cat.icon, color: cat.iconColor, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      cat.title(lang),
                      style: const TextStyle(
                        fontFamily: 'Cairo', fontSize: 18,
                        fontWeight: FontWeight.w800, color: AppColors.darkText,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color:        AppColors.primary.withValues(alpha: 0.09),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      l10n.itemsCount(cat.items.length),
                      style: const TextStyle(
                        fontFamily: 'Cairo', fontSize: 12,
                        fontWeight: FontWeight.w600, color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: Divider(color: AppColors.cardBorder, height: 1),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.separated(
                controller:       ctrl,
                padding:          const EdgeInsets.fromLTRB(24, 8, 24, 32),
                itemCount:        cat.items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder:      (_, i) => _GuideItemRow(item: cat.items[i]),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

// =============================================================================
// SECTION 8 — COUNTRY SWITCHER BOTTOM SHEET
// Shown when the user taps the country chip. Hidden if only 1 country exists.
// =============================================================================
void _showCountrySwitcher(
  BuildContext ctx,
  GuideCubit cubit,
  GuideState state,
) {
  if (state.countries.length <= 1) return;
  showModalBottomSheet(
    context:         ctx,
    backgroundColor: Colors.transparent,
    builder: (_) => Container(
      decoration: const BoxDecoration(
        color:        AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'اختر الدولة',
                style: TextStyle(
                  fontFamily: 'Cairo', fontSize: 16,
                  fontWeight: FontWeight.w800, color: AppColors.darkText,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => Navigator.of(ctx).pop(),
                child: Container(
                  width: 30, height: 30,
                  decoration: BoxDecoration(
                    color: AppColors.cardBorder,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(LucideIcons.x,
                      size: 14, color: AppColors.darkText),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...state.countries.map((country) {
            final selected = country.code == state.selectedCountryCode;
            return GestureDetector(
              onTap: () {
                if (!selected) cubit.switchCountry(country.code);
                Navigator.of(ctx).pop();
              },
              child: Container(
                margin:  const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: selected
                      ? AppColors.primary.withValues(alpha: 0.08)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: selected
                        ? AppColors.primary.withValues(alpha: 0.25)
                        : AppColors.cardBorder,
                  ),
                ),
                child: Row(
                  children: [
                    Text(country.flag, style: const TextStyle(fontSize: 22)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        country.nameAr,
                        style: TextStyle(
                          fontFamily: 'Cairo', fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: selected ? AppColors.primary : AppColors.darkText,
                        ),
                      ),
                    ),
                    if (selected)
                      const Icon(LucideIcons.checkCircle,
                          size: 18, color: AppColors.primary),
                  ],
                ),
              ),
            );
          }),
          SizedBox(height: MediaQuery.of(ctx).padding.bottom + 16),
        ],
      ),
    ),
  );
}

// =============================================================================
// SECTION 9 — TIP BANNER  (fully API-driven)
// =============================================================================
class _TipBanner extends StatelessWidget {
  final GuideTip tip;
  const _TipBanner({required this.tip});

  @override
  Widget build(BuildContext context) {
    final lang = Localizations.localeOf(context).languageCode;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color:        tip.bgColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color:      tip.bgColor.withValues(alpha: 0.22),
            blurRadius: 16, offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 42, height: 42,
            decoration: BoxDecoration(
              color:        tip.iconBgColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(tip.iconData, color: tip.iconColor, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tip.localizedTitle(lang),
                  textAlign: TextAlign.start,
                  style: TextStyle(
                    fontFamily: 'Cairo', fontSize: 14,
                    fontWeight: FontWeight.w800, color: tip.iconColor,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  tip.localizedBody(lang),
                  textAlign: TextAlign.start,
                  style: TextStyle(
                    fontFamily: 'Tajawal', fontSize: 12,
                    color: tip.iconColor.withValues(alpha: 0.75), height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// SECTION 10 — STUDENT GUIDE PAGE
// =============================================================================
class StudentGuidePage extends StatelessWidget {
  const StudentGuidePage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => GuideCubit(),
      child: const _StudentGuideView(),
    );
  }
}

class _StudentGuideView extends StatefulWidget {
  const _StudentGuideView();

  @override
  State<_StudentGuideView> createState() => _StudentGuideViewState();
}

class _StudentGuideViewState extends State<_StudentGuideView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<GuideCubit>().resetToHome();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: BlocBuilder<GuideCubit, GuideState>(
        builder: (context, state) {
          final cubit = context.read<GuideCubit>();
          final l10n  = AppLocalizations.of(context)!;

          return SafeArea(
            bottom: false,
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [

                // ── Header ──────────────────────────────────────────
                SliverToBoxAdapter(
                  child: SharedHeader(
                    title: l10n.studentGuideTitle,
                    trailing: [
                      GestureDetector(
                        onTap: state.countries.length > 1
                            ? () => _showCountrySwitcher(
                                context, cubit, state)
                            : null,
                        child: Container(
                          height: 34,
                          padding:
                              const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: Theme.of(context).cardColor,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: AppColors.cardBorder,
                              width: 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.darkText
                                    .withValues(alpha: 0.06),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          alignment: Alignment.center,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (state.selectedCountryFlag.isNotEmpty) ...[
                                Text(
                                  state.selectedCountryFlag,
                                  style: const TextStyle(fontSize: 14),
                                ),
                                const SizedBox(width: 6),
                              ],
                              Text(
                                state.selectedCountryNameAr.isNotEmpty
                                    ? state.selectedCountryNameAr
                                    : '...',
                                style: const TextStyle(
                                  fontFamily: 'Cairo',
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.darkText,
                                ),
                              ),
                              if (state.countries.length > 1) ...[
                                const SizedBox(width: 3),
                                const Icon(
                                  LucideIcons.chevronDown,
                                  size: 13,
                                  color: AppColors.textSecondary,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 20)),

                // ── Loading ──────────────────────────────────────────
                if (state.status == GuideStatus.loading)
                  const SliverFillRemaining(
                    child: Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                        strokeWidth: 2.5,
                      ),
                    ),
                  )

                // ── Error ────────────────────────────────────────────
                else if (state.status == GuideStatus.error)
                  SliverFillRemaining(
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(LucideIcons.wifiOff, size: 48,
                              color: AppColors.primary.withValues(alpha: 0.3)),
                          const SizedBox(height: 16),
                          const Text(
                            'تعذّر تحميل الدليل',
                            style: TextStyle(
                              fontFamily: 'Cairo', fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppColors.darkText,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'تحقق من الاتصال بالإنترنت',
                            style: TextStyle(
                              fontFamily: 'Tajawal', fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 24),
                          GestureDetector(
                            onTap: cubit.reload,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 24, vertical: 12),
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text(
                                'إعادة المحاولة',
                                style: TextStyle(
                                  fontFamily: 'Cairo', fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )

                // ── Loaded ───────────────────────────────────────────
                else ...[
                  // Search bar
                  SliverToBoxAdapter(
                    child: Padding(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 20),
                      child: AppSearchBar(
                        initialQuery: state.query,
                        hintText:     l10n.studentGuideSearchHint,
                        onChanged:    cubit.search,
                        onClear:      cubit.clearSearch,
                      ),
                    ),
                  ),

                  const SliverToBoxAdapter(child: SizedBox(height: 20)),

                  // Search results label
                  if (state.query.isNotEmpty) ...[
                    SliverToBoxAdapter(
                      child: Padding(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 20),
                        child: Row(
                          mainAxisAlignment:
                              MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              l10n.searchResults,
                              style: const TextStyle(
                                fontFamily: 'Cairo', fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: AppColors.darkText,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.primary
                                    .withValues(alpha: 0.09),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                l10n.resultsCount(state.filtered.length),
                                style: const TextStyle(
                                  fontFamily: 'Cairo', fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SliverToBoxAdapter(child: SizedBox(height: 14)),
                  ],

                  // Grid or empty search state
                  if (state.filtered.isEmpty)
                    SliverFillRemaining(
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(LucideIcons.searchX, size: 52,
                                color: AppColors.primary
                                    .withValues(alpha: 0.22)),
                            const SizedBox(height: 16),
                            Text(
                              l10n.noResultsFor(state.query),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontFamily: 'Cairo', fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              l10n.tryDifferentSearch,
                              style: const TextStyle(
                                fontFamily: 'Tajawal', fontSize: 13,
                                color: AppColors.textHint,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 20),
                      sliver: SliverGrid(
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount:   2,
                          mainAxisSpacing:  14,
                          crossAxisSpacing: 14,
                          childAspectRatio: 1.0,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (ctx, i) => _CategoryTile(
                            cat:   state.filtered[i],
                            onTap: () =>
                                _showSheet(ctx, state.filtered[i]),
                          ),
                          childCount: state.filtered.length,
                        ),
                      ),
                    ),

                  // Tip banner — visible only when not searching
                  // and the admin has enabled it for this country
                  if (state.query.isEmpty &&
                      state.tip != null &&
                      state.tip!.visible) ...[
                    const SliverToBoxAdapter(child: SizedBox(height: 20)),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 20),
                        child: _TipBanner(tip: state.tip!),
                      ),
                    ),
                  ],
                ],

                SliverToBoxAdapter(
                  child: SizedBox(
                    height:
                        MediaQuery.of(context).padding.bottom + 60,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

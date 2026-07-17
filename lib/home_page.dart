// =============================================================================
// MUBTAATH APP — HOME PAGE  (v4 — fully localized RTL + brand identity)
// =============================================================================
// File Path  : lib/features/home/presentation/pages/home_page.dart
// Design Ref : تطبيق_مبتعث.pdf — Page 6
//
// RTL CONTRACT (enforced globally):
//   • Directionality(rtl) wraps every Scaffold body
//   • CrossAxisAlignment.start  → points to RIGHT in RTL
//   • CrossAxisAlignment.end    → points to LEFT  in RTL
//   • MainAxisAlignment.end     → RIGHT side of Row in RTL
//   • TextAlign.right           → explicit on every Text
//   • textDirection: rtl        → on every TextField
//
// SHADOW SPEC (task v4):
//   BoxShadow(color: #305544.withOpacity(0.08), blurRadius: 15, offset: (0,8))
//
// SEARCH BAR SPEC (task v4):
//   height: 56 | border: #305544 1.2px | icon: RIGHT | hint: follows icon
//
// TYPOGRAPHY SPEC:
//   Section headers → Cairo Bold  18-20px
//   Body / hints    → Tajawal     14px
//   Room title      → Cairo Bold  15px
//   Nav labels      → Cairo       9px
// =============================================================================

import 'dart:ui' show ImageFilter;

import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mubtaath/settings_page.dart';
import 'package:mubtaath/core/services/nav_style_setting.dart';
import 'package:mubtaath/prayer_times_page.dart';
import 'package:mubtaath/student_guide_page.dart' hide AppSearchBar;
import 'package:mubtaath/notifications_page.dart';
import 'package:mubtaath/community_page.dart';
import 'package:mubtaath/core/theme/app_colors.dart';
import 'package:mubtaath/core/widgets/mubtaath_refresh.dart';
import 'package:mubtaath/core/widgets/post_signup_sheets.dart';
import 'package:mubtaath/core/widgets/shared_widgets.dart';
import 'package:mubtaath/core/l10n/app_localizations.dart';
import 'package:mubtaath/core/services/dio_client.dart';
import 'package:mubtaath/core/bloc/room_status_cubit.dart';
import 'package:mubtaath/core/utils/avatar_utils.dart';


// =============================================================================
// SECTION 0 — DESIGN TOKENS  (single source of truth)
// =============================================================================

/// ─── Typography ──────────────────────────────────────────────────────────────
const TextStyle _kHeaderStyle = TextStyle(
  fontFamily: 'Cairo',
  fontSize:   20,
  fontWeight: FontWeight.w800,
  color:      AppColors.darkText,
  height:     1.3,
);

const TextStyle _kSubHeaderStyle = TextStyle(
  fontFamily: 'Cairo',
  fontSize:   18,
  fontWeight: FontWeight.w700,
  color:      AppColors.darkText,
  height:     1.3,
);

const TextStyle _kBodyStyle = TextStyle(
  fontFamily: 'Tajawal',
  fontSize:   14,
  fontWeight: FontWeight.w400,
  color:      AppColors.textSecondary,
  height:     1.5,
);

/// ─── Spacing constants ────────────────────────────────────────────────────────
const double kPageHPad   = 20.0;
const double kCardRadius = 22.0;
const double kCardGap    = 14.0;

// =============================================================================
// SECTION 1 — ROOM MODEL
// =============================================================================

class RoomModel implements RoomCardData {
  @override
  final String id;
  final String titleAr;
  final String titleEn;
  @override
  final String imageUrl;
  @override
  final int    listenerCount;
  final String countryCode;
  final String hostName;
  final String hostAvatar;
  @override
  final bool   isLive;

  const RoomModel({
    required this.id,
    required this.titleAr,
    required this.titleEn,
    required this.imageUrl,
    required this.listenerCount,
    required this.countryCode,
    this.hostName   = '',
    this.hostAvatar = '',
    this.isLive     = true,
  });

  factory RoomModel.fromJson(Map<String, dynamic> j) => RoomModel(
    id:            j['id']            as String? ?? '',
    titleAr:       j['titleAr']       as String? ?? '',
    titleEn:       j['titleEn']       as String? ?? '',
    imageUrl:      j['imageUrl']      as String? ?? '',
    listenerCount: j['listenerCount'] as int?    ?? 0,
    countryCode:   j['countryCode']   as String? ?? '',
    hostName:      j['hostName']      as String? ?? '',
    hostAvatar:    j['hostAvatar']    as String? ?? '',
    isLive:        j['isLive']        as bool?   ?? false,
  );

  @override
  String localizedTitle(String lang) => lang == 'ar' ? titleAr : titleEn;
}

// ── Rooms API service ─────────────────────────────────────────────────────────
class _RoomsApi {
  Future<List<RoomModel>> fetchByCountry(String countryCode) async {
    final params = <String, dynamic>{'status': 'active'};
    if (countryCode.isNotEmpty) params['country'] = countryCode;
    final resp = await appDio.get('/rooms', queryParameters: params);
    final data = resp.data['data'] as List<dynamic>? ?? [];
    return data
        .map((e) => RoomModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}

// =============================================================================
// SECTION 2 — HOME STATE + CUBIT
// =============================================================================

class HomeState {
  final int             navIndex;
  final String          searchQuery;
  final List<RoomModel> allRooms;
  final List<RoomModel> filteredRooms;
  final bool            isLoading;
  final bool            hasError;
  final String userId;
  final String userCountryCode;
  final String userCountryNameAr;
  final String userCountryNameEn;
  final String userCountryFlag;
  final String userFirstName;
  final String userAvatar;
  final String iosNavStyle;

  const HomeState({
    this.navIndex           = 0,
    this.searchQuery        = '',
    this.allRooms           = const [],
    this.filteredRooms      = const [],
    this.isLoading          = true,
    this.hasError           = false,
    this.userId             = '',
    this.userCountryCode    = '',
    this.userCountryNameAr  = '',
    this.userCountryNameEn  = '',
    this.userCountryFlag    = '',
    this.userFirstName      = '',
    this.userAvatar         = '',
    this.iosNavStyle        = NavStyleSetting.liquid,
  });

  HomeState copyWith({
    int?             navIndex,
    String?          searchQuery,
    List<RoomModel>? allRooms,
    List<RoomModel>? filteredRooms,
    bool?            isLoading,
    bool?            hasError,
    String?          userId,
    String?          userCountryCode,
    String?          userCountryNameAr,
    String?          userCountryNameEn,
    String?          userCountryFlag,
    String?          userFirstName,
    String?          userAvatar,
    String?          iosNavStyle,
  }) =>
      HomeState(
        navIndex:          navIndex          ?? this.navIndex,
        searchQuery:       searchQuery       ?? this.searchQuery,
        allRooms:          allRooms          ?? this.allRooms,
        filteredRooms:     filteredRooms     ?? this.filteredRooms,
        isLoading:         isLoading         ?? this.isLoading,
        hasError:          hasError          ?? this.hasError,
        userId:            userId            ?? this.userId,
        userCountryCode:   userCountryCode   ?? this.userCountryCode,
        userCountryNameAr: userCountryNameAr ?? this.userCountryNameAr,
        userCountryNameEn: userCountryNameEn ?? this.userCountryNameEn,
        userCountryFlag:   userCountryFlag   ?? this.userCountryFlag,
        userFirstName:     userFirstName     ?? this.userFirstName,
        userAvatar:        userAvatar        ?? this.userAvatar,
        iosNavStyle:       iosNavStyle       ?? this.iosNavStyle,
      );
}

class HomeCubit extends Cubit<HomeState> {
  final _api = _RoomsApi();
  final RoomStatusCubit _statusCubit;

  HomeCubit(this._statusCubit) : super(const HomeState()) {
    _initialize();
    NavStyleSetting.get().then((v) {
      if (!isClosed) emit(state.copyWith(iosNavStyle: v));
    });
  }

  Future<void> setIosNavStyle(String style) async {
    emit(state.copyWith(iosNavStyle: style));
    await NavStyleSetting.set(style);
  }

  Future<void> _initialize() async {
    try {
      final resp    = await appDio.get('/auth/me');
      final user    = resp.data['data'] as Map<String, dynamic>;
      final fullName  = user['fullName']  as String? ?? '';
      final firstName = fullName.split(' ').first;
      final avatarUrl = user['avatarUrl'] as String? ?? '';
      final avatarId  = (user['avatarId'] as num?)?.toInt() ?? 1;
      final avatarPath = avatarUrl.isNotEmpty ? avatarUrl : getAvatarPath(avatarId);

      emit(state.copyWith(
        userId:            user['id']?.toString() ?? '',
        userFirstName:     firstName,
        userAvatar:        avatarPath,
        userCountryCode:   user['countryCode']   as String? ?? '',
        userCountryNameAr: user['countryNameAr'] as String? ?? '',
        userCountryNameEn: user['countryNameEn'] as String? ?? '',
        userCountryFlag:   user['countryFlag']   as String? ?? '',
      ));
    } catch (e) {
      debugPrint('[HomeCubit] user fetch error: $e');
      // Non-fatal — proceed with empty user data; rooms still load
    }
    await _loadRooms();
  }

  Future<void> _loadRooms() async {
    emit(state.copyWith(isLoading: true, hasError: false));
    try {
      final rooms = await _api.fetchByCountry(state.userCountryCode);
      emit(state.copyWith(
        isLoading:    false,
        allRooms:     rooms,
        filteredRooms: rooms,
      ));
      _statusCubit.seedCounts({for (final r in rooms) r.id: r.listenerCount});
    } catch (e) {
      debugPrint('[HomeCubit] fetch error: $e');
      emit(state.copyWith(isLoading: false, hasError: true));
    }
  }

  Future<void> reload() => _initialize();

  void setNavIndex(int i) => emit(state.copyWith(navIndex: i));

  void search(String query) {
    if (query.length > 100) return;
    final q = query.trim().toLowerCase();
    emit(state.copyWith(
      searchQuery:   query,
      filteredRooms: q.isEmpty
          ? state.allRooms
          : state.allRooms
              .where((r) =>
                  r.titleAr.toLowerCase().contains(q) ||
                  r.titleEn.toLowerCase().contains(q) ||
                  r.hostName.toLowerCase().contains(q))
              .toList(),
    ));
  }

  void clearSearch() => emit(state.copyWith(
        searchQuery:   '',
        filteredRooms: state.allRooms,
      ));
}

// =============================================================================
// SECTION 3 — NAV ITEMS (Lucide icons)
// =============================================================================

class _NavItem {
  final IconData icon;
  final String   label;
  const _NavItem({required this.icon, required this.label});
}

const List<_NavItem> _kNavItems = [
  _NavItem(icon: LucideIcons.home,          label: 'home'),
  _NavItem(icon: LucideIcons.bell,          label: 'notifications'),
  _NavItem(icon: LucideIcons.messageCircle, label: 'community'),
  _NavItem(icon: LucideIcons.settings2,     label: 'settings'),
  _NavItem(icon: LucideIcons.moon,          label: 'prayer'),
  _NavItem(icon: LucideIcons.bookOpen,      label: 'guide'),
];

String _navLabel(String key, AppLocalizations l10n) => switch (key) {
  'home'          => l10n.navHome,
  'notifications' => l10n.notificationsTitle,
  'community'     => l10n.navCommunity,
  'settings'      => l10n.settingsTitle,
  'prayer'        => l10n.navPrayer,
  'guide'         => l10n.navGuide,
  _               => l10n.navHome,
};

bool get _isIOS =>
    defaultTargetPlatform == TargetPlatform.iOS ||
    defaultTargetPlatform == TargetPlatform.macOS;

// =============================================================================
// SECTION 4 — HOME HEADER
// 2px solid green border around avatar
// CrossAxisAlignment.start → RIGHT in RTL
// =============================================================================


class _HomeHeader extends StatelessWidget {
  final HomeState state;
  const _HomeHeader({required this.state});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final lang = Localizations.localeOf(context).languageCode;
    final countryName = lang == 'ar'
        ? state.userCountryNameAr
        : state.userCountryNameEn;

    return Padding(
      padding: const EdgeInsets.fromLTRB(kPageHPad, 20, kPageHPad, 0),
      child: Row(
        children: [
          // 👈 هنا الاستبدال الذكي
  GestureDetector(
  onTap: () => context.push('/profile'),
  child: CoreAvatar(
    size: 48,
    // نستخدم المتغيرات مباشرة من state
    imageUrl: state.userAvatar, 
    initials: state.userFirstName, 
    isPremium: false, 
  ),
),

          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.greeting(state.userFirstName),
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF051C16),
                  ),
                ),
                Text(
                  '${l10n.studyingIn(countryName)} ${state.userCountryFlag}',
                  style: TextStyle(
                    fontFamily: 'Tajawal',
                    fontSize: 13,
                    color: AppColors.primary.withOpacity(0.8),
                    fontWeight: FontWeight.w500,
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
// SECTION 6 — SECTION HEADER ROW
// Cairo Bold 20px | TextAlign.right | count badge on left
// =============================================================================

class _SectionHeader extends StatelessWidget {
  final String label;
  final int? count;

  const _SectionHeader({required this.label, this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity, // لضمان أخذ كامل العرض
      alignment: AlignmentDirectional.centerStart, // محاذاة المحتوى لليمين
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'Cairo',
              fontSize: 19,
              fontWeight: FontWeight.w800,
              color: AppColors.primary, // اللون أخضر الهوية
            ),
          ),
          if (count != null) ...[
            const SizedBox(width: 8),
            Text(
              '($count)',
              style: const TextStyle(
                fontFamily: 'Tajawal',
                fontSize: 15,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}


// =============================================================================
// SECTION 8 — EMPTY SEARCH STATE
// =============================================================================

class _EmptyState extends StatelessWidget {
  final String query;
  const _EmptyState({required this.query});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        // ── start = RIGHT in RTL ──────────────────────────────────────
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(
            LucideIcons.searchX,
            size:  52,
            color: AppColors.primary.withOpacity(0.22),
          ),
          const SizedBox(height: 16),
          Text(
            l10n.noResultsFor(query),
            textAlign: TextAlign.start,
            style: _kSubHeaderStyle.copyWith(
              color:      AppColors.textSecondary,
              fontSize:   15,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.tryDifferentSearch,
            textAlign: TextAlign.start,
            style: _kBodyStyle,
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// SECTION 9 — HOME BODY (tab content)
// =============================================================================

class _HomeBody extends StatelessWidget {
  const _HomeBody();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<HomeCubit, HomeState>(
      builder: (context, state) {
        final l10n = AppLocalizations.of(context)!;
        final cubit = context.read<HomeCubit>();
        final rooms = state.filteredRooms;

        return SafeArea(
            bottom: false,
            child: MubtaathRefresh(
              onRefresh: () => cubit.reload(),
              child: CustomScrollView(
              // AlwaysScrollable so the pull-to-refresh works even when the
              // content is shorter than the viewport.
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              slivers: [
                // ── Header ────────────────────────────────────────────────
                SliverToBoxAdapter(
                  child: _HomeHeader(state: state),
                ),

                // ── Search bar ────────────────────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      kPageHPad, 18, kPageHPad, 0,
                    ),
                    child: AppSearchBar(
                      hintText:     l10n.homeSearchHint,
                      initialQuery: state.searchQuery,
                      onChanged:    cubit.search,
                      onClear:      cubit.clearSearch,
                    ),
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 24)),

                // ── Section header ────────────────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: kPageHPad),
                    child: Align(
                      alignment: AlignmentDirectional.centerStart, // التأكيد على المحاذاة لليمين
                      child: _SectionHeader(
                        label: state.searchQuery.isEmpty
                            ? l10n.featuredRooms
                            : l10n.searchResults,
                        count: state.searchQuery.isNotEmpty ? rooms.length : null,
                      ),
                    ),
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 14)),

                // ── Rooms list ────────────────────────────────────────────
                if (rooms.isEmpty && state.searchQuery.isNotEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: kPageHPad,
                      ),
                      child: _EmptyState(query: state.searchQuery),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: kPageHPad,
                    ),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (ctx, i) {
                          if (i.isOdd) return const SizedBox(height: kCardGap);
                          final room = rooms[i ~/ 2];
                          return CommunityRoomCard(
                            room:  room,
                            onTap: () => ctx.push('/room/${room.id}'),
                          );
                        },
                        childCount: rooms.isNotEmpty
                            ? rooms.length * 2 - 1
                            : 0,
                      ),
                    ),
                  ),

                // Scroll clearance so the last room card can be pulled clear
                // of the floating liquid pill — content still extends behind
                // the pill at rest, this just makes the tail end reachable.
                SliverToBoxAdapter(
                  child: SizedBox(height: liquidNavScrollClearance(context)),
                ),
              ],
            ),
          ),
          );
      },
    );
  }
}
// =============================================================================
// SECTION 10 — NAV TAB ITEM (shared Android + iOS)
// =============================================================================

class _NavTab extends StatelessWidget {
  final _NavItem     item;
  final bool         isActive;
  final bool         isDark;
  final VoidCallback onTap;
  final int          badge;

  const _NavTab({
    required this.item,
    required this.isActive,
    required this.onTap,
    this.isDark = false,
    this.badge  = 0,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    // Solid selection "bubble": a filled chip behind the active icon.
    //   • Android (light bar): green bubble, white icon.
    //   • iOS   (dark glass):  white bubble, dark icon.
    final bubbleColor     = isDark ? AppColors.white       : AppColors.primary;
    final activeIconColor = isDark ? AppColors.primaryDark : AppColors.white;
    final inactiveColor   = isDark
        ? AppColors.white.withValues(alpha: 0.58)
        : AppColors.navInactive;
    final activeLabel     = isDark ? AppColors.white : AppColors.primary;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Icon — solid rounded bubble when active, with optional unread badge.
          Stack(
            clipBehavior: Clip.none,
            children: [
              AnimatedContainer(
                duration:  const Duration(milliseconds: 260),
                curve:     Curves.easeOutBack,
                width:     isActive ? 52 : 42,
                height:    38,
                decoration: BoxDecoration(
                  color:        isActive ? bubbleColor : Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: isActive
                      ? [
                          BoxShadow(
                            color:      bubbleColor.withValues(alpha: 0.34),
                            blurRadius: 13,
                            offset:     const Offset(0, 5),
                          ),
                        ]
                      : null,
                ),
                child: Icon(
                  item.icon,
                  size:  22,
                  color: isActive ? activeIconColor : inactiveColor,
                ),
              ),
              if (badge > 0)
                Positioned(
                  top:   -3,
                  right: -4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                    decoration: BoxDecoration(
                      color:        const Color(0xFFE53935),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                    child: Text(
                      badge > 99 ? '99+' : '$badge',
                      style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontSize:   9,
                        fontWeight: FontWeight.w800,
                        color:      Colors.white,
                        height:     1.0,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),

          const SizedBox(height: 5),

          // Label — ellipsis, centered; works for both RTL and LTR text.
          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 180),
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize:   11,
              fontWeight: isActive ? FontWeight.w800 : FontWeight.w500,
              color:      isActive ? activeLabel : inactiveColor,
              height:     1.0,
            ),
            child: Text(
              _navLabel(item.label, l10n),
              maxLines:  1,
              overflow:  TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// SECTION 11 — ANDROID & iOS NAV BARS
// =============================================================================

class _AndroidNav extends StatelessWidget {
  final int              currentIndex;
  final ValueChanged<int> onTap;
  final int              unreadNotifCount;

  const _AndroidNav({
    required this.currentIndex,
    required this.onTap,
    this.unreadNotifCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color:        AppColors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
        boxShadow: [
          BoxShadow(
            color:      AppColors.primary.withValues(alpha: 0.10),
            blurRadius: 18,
            offset:     const Offset(0, -4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 76,
            child: Row(
              children: List.generate(
                _kNavItems.length,
                (i) => Expanded(
                  child: _NavTab(
                    item:     _kNavItems[i],
                    isActive: currentIndex == i,
                    onTap:    () => onTap(i),
                    badge:    i == 1 ? unreadNotifCount : 0,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// iOS liquid-pill height — single source of truth, shared with the scroll-
// clearance helper below so tab pages can stay in sync with it without
// duplicating the number.
const double kLiquidNavHeight = 66.0;

/// Bottom scroll-padding a tab's own scrollable should add to its trailing
/// edge so content sitting at the very end (a button, the last list item...)
/// can be scrolled clear of the floating liquid pill instead of staying
/// permanently hidden behind it. Safe to call unconditionally regardless of
/// which nav style is active — on the classic bar, Scaffold's own
/// bottomNavigationBar already reserves its space, so this just adds a
/// little extra (harmless) scroll room past the natural end there.
double liquidNavScrollClearance(BuildContext context) =>
    kLiquidNavHeight + MediaQuery.of(context).padding.bottom + 26;

class _IOSNav extends StatelessWidget {
  final int              currentIndex;
  final ValueChanged<int> onTap;
  final int              unreadNotifCount;

  const _IOSNav({
    required this.currentIndex,
    required this.onTap,
    this.unreadNotifCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    // Sits a bit below the home-indicator safe area (not flush against it,
    // not floating far above it either).
    final bot = MediaQuery.of(context).padding.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(18, 0, 18, bot - 6),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        // iOS-26 "Liquid Glass" approximation: a real backdrop blur behind a
        // translucent fill, with a bright edge highlight. Renders as frosted
        // glass over whatever content scrolls beneath it.
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
          child: Container(
            height: kLiquidNavHeight,
            decoration: BoxDecoration(
              color:        AppColors.primaryDark.withValues(alpha: 0.62),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                color: AppColors.white.withValues(alpha: 0.18),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color:      AppColors.primary.withValues(alpha: 0.28),
                  blurRadius: 26,
                  offset:     const Offset(0, 12),
                ),
              ],
            ),
            child: Row(
              children: List.generate(
                _kNavItems.length,
                (i) => Expanded(
                  child: _NavTab(
                    item:     _kNavItems[i],
                    isActive: currentIndex == i,
                    onTap:    () => onTap(i),
                    badge:    i == 1 ? unreadNotifCount : 0,
                    isDark:   true,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// SECTION 12 — PLACEHOLDER TAB
// =============================================================================

class _PlaceholderTab extends StatelessWidget {
  final String   title;
  final IconData icon;
  const _PlaceholderTab({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return SafeArea(
      bottom: false,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 52, color: AppColors.primary.withOpacity(0.28)),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: _kSubHeaderStyle,
            ),
            const SizedBox(height: 8),
            Text(l10n.comingSoon, textAlign: TextAlign.center, style: _kBodyStyle),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// SECTION 13 — HOME PAGE (root widget)
// =============================================================================

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  Widget _tabBody(int index, HomeState state) {
    switch (index) {
      case 0: return const _HomeBody();
      case 1: return const NotificationsPage();
      case 2: return CommunityPage(
          countryCode:   state.userCountryCode,
          countryFlag:   state.userCountryFlag,
          countryNameAr: state.userCountryNameAr,
          countryNameEn: state.userCountryNameEn,
        );
      case 3: return const SettingsPage();
      case 4: return const PrayerTimesPage();
      case 5: return const StudentGuidePage();
      default: return const _HomeBody();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (ctx) => HomeCubit(ctx.read<RoomStatusCubit>())),
        // NotifCubit is hoisted here so the nav badge stays in sync with the
        // NotificationsPage without requiring inter-cubit communication.
        BlocProvider(create: (_) => NotifCubit()),
      ],
      child: BlocListener<HomeCubit, HomeState>(
        // Fires exactly once per HomePage lifetime, the moment userId first
        // populates (async /auth/me fetch resolving) — never again after,
        // even though HomeState keeps changing for unrelated reasons (room
        // list refreshing, tab switches, ...).
        listenWhen: (previous, current) =>
            previous.userId.isEmpty && current.userId.isNotEmpty,
        listener: (ctx, state) {
          final extra = GoRouterState.of(ctx).extra;
          final justRegistered =
              extra is Map && extra['justRegistered'] == true;
          if (justRegistered) {
            showBioPromptSheet(ctx, userId: state.userId);
          }
        },
        child: BlocBuilder<HomeCubit, HomeState>(
        builder: (ctx, state) {
          final cubit = ctx.read<HomeCubit>();
          final usesLiquidPill =
              _isIOS && state.iosNavStyle == NavStyleSetting.liquid;

          return BlocSelector<NotifCubit, NotifState, int>(
            selector: (s) => s.unreadCount,
            builder: (ctx2, unreadNotifCount) {
              return AnnotatedRegion<SystemUiOverlayStyle>(
                // Light Android system nav bar to match the app background on
                // every main tab (home / notifications / community / settings /
                // prayer / guide). Re-applied every frame so it always wins.
                value: const SystemUiOverlayStyle(
                  systemNavigationBarColor:          AppColors.background,
                  systemNavigationBarIconBrightness: Brightness.dark,
                  systemNavigationBarDividerColor:   AppColors.background,
                  statusBarColor:                    Colors.transparent,
                  statusBarIconBrightness:           Brightness.dark,
                ),
                child: Scaffold(
                backgroundColor: AppColors.background,
                // iOS defaults to the floating "liquid glass" pill, drawn inside
                // the body Stack so content blurs through it while scrolling.
                // If the user picked the classic style in Settings (or on
                // Android, always), the flat bar goes through the normal
                // bottomNavigationBar slot instead — same as before.
                bottomNavigationBar: usesLiquidPill
                    ? null
                    : _AndroidNav(
                        currentIndex:     state.navIndex,
                        onTap:            cubit.setNavIndex,
                        unreadNotifCount: unreadNotifCount,
                      ),
                body: Stack(
                  children: [
                    // Tab content deliberately extends to the true bottom of
                    // the screen — NOT padded short of the pill — so the
                    // pill's BackdropFilter has real, live content to blur as
                    // it scrolls past underneath (that's the whole "liquid
                    // glass" effect; padding the content away from it here
                    // would leave the glass blurring empty space, which just
                    // reads as a flat, opaque block instead of translucent).
                    // Reachability is instead handled per-tab, as trailing
                    // scroll padding on each tab's own scrollable — see
                    // kLiquidNavScrollClearance.
                    AnimatedSwitcher(
                      duration:       const Duration(milliseconds: 200),
                      switchInCurve:  Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      transitionBuilder: (child, anim) => FadeTransition(
                        opacity: anim,
                        child: child,
                      ),
                      child: KeyedSubtree(
                        key:   ValueKey(state.navIndex),
                        child: _tabBody(state.navIndex, state),
                      ),
                    ),
                    // iOS floating pill nav
                    if (usesLiquidPill)
                      Positioned(
                        bottom: 0, left: 0, right: 0,
                        child: _IOSNav(
                          currentIndex:     state.navIndex,
                          onTap:            cubit.setNavIndex,
                          unreadNotifCount: unreadNotifCount,
                        ),
                      ),
                  ],
                ),
              ),
              );
            },
          );
        },
      ),
      ),
    );
  }
}


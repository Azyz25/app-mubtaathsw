// =============================================================================
// MUBTAATH APP — COMMUNITY PAGE  (Refactored — Read-Only / RTL)
// =============================================================================
// File Path  : lib/features/community/presentation/pages/community_page.dart
// Design Ref : تطبيق_مبتعث.pdf — Page 14
// State Mgmt : CommunityCubit
//
// CHANGES IN THIS REFACTOR:
//   ① _CommunitySearchBar  → kept identical (single clean input, matches Home)
//   ② Header               → "مجتمع بريطانيا" RIGHT | badge LEFT (RTL-correct)
//   ③ _FilterChips         → reverse:true + correct RTL padding
//   ④ _CommunityRoomCard   → host name/avatar row REMOVED; title + listeners only
//   ⑤ _CreateRoomFab       → REMOVED entirely (page is read-only)
//   ⑥ CommunityPage        → BlocProvider + Directionality(rtl) wrapping
//
// Brand: Primary #305544 | Secondary #B19369 | BG #F9F7F5
// Font : Cairo (titles) | Tajawal (hints/labels)
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mubtaath/core/l10n/app_localizations.dart';
import 'package:mubtaath/core/services/dio_client.dart';
import 'package:mubtaath/core/utils/debug_log.dart';
import 'package:mubtaath/core/theme/app_colors.dart';
import 'package:mubtaath/core/widgets/mubtaath_refresh.dart';
import 'package:mubtaath/core/bloc/room_status_cubit.dart';
import 'package:mubtaath/core/widgets/shared_widgets.dart';
import 'package:mubtaath/home_page.dart' show liquidNavScrollClearance;

// =============================================================================
// SECTION 1 — COMMUNITY ROOM MODEL
// =============================================================================

/// A dynamic, admin-managed topic fetched from `GET /topics`. Drives the
/// horizontal filter tabs at the top of the community screen.
class RoomTopic {
  final int    id;
  final String nameAr;
  final String nameEn;

  const RoomTopic({required this.id, required this.nameAr, required this.nameEn});

  factory RoomTopic.fromJson(Map<String, dynamic> j) => RoomTopic(
        id:     (j['id'] as num?)?.toInt() ?? 0,
        nameAr: j['nameAr'] as String? ?? j['name_ar'] as String? ?? '',
        nameEn: j['nameEn'] as String? ?? j['name_en'] as String? ?? '',
      );

  String label(String lang) =>
      lang == 'ar' ? nameAr : (nameEn.isNotEmpty ? nameEn : nameAr);
}

class CommunityRoom implements RoomCardData {
  @override
  final String       id;
  final String       titleAr;
  final String       titleEn;
  final String       hostName;   // kept in model for future API use
  final String       hostAvatar; // kept in model for future API use
  @override
  final String       imageUrl;
  @override
  final int          listenerCount;
  final String       country;
  final String       countryFlag;
  /// Linked dynamic topic id — null when the room has no managed topic.
  /// Drives the dynamic filter tabs (replaces the old hardcoded category).
  final int?         topicId;
  @override
  final bool         isLive;

  const CommunityRoom({
    required this.id,
    required this.titleAr,
    required this.titleEn,
    required this.hostName,
    required this.hostAvatar,
    required this.imageUrl,
    required this.listenerCount,
    required this.country,
    required this.countryFlag,
    required this.topicId,
    this.isLive = true,
  });

  @override
  String localizedTitle(String lang) => lang == 'ar' ? titleAr : titleEn;

  factory CommunityRoom.fromJson(Map<String, dynamic> j) => CommunityRoom(
    id:            j['id']            as String? ?? '',
    titleAr:       j['titleAr']       as String? ?? '',
    titleEn:       j['titleEn']       as String? ?? '',
    hostName:      j['hostName']      as String? ?? '',
    hostAvatar:    j['hostAvatar']    as String? ?? '',
    imageUrl:      j['imageUrl']      as String? ?? '',
    listenerCount: j['listenerCount'] as int?    ?? 0,
    country:       j['countryFlag']   as String? ?? '',
    countryFlag:   j['countryFlag']   as String? ?? '',
    topicId:       (j['topicId'] as num?)?.toInt() ??
                   (j['topic_id'] as num?)?.toInt(),
    isLive:        j['isLive']        as bool?   ?? false,
  );
}

// =============================================================================
// SECTION 2 — COMMUNITY STATE
// =============================================================================

class CommunityState {
  final List<CommunityRoom> allRooms;
  final List<CommunityRoom> filteredRooms;
  /// Dynamic topics fetched from the API — the source of the filter tabs.
  final List<RoomTopic>     topics;
  /// Selected topic id, or null for the "All" tab.
  final int?                activeTopicId;
  final String              searchQuery;
  final bool                isLoading;
  final bool                hasError;
  final String              countryFlag;
  final String              countryNameAr;
  final String              countryNameEn;

  const CommunityState({
    this.allRooms       = const [],
    this.filteredRooms  = const [],
    this.topics         = const [],
    this.activeTopicId,
    this.searchQuery    = '',
    this.isLoading      = true,
    this.hasError       = false,
    this.countryFlag    = '',
    this.countryNameAr  = '',
    this.countryNameEn  = '',
  });

  CommunityState copyWith({
    List<CommunityRoom>? allRooms,
    List<CommunityRoom>? filteredRooms,
    List<RoomTopic>?     topics,
    String?              searchQuery,
    bool?                isLoading,
    bool?                hasError,
    String?              countryFlag,
    String?              countryNameAr,
    String?              countryNameEn,
    // Object? sentinel so callers can reset the filter to "All" (null).
    Object?              activeTopicId = _keep,
  }) =>
      CommunityState(
        allRooms:       allRooms       ?? this.allRooms,
        filteredRooms:  filteredRooms  ?? this.filteredRooms,
        topics:         topics         ?? this.topics,
        activeTopicId:  activeTopicId == _keep
            ? this.activeTopicId
            : activeTopicId as int?,
        searchQuery:    searchQuery    ?? this.searchQuery,
        isLoading:      isLoading      ?? this.isLoading,
        hasError:       hasError       ?? this.hasError,
        countryFlag:    countryFlag    ?? this.countryFlag,
        countryNameAr:  countryNameAr  ?? this.countryNameAr,
        countryNameEn:  countryNameEn  ?? this.countryNameEn,
      );
}

// Sentinel so copyWith can tell "not passed" apart from "set to null (All)".
const _keep = Object();

// =============================================================================
// SECTION 3 — COMMUNITY CUBIT
// =============================================================================

class CommunityCubit extends Cubit<CommunityState> {
  final String _countryCode;
  final RoomStatusCubit _statusCubit;

  CommunityCubit({
    required RoomStatusCubit statusCubit,
    required String countryCode,
    required String countryFlag,
    required String countryNameAr,
    required String countryNameEn,
  })  : _countryCode  = countryCode,
        _statusCubit  = statusCubit,
        super(CommunityState(
          countryFlag:   countryFlag,
          countryNameAr: countryNameAr,
          countryNameEn: countryNameEn,
          isLoading:     true,
        )) {
    _load();
  }

  /// Public entry point for pull-to-refresh.
  Future<void> reload() => _load();

  Future<void> _load() async {
    emit(state.copyWith(isLoading: true, hasError: false));
    try {
      // Topics and rooms in parallel — the filter tabs are now database-driven.
      final results = await Future.wait([
        appDio.get('/topics'),
        appDio.get('/rooms', queryParameters: {
          'status': 'active',
          'country_code': _countryCode,
        }),
      ]);

      final topicData = results[0].data['data'] as List<dynamic>? ?? [];
      final topics = topicData
          .map((e) => RoomTopic.fromJson(e as Map<String, dynamic>))
          .toList();

      final roomData = results[1].data['data'] as List<dynamic>? ?? [];
      final rooms = roomData
          .map((e) => CommunityRoom.fromJson(e as Map<String, dynamic>))
          .toList();

      emit(state.copyWith(
        isLoading:     false,
        topics:        topics,
        allRooms:      rooms,
        filteredRooms: rooms,
      ));
      _statusCubit.seedCounts({for (final r in rooms) r.id: r.listenerCount});
    } catch (e) {
      logDebug('[CommunityCubit] fetch error: $e');
      emit(state.copyWith(isLoading: false, hasError: true));
    }
  }

  /// Applies the current topic filter + search query against allRooms.
  /// [topicId] null means the "All" tab.
  List<CommunityRoom> _applyFilters(int? topicId, String query) {
    final base = topicId == null
        ? state.allRooms
        : state.allRooms.where((r) => r.topicId == topicId).toList();

    final q = query.trim().toLowerCase();
    if (q.isEmpty) return base;
    return base
        .where((r) =>
            r.titleAr.toLowerCase().contains(q) ||
            r.titleEn.toLowerCase().contains(q))
        .toList();
  }

  void setTopic(int? topicId) {
    emit(state.copyWith(
      activeTopicId: topicId,
      filteredRooms: _applyFilters(topicId, state.searchQuery),
    ));
  }

  void search(String query) {
    emit(state.copyWith(
      searchQuery:   query,
      filteredRooms: _applyFilters(state.activeTopicId, query),
    ));
  }

  void clearSearch() => emit(state.copyWith(
        searchQuery:   '',
        filteredRooms: _applyFilters(state.activeTopicId, ''),
      ));
}



// =============================================================================
// SECTION 5 — FILTER CHIP ROW  (RTL — starts from right)
// =============================================================================

/// One filter tab. id == null is the "All" tab.
class _TopicTab {
  final int?   id;
  final String label;
  const _TopicTab({required this.id, required this.label});
}

class _FilterChips extends StatelessWidget {
  final List<RoomTopic>   topics;
  final int?              activeTopicId;
  final ValueChanged<int?> onSelect;

  const _FilterChips({
    required this.topics,
    required this.activeTopicId,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final lang = Localizations.localeOf(context).languageCode;

    // "All" first, then one tab per dynamic topic from the API.
    final tabs = <_TopicTab>[
      _TopicTab(id: null, label: l10n.filterAll),
      ...topics.map((t) => _TopicTab(id: t.id, label: t.label(lang))),
    ];

    return Align(
      alignment: AlignmentDirectional.centerStart, // يربط القائمة كاملة باليمين
      child: SizedBox(
        height: 40,
        child: ListView.separated(
          shrinkWrap: true,
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          itemCount: tabs.length,
          separatorBuilder: (_, __) => const SizedBox(width: 10),
          itemBuilder: (_, i) {
            // نعكس الاندكس يدوياً عشان نبدأ من "الكل" باليمين
            final tab      = tabs[tabs.length - 1 - i];
            final isActive = tab.id == activeTopicId;

            return GestureDetector(
              onTap: () => onSelect(tab.id),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                decoration: BoxDecoration(
                  color: isActive ? AppColors.primary : AppColors.surface,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: isActive
                        ? AppColors.primary
                        : AppColors.primary.withValues(alpha: 0.12),
                    width: 1.2,
                  ),
                ),
                child: Center(
                  child: Text(
                    tab.label,
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize:   13,
                      fontWeight: isActive ? FontWeight.bold : FontWeight.w600,
                      color: isActive
                          ? AppColors.surface
                          : AppColors.primary.withValues(alpha: 0.7),
                    ),
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


// =============================================================================
// SECTION 6 — COMMUNITY ROOM CARD  (Read-only — no host section)
// =============================================================================



// =============================================================================
// SECTION 8 — COMMUNITY PAGE (entry point)
// =============================================================================

/// Entry point for the Community tab.
/// BlocProvider + Directionality(rtl) are both here so every descendant
/// widget has access to both the cubit and the correct text direction.
class CommunityPage extends StatelessWidget {
  final String countryCode;
  final String countryFlag;
  final String countryNameAr;
  final String countryNameEn;

  const CommunityPage({
    super.key,
    required this.countryCode,
    required this.countryFlag,
    required this.countryNameAr,
    required this.countryNameEn,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (ctx) => CommunityCubit(
        statusCubit:   ctx.read<RoomStatusCubit>(),
        countryCode:   countryCode,
        countryFlag:   countryFlag,
        countryNameAr: countryNameAr,
        countryNameEn: countryNameEn,
      ),
      child: const Scaffold(
        backgroundColor: AppColors.background,
        // No FAB — page is read-only
        body: _CommunityView(),
      ),
    );
  }
}

// =============================================================================
// SECTION 9 — _CommunityView  (main scrollable body)
// =============================================================================

class _CommunityView extends StatelessWidget {
  const _CommunityView();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CommunityCubit, CommunityState>(
      builder: (context, state) {
        final cubit = context.read<CommunityCubit>();
        final l10n  = AppLocalizations.of(context)!;

        return SafeArea(
          bottom: false,
          child: MubtaathRefresh(
            onRefresh: () => cubit.reload(),
            child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            slivers: [

              // ── 1. Header ────────────────────────────────────────────────
              SliverToBoxAdapter(
                child: SharedHeader(
                  title: l10n.communityTitle(
                    Localizations.localeOf(context).languageCode == 'ar'
                        ? state.countryNameAr
                        : state.countryNameEn,
                  ),
                  trailing: [
                    Text(state.countryFlag, style: const TextStyle(fontSize: 22)),
                    if (!state.isLoading) ...[
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color:        AppColors.primary.withValues(alpha: 0.09),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          l10n.roomsCount(state.filteredRooms.length),
                          style: const TextStyle(
                            fontFamily: 'Cairo',
                            fontSize:   12,
                            fontWeight: FontWeight.w700,
                            color:      AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 16)),

              // ── 2. Search Bar ─────────────────────────────────────────────


SliverToBoxAdapter(
  child: Padding(
    padding: const EdgeInsets.symmetric(horizontal: 20),
    child: AppSearchBar(
      hintText: l10n.communitySearchHint,
      onChanged: (val) => cubit.search(val),
      onClear: cubit.clearSearch,
    ),
  ),
),

// ── المارجن السفلي (عشان ما يلزق في اللي تحته) ──
const SliverToBoxAdapter(child: SizedBox(height: 24)), 


          
          
          
          
              // ── 3. Filter Chips (dynamic topics, RTL — starts from right) ─
              SliverToBoxAdapter(
                child: _FilterChips(
                  topics:        state.topics,
                  activeTopicId: state.activeTopicId,
                  onSelect:      cubit.setTopic,
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 16)),

              // ── 4. Room List / Loading / Empty ────────────────────────────
              if (state.isLoading)
                const SliverFillRemaining(child: CoreLoadingIndicator())
              else if (state.hasError)
                SliverFillRemaining(
                  child: CoreEmptyState(
                    icon:     LucideIcons.wifiOff,
                    title:    l10n.genericError,
                    subtitle: l10n.noRoomsAvailable,
                  ),
                )
              else if (state.filteredRooms.isEmpty)
                SliverFillRemaining(
                  // Two very different empty cases — keep them visually
                  // distinct so an empty list never reads as a frozen screen:
                  //  • a search that matched nothing, vs
                  //  • genuinely no active rooms right now (all closed).
                  child: state.searchQuery.isNotEmpty
                      ? CoreEmptyState(
                          icon:     LucideIcons.searchX,
                          title:    l10n.noResults,
                          subtitle: l10n.noResultsFor(state.searchQuery),
                        )
                      : CoreEmptyState(
                          icon:     LucideIcons.micOff,
                          title:    l10n.noActiveRoomsTitle,
                          subtitle: l10n.noActiveRoomsHint,
                        ),
                )
              else
           SliverPadding(
  padding: const EdgeInsets.symmetric(horizontal: 20),
  sliver: SliverList(
    delegate: SliverChildBuilderDelegate(
      (ctx, i) {
        // 1. المسافات بين الكروت
        if (i.isOdd) return const SizedBox(height: 14);

        // 2. حساب رقم العنصر (Index)
        final index = i ~/ 2;
        
        // 3. تأكد إن الاندكس ما يطلع برا طول القائمة
        if (index >= state.filteredRooms.length) return const SizedBox();

        final room = state.filteredRooms[index];

        // 4. هنا الـ return الصح داخل الدالة
        return CommunityRoomCard(
          room: room,
          onTap: () => ctx.push('/room/${room.id}'),
        );
      },
      // تذكر تضرب العدد في 2 وتنقص 1 عشان السبيسرات
      childCount: state.filteredRooms.isEmpty ? 0 : state.filteredRooms.length * 2 - 1,
    ),
  ),
),
              // Bottom padding so last card clears the nav bar
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
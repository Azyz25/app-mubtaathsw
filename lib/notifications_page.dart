// =============================================================================
// MUBTAATH — NOTIFICATIONS SCREEN
// =============================================================================
// File  : lib/features/notifications/presentation/pages/notifications_page.dart
//
// Architecture note:
//   NotifCubit is provided by the ancestor HomePage (not by this page).
//   This allows the nav badge to reflect live unread count.
//
// DESIGN SYSTEM:
//   Background    : Color(0xFFF8F9FA)
//   Card bg       : Colors.white
//   Card radius   : BorderRadius.circular(16)
//   Card shadow   : BoxShadow(black 3%, blur 10, offset (0,4))
//   Card border   : Border.all(black 5%)
//   H-padding     : EdgeInsets.symmetric(horizontal: 20)
//   Item spacing  : SizedBox(height: 12)
//   Heading font  : Cairo Bold   #305544
//   Body font     : Tajawal Med  #707070
// =============================================================================

import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:mubtaath/core/theme/app_colors.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mubtaath/core/l10n/app_localizations.dart';
import 'package:mubtaath/core/services/dio_client.dart';
import 'package:mubtaath/core/services/reverb_service.dart';
import 'package:mubtaath/core/widgets/mubtaath_refresh.dart';
import 'package:mubtaath/core/widgets/shared_widgets.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ROUTE WHITELIST
// ─────────────────────────────────────────────────────────────────────────────
const _kAllowedRoutePrefixes = {
  '/room/',
  '/home',
  '/profile',
  '/notifications',
  '/student-guide',
  '/prayer-times',
  '/qibla',
  '/audio-room/',
  '/support',
};

bool _isSafeRoute(String? route) {
  if (route == null || route.isEmpty) return false;
  return _kAllowedRoutePrefixes.any(route.startsWith);
}

// ─────────────────────────────────────────────────────────────────────────────
// DESIGN TOKENS
// ─────────────────────────────────────────────────────────────────────────────
abstract class _D {
  static const Color scaffoldBg   = Color(0xFFF8F9FA);
  static const Color primary      = Color(0xFF305544);
  static const Color secondary    = Color(0xFFB19369);
  static const Color cardBg       = Colors.white;
  static const Color cardShadow   = Color(0x08000000);
  static const Color cardBorder   = Color(0x0D000000);
  static const Color heading      = Color(0xFF305544);
  static const Color body         = Color(0xFF707070);
  static const Color bodyLight    = Color(0xFFAAAAAA);
  static const Color unreadDot    = Color(0xFF305544);
  // Category-specific accent colours
  static const Color blue         = Color(0xFF2563EB);
  static const Color purple       = Color(0xFF7C3AED);
  static const Color muted        = Color(0xFF6B7280);
  static const double hPad        = 20.0;
  static const double vPad        = 16.0;
  static const double itemGap     = 12.0;
  static const double cardRadius  = 16.0;
  static const double sideBorder  = 4.0;
}

// ─────────────────────────────────────────────────────────────────────────────
// NOTIFICATION TYPE
// ─────────────────────────────────────────────────────────────────────────────
enum NotifType {
  room, system, alert, embassy, message, update, feature, maintenance,
  // Targeted in-app notification types from admin actions
  supportReply, statusChange, warning, ban,
}

extension NotifTypeX on NotifType {
  Color get borderColor => switch (this) {
    NotifType.alert       => _D.secondary,
    NotifType.embassy     => _D.secondary,
    NotifType.update      => _D.blue,
    NotifType.feature     => _D.purple,
    NotifType.maintenance => _D.muted,
    NotifType.warning     => _D.secondary,
    NotifType.ban         => AppColors.error,
    NotifType.supportReply || NotifType.statusChange => _D.primary,
    _                     => _D.primary,
  };

  Color get iconBg => borderColor.withValues(alpha: 0.10);

  IconData get icon => switch (this) {
    NotifType.room         => LucideIcons.barChart2,
    NotifType.system       => LucideIcons.info,
    NotifType.alert        => LucideIcons.alertCircle,
    NotifType.message      => LucideIcons.messageCircle,
    NotifType.embassy      => LucideIcons.landmark,
    NotifType.update       => LucideIcons.refreshCw,
    NotifType.feature      => LucideIcons.sparkles,
    NotifType.maintenance  => LucideIcons.wrench,
    NotifType.supportReply => LucideIcons.messageSquare,
    NotifType.statusChange => LucideIcons.checkCircle,
    NotifType.warning      => LucideIcons.alertTriangle,
    NotifType.ban          => LucideIcons.shieldOff,
  };
}

// ─────────────────────────────────────────────────────────────────────────────
// NOTIFICATION MODEL
// ─────────────────────────────────────────────────────────────────────────────
class NotifModel {
  final String    id;
  final NotifType type;
  final String    titleAr;
  final String    titleEn;
  final String    bodyAr;
  final String    bodyEn;
  final DateTime  sentAt;
  final bool      isRead;
  final bool      isFeatured;
  final String?   routeOnTap;
  final String?   imageUrl;
  // In-app targeted notification fields (from notificationType + relatedId)
  final String?   notificationType;
  final String?   relatedId;

  const NotifModel({
    required this.id,
    required this.type,
    required this.titleAr,
    required this.titleEn,
    required this.bodyAr,
    required this.bodyEn,
    required this.sentAt,
    this.isRead          = false,
    this.isFeatured      = false,
    this.routeOnTap,
    this.imageUrl,
    this.notificationType,
    this.relatedId,
  });

  String localizedTitle(String lang) => lang == 'ar' ? titleAr : titleEn;
  String localizedBody(String lang)  => lang == 'ar' ? bodyAr  : bodyEn;

  NotifModel markRead() => NotifModel(
        id: id, type: type,
        titleAr: titleAr, titleEn: titleEn,
        bodyAr:  bodyAr,  bodyEn:  bodyEn,
        sentAt:           sentAt,
        isRead:           true,
        isFeatured:       isFeatured,
        routeOnTap:       routeOnTap,
        imageUrl:         imageUrl,
        notificationType: notificationType,
        relatedId:        relatedId,
      );

  factory NotifModel.fromApi(Map<String, dynamic> j) {
    final rawSent = j['sentAt']?.toString() ?? j['createdAt']?.toString();
    final rawRead = j['readAt']?.toString();
    final sentAt  = rawSent != null
        ? DateTime.tryParse(rawSent) ?? DateTime.now()
        : DateTime.now();
    final isRead         = rawRead != null;
    final notifType      = j['notificationType']?.toString();
    final relatedId      = j['relatedId']?.toString();

    return NotifModel(
      id:               (j['id'] ?? '').toString(),
      type:             _resolveType(notifType, j['category']?.toString()),
      titleAr:          (j['title'] ?? '').toString(),
      titleEn:          (j['title'] ?? '').toString(),
      bodyAr:           (j['body']  ?? '').toString(),
      bodyEn:           (j['body']  ?? '').toString(),
      sentAt:           sentAt,
      isRead:           isRead,
      isFeatured:       false,
      routeOnTap:       _deriveRoute(notifType),
      imageUrl:         j['imageUrl']?.toString(),
      notificationType: notifType,
      relatedId:        relatedId,
    );
  }

  // Derive a route from the machine-readable notificationType.
  // Support-related types all go to the support page (history tab).
  static String? _deriveRoute(String? notifType) => switch (notifType) {
    'support_reply' || 'status_change' || 'warning' || 'ban' => '/support',
    _ => null,
  };

  // Pick the correct NotifType enum from notificationType first,
  // then fall back to the category string for broadcast notifications.
  static NotifType _resolveType(String? notifType, String? category) =>
      switch (notifType) {
        'support_reply'  => NotifType.supportReply,
        'status_change'  => NotifType.statusChange,
        'warning'        => NotifType.warning,
        'ban'            => NotifType.ban,
        _ => switch (category) {
          'room'        => NotifType.room,
          'alert'       => NotifType.alert,
          'embassy'     => NotifType.embassy,
          'message'     => NotifType.message,
          'update'      => NotifType.update,
          'feature'     => NotifType.feature,
          'maintenance' => NotifType.maintenance,
          _             => NotifType.system,
        },
      };
}

// ─────────────────────────────────────────────────────────────────────────────
// STUB DATA  (shown on network failure so screen is never blank)
// ─────────────────────────────────────────────────────────────────────────────
final _kStubNotifs = <NotifModel>[
  NotifModel(
    id: 'n1', type: NotifType.room,
    titleAr: 'روم جديد', titleEn: 'New Room',
    bodyAr:  'بدأ الآن روم جديد اطلع عليه !',
    bodyEn:  'A new room has just started — check it out!',
    sentAt:     DateTime.now().subtract(const Duration(minutes: 5)),
    routeOnTap: '/room/r1',
  ),
  NotifModel(
    id: 'n2', type: NotifType.system,
    titleAr: 'مرحباً بك', titleEn: 'Welcome',
    bodyAr:  'أهلا بك في تطبيق مبتعث سعدنا بلقائك !',
    bodyEn:  'Welcome to Mubtaath! Great to have you here.',
    sentAt: DateTime.now().subtract(const Duration(hours: 1)),
    isRead: true,
  ),
  NotifModel(
    id: 'n3', type: NotifType.alert,
    titleAr: 'تحديث مهم', titleEn: 'Important Update',
    bodyAr:  'هناك تحديث جديد للتطبيق الرجاء التحديث',
    bodyEn:  'A new app update is available. Please update now.',
    sentAt:     DateTime.now().subtract(const Duration(hours: 3)),
    isFeatured: true,
  ),
  NotifModel(
    id: 'n4', type: NotifType.embassy,
    titleAr: 'أخبار السفارة', titleEn: 'Embassy News',
    bodyAr:  'تنبيه من سفارة المملكة في لندن بخصوص تجديد الإقامة',
    bodyEn:  'Notice from the Saudi Embassy in London regarding residence renewal.',
    sentAt: DateTime.now().subtract(const Duration(days: 1)),
  ),
  NotifModel(
    id: 'n5', type: NotifType.message,
    titleAr: 'رسالة جديدة', titleEn: 'New Message',
    bodyAr:  'محمد أرسل رسالة في روم تجارب المبتعثين',
    bodyEn:  'Mohammed sent a message in the Scholarship Experiences room.',
    sentAt:     DateTime.now().subtract(const Duration(days: 1, hours: 2)),
    routeOnTap: '/room/r1',
  ),
  NotifModel(
    id: 'n6', type: NotifType.system,
    titleAr: 'تذكير', titleEn: 'Reminder',
    bodyAr:  'لديك 3 رومات نشطة في دولتك هذا الأسبوع',
    bodyEn:  'You have 3 active rooms in your country this week.',
    sentAt: DateTime.now().subtract(const Duration(days: 3)),
    isRead: true,
  ),
];

// ─────────────────────────────────────────────────────────────────────────────
// STATE + CUBIT
// ─────────────────────────────────────────────────────────────────────────────
class NotifState {
  final List<NotifModel> items;
  final bool             loading;

  const NotifState({this.items = const [], this.loading = false});

  int get unreadCount => items.where((n) => !n.isRead).length;

  NotifState copyWith({List<NotifModel>? items, bool? loading}) =>
      NotifState(items: items ?? this.items, loading: loading ?? this.loading);
}

class NotifCubit extends Cubit<NotifState> {
  NotifCubit() : super(const NotifState(loading: true)) {
    _fetchThenConnect();
  }

  final _reverb = ReverbService();

  /// Fetches the initial list, then opens the WebSocket so that the
  /// real-time prepend can never clobber the REST response in a race.
  Future<void> _fetchThenConnect() async {
    await _fetch();
    if (!isClosed) _initRealTime();
  }

  void _initRealTime() {
    _reverb.onNotification = (payload) {
      // Drop admin-only notifications — regular users never see those.
      if (payload['targetType'] == 'admins_only') return;
      // Deduplicate: if the REST response already included this ID, skip it.
      final id = (payload['id'] ?? '').toString();
      if (id.isEmpty || state.items.any((n) => n.id == id)) return;
      try {
        emit(state.copyWith(items: [NotifModel.fromApi(payload), ...state.items]));
      } catch (e) {
        debugPrint('[NotifCubit] socket parse error: $e');
      }
    };
    _reverb.connect();
  }

  @override
  Future<void> close() {
    _reverb.dispose();
    return super.close();
  }

  Future<void> _fetch() async {
    try {
      final resp = await appDio.get('/notifications');
      final raw  = resp.data;
      final list = (raw is Map ? raw['data'] : null) as List<dynamic>? ?? [];

      // Parse item-by-item so one malformed entry never drops the whole list.
      // No status filtering here — the backend already filters by status;
      // 'sending' and 'delivered' items are both rendered.
      final items = <NotifModel>[];
      for (final e in list) {
        if (e is! Map<String, dynamic>) continue;
        try {
          items.add(NotifModel.fromApi(e));
        } catch (_) {
          // skip malformed item
        }
      }
      if (!isClosed) emit(NotifState(items: items));
    } on DioException catch (_) {
      if (!isClosed) emit(NotifState(items: _kStubNotifs));
    } catch (_) {
      if (!isClosed) emit(NotifState(items: _kStubNotifs));
    }
  }

  /// Pull-to-refresh — re-fetches without showing the full loading spinner.
  Future<void> refresh() => _fetch();

  /// Mark a single notification as read locally and call the backend.
  void markRead(String id) {
    emit(state.copyWith(
      items: state.items.map((n) => n.id == id ? n.markRead() : n).toList(),
    ));
    _fireRead(id);
  }

  /// Mark all unread notifications as read locally, then call the bulk endpoint.
  /// Falls back to individual calls if the bulk endpoint fails.
  Future<void> markAllRead() async {
    final unread = state.items.where((n) => !n.isRead).toList();
    if (unread.isEmpty) return;
    emit(state.copyWith(
      items: state.items.map((n) => n.markRead()).toList(),
    ));
    try {
      await appDio.post('/notifications/read-all');
    } catch (_) {
      for (final n in unread) {
        _fireRead(n.id);
      }
    }
  }

  Future<void> _fireRead(String id) async {
    try { await appDio.post('/notifications/$id/read'); } catch (_) {}
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TIME FORMATTER
// ─────────────────────────────────────────────────────────────────────────────
String _fmtTime(DateTime dt, AppLocalizations l10n) {
  final diff = DateTime.now().difference(dt);
  if (diff.inMinutes < 1)  return l10n.timeNow;
  if (diff.inMinutes < 60) return l10n.minutesAgo(diff.inMinutes);
  if (diff.inHours   < 24) return l10n.hoursAgo(diff.inHours);
  if (diff.inDays    == 1) return l10n.yesterday;
  return '${dt.day}/${dt.month}';
}

String _sectionKey(DateTime dt) {
  final diff = DateTime.now().difference(dt);
  if (diff.inDays == 0) return 'today';
  if (diff.inDays == 1) return 'yesterday';
  return 'earlier';
}

String _localizeSection(String key, AppLocalizations l10n) => switch (key) {
  'today'     => l10n.today,
  'yesterday' => l10n.yesterday,
  _           => l10n.earlier,
};

// ─────────────────────────────────────────────────────────────────────────────
// NOTIFICATION CARD
// ─────────────────────────────────────────────────────────────────────────────
class _NotifCard extends StatelessWidget {
  final NotifModel   notif;
  final VoidCallback onTap;

  const _NotifCard({required this.notif, required this.onTap});

  bool get _featured => notif.isFeatured && !notif.isRead;

  @override
  Widget build(BuildContext context) {
    final l10n       = AppLocalizations.of(context)!;
    final lang       = Localizations.localeOf(context).languageCode;
    final accent     = notif.type.borderColor;
    final bgColor    = _featured ? _D.primary    : _D.cardBg;
    final titleColor = _featured ? Colors.white  : _D.heading;
    final bodyColor  = _featured
        ? Colors.white.withValues(alpha: 0.80)
        : _D.body;
    final timeColor  = _featured
        ? Colors.white.withValues(alpha: 0.60)
        : _D.bodyLight;
    final iconBg    = _featured
        ? Colors.white.withValues(alpha: 0.15)
        : notif.type.iconBg;
    final iconColor = _featured ? Colors.white : accent;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color:        bgColor,
          borderRadius: BorderRadius.circular(_D.cardRadius),
          border: Border.all(
            color: _featured ? Colors.transparent : _D.cardBorder,
            width: 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color:      _featured
                  ? _D.primary.withValues(alpha: 0.22)
                  : _D.cardShadow,
              blurRadius: _featured ? 18 : 10,
              offset:     const Offset(0, 4),
            ),
          ],
        ),
        // Stack lets the side border fill the card height via Positioned(top/bottom)
        // without needing IntrinsicHeight (which asserts on unbounded ListView height).
        child: ClipRRect(
          borderRadius: BorderRadius.circular(_D.cardRadius),
          child: Stack(
            children: [

              // ── Content column ────────────────────────────────────────────
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [

                  // Indent content so it doesn't sit under the side border
                  Padding(
                    padding: const EdgeInsets.only(right: _D.sideBorder),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [

                          // Icon container
                          Container(
                            width:  40,
                            height: 40,
                            decoration: BoxDecoration(
                              color:        iconBg,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              notif.type.icon,
                              color: iconColor,
                              size:  20,
                            ),
                          ),

                          const SizedBox(width: 12),

                          // Title + body — Expanded prevents unbounded width
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (!notif.isRead && !_featured)
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          notif.localizedTitle(lang),
                                          style: TextStyle(
                                            fontFamily: 'Cairo',
                                            fontSize:   14,
                                            fontWeight: FontWeight.w700,
                                            color:      titleColor,
                                            height:     1.3,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Container(
                                        width: 7, height: 7,
                                        decoration: const BoxDecoration(
                                          color: _D.unreadDot,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                    ],
                                  )
                                else
                                  Text(
                                    notif.localizedTitle(lang),
                                    textAlign: TextAlign.start,
                                    style: TextStyle(
                                      fontFamily: 'Cairo',
                                      fontSize:   14,
                                      fontWeight: notif.isRead
                                          ? FontWeight.w600
                                          : FontWeight.w700,
                                      color:      titleColor,
                                      height:     1.3,
                                    ),
                                  ),

                                const SizedBox(height: 4),

                                Text(
                                  notif.localizedBody(lang),
                                  textAlign: TextAlign.start,
                                  style: TextStyle(
                                    fontFamily: 'Tajawal',
                                    fontSize:   13,
                                    fontWeight: FontWeight.w500,
                                    color:      bodyColor,
                                    height:     1.5,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(width: 12),

                          // Timestamp — top-trailing corner
                          Text(
                            _fmtTime(notif.sentAt, l10n),
                            style: TextStyle(
                              fontFamily: 'Tajawal',
                              fontSize:   11,
                              fontWeight: FontWeight.w500,
                              color:      timeColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // ── Optional image banner ─────────────────────────────────
                  if (notif.imageUrl != null && notif.imageUrl!.isNotEmpty)
                    CachedNetworkImage(
                      imageUrl: notif.imageUrl!,
                      width:    double.infinity,
                      height:   160,
                      fit:      BoxFit.cover,
                      placeholder: (_, __) => Container(
                        height: 160,
                        color:  _D.cardBorder,
                      ),
                      errorWidget: (_, __, ___) => const SizedBox.shrink(),
                    ),

                ],
              ),

              // ── Colored side border (right/start in RTL) ─────────────────
              // Positioned stretches to the Column's natural height — no IntrinsicHeight needed.
              Positioned(
                top:    0,
                bottom: 0,
                right:  0,
                child: Container(
                  width: _D.sideBorder,
                  decoration: BoxDecoration(
                    color: _featured
                        ? Colors.white.withValues(alpha: 0.30)
                        : accent,
                    borderRadius: const BorderRadius.only(
                      topRight:    Radius.circular(_D.cardRadius),
                      bottomRight: Radius.circular(_D.cardRadius),
                    ),
                  ),
                ),
              ),

            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SECTION HEADER  (Today / Yesterday / Earlier)
// ─────────────────────────────────────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: Divider(
              color:     Colors.black.withValues(alpha: 0.08),
              thickness: 1,
              endIndent: 10,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'Cairo',
              fontSize:   12,
              fontWeight: FontWeight.w700,
              color:      _D.body,
              letterSpacing: 0.3,
            ),
          ),
          Expanded(
            child: Divider(
              color:     Colors.black.withValues(alpha: 0.08),
              thickness: 1,
              indent:    10,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PAGE HEADER  (title + badge + mark-all-read button)
// ─────────────────────────────────────────────────────────────────────────────
class _PageHeader extends StatelessWidget {
  final int          unreadCount;
  final VoidCallback onMarkAll;

  const _PageHeader({required this.unreadCount, required this.onMarkAll});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(_D.hPad, _D.vPad, _D.hPad, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                AppLocalizations.of(context)!.notificationsTitle,
                style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontSize:   22,
                  fontWeight: FontWeight.w800,
                  color:      _D.heading,
                ),
              ),
              if (unreadCount > 0) ...[
                const SizedBox(width: 8),
                Container(
                  width: 22, height: 22,
                  decoration: const BoxDecoration(
                    color: _D.primary, shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '$unreadCount',
                      style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontSize:   11,
                        fontWeight: FontWeight.w700,
                        color:      Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
          if (unreadCount > 0)
            GestureDetector(
              onTap: onMarkAll,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color:        _D.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _D.primary.withValues(alpha: 0.15),
                    width: 1.0,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      AppLocalizations.of(context)!.markAllRead,
                      style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontSize:   12,
                        fontWeight: FontWeight.w600,
                        color:      _D.primary,
                      ),
                    ),
                    const SizedBox(width: 5),
                    const Icon(LucideIcons.checkCheck, color: _D.primary, size: 13),
                  ],
                ),
              ),
            )
          else
            const SizedBox.shrink(),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// NOTIFICATIONS PAGE
// NotifCubit is provided by ancestor HomePage — no BlocProvider here.
// ─────────────────────────────────────────────────────────────────────────────
class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  @override
  void initState() {
    super.initState();
    // Refresh on every page entry so the list is always up-to-date.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<NotifCubit>().refresh();
    });
  }

  static Map<String, List<NotifModel>> _group(List<NotifModel> items) {
    final Map<String, List<NotifModel>> map = {};
    for (final n in items) {
      (map[_sectionKey(n.sentAt)] ??= []).add(n);
    }
    const order = ['today', 'yesterday', 'earlier'];
    return Map.fromEntries(
      order.where(map.containsKey).map((k) => MapEntry(k, map[k]!)),
    );
  }

  static List<dynamic> _flatten(Map<String, List<NotifModel>> grouped) {
    final List<dynamic> flat = [];
    for (final entry in grouped.entries) {
      flat.add(entry.key);
      flat.addAll(entry.value);
    }
    return flat;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _D.scaffoldBg,
      body: BlocBuilder<NotifCubit, NotifState>(
        builder: (context, state) {
          final cubit = context.read<NotifCubit>();
          final l10n  = AppLocalizations.of(context)!;

          return SafeArea(
            child: Column(
              children: [
                _PageHeader(
                  unreadCount: state.unreadCount,
                  onMarkAll:   cubit.markAllRead,
                ),
                const SizedBox(height: _D.vPad),
                Expanded(
                  child: state.loading
                      ? const CoreLoadingIndicator()
                      : MubtaathRefresh(
                          onRefresh: cubit.refresh,
                          child: state.items.isEmpty
                              ? CoreEmptyState(
                                  icon:     LucideIcons.bellOff,
                                  title:    l10n.noNotifications,
                                  subtitle: l10n.noNotificationsSub,
                                )
                              : _NotifList(
                                  flat:  _flatten(_group(state.items)),
                                  cubit: cubit,
                                ),
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

// ─────────────────────────────────────────────────────────────────────────────
// NOTIFICATION LIST
// ─────────────────────────────────────────────────────────────────────────────
class _NotifList extends StatelessWidget {
  final List<dynamic> flat;
  final NotifCubit    cubit;

  const _NotifList({required this.flat, required this.cubit});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return ListView.builder(
      physics:   const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      padding:   const EdgeInsets.fromLTRB(_D.hPad, 0, _D.hPad, 32),
      itemCount: flat.length,
      itemBuilder: (ctx, i) {
        final item = flat[i];

        if (item is String) {
          return _SectionHeader(label: _localizeSection(item, l10n));
        }

        final notif = item as NotifModel;
        return Padding(
          padding: const EdgeInsets.only(bottom: _D.itemGap),
          child: _NotifCard(
            notif: notif,
            onTap: () {
              if (!notif.isRead) cubit.markRead(notif.id);
              if (_isSafeRoute(notif.routeOnTap) && ctx.mounted) {
                ctx.push(notif.routeOnTap!);
              }
            },
          ),
        );
      },
    );
  }
}

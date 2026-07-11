// lib/core/widgets/shared_widgets.dart
//
// Central barrel + extracted shared widgets.
// Single import gives access to every reusable UI primitive:
//   import 'package:mubtaath/core/widgets/shared_widgets.dart';
//
// Barrel re-exports ─────────────────────────────────────────────────────────
export 'app_search_bar.dart';

// ────────────────────────────────────────────────────────────────────────────
// All layout uses EdgeInsetsDirectional / AlignmentDirectional so widgets
// mirror correctly under both RTL (Arabic) and LTR (English) locales.
// Hardcoded TextDirection.rtl has been purged; direction is inferred from the
// ambient Locale injected by MaterialApp via flutter_localizations.
// ────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mubtaath/core/bloc/room_status_cubit.dart';
import 'package:mubtaath/core/l10n/app_localizations.dart';

// ─── Private colour constants ────────────────────────────────────────────────
abstract class _C {
  static const Color primary     = Color(0xFF305544);
  static const Color disabled    = Color(0xFF9E9E9E);
  static const Color textPrimary = Color(0xFF051C16);
  static const Color textHint    = Color(0xFFB0B0B0);
  static const Color textSub     = Color(0xFF707070);
  static const Color fieldBorder = Color(0xFFCECECE);
  static const Color divider     = Color(0xFFE0E0E0);
  static const Color error       = Color(0xFFD32F2F);
  // Shared by logout button
  static const Color logoutRed   = Color(0xFFD32F2F);
  static const Color cardBorder  = Color(0xFFE2E2E2);
}

// ════════════════════════════════════════════════════════════════════════════
// 1. CorePrimaryButton
// ════════════════════════════════════════════════════════════════════════════
class CorePrimaryButton extends StatelessWidget {
  final String         label;
  final VoidCallback?  onPressed;
  final bool           isLoading;
  final bool           isDisabled;

  const CorePrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading  = false,
    this.isDisabled = false,
  });

  bool get _isInteractive => !isLoading && !isDisabled && onPressed != null;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width:  double.infinity,
      height: 56,
      decoration: BoxDecoration(
        color:        _isInteractive ? _C.primary : _C.disabled,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap:          _isInteractive ? onPressed : null,
          borderRadius:   BorderRadius.circular(14),
          splashColor:    Colors.white.withValues(alpha: 0.15),
          highlightColor: Colors.white.withValues(alpha: 0.08),
          child: Center(
            child: isLoading
                ? const SizedBox(
                    width:  24,
                    height: 24,
                    child:  CircularProgressIndicator(
                      color:       Colors.white,
                      strokeWidth: 2.5,
                    ),
                  )
                : Text(
                    label,
                    style: const TextStyle(
                      fontFamily:    'Cairo',
                      fontSize:      16,
                      fontWeight:    FontWeight.w700,
                      color:         Colors.white,
                      letterSpacing: 0.3,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// 2. CoreTextField
//
// Directional contract:
//   • textAlign      → TextAlign.start  (follows ambient direction)
//   • textDirection  → NOT set; inferred from Localizations (purged per Task 3)
//   • suffixIcon     → renders on the trailing (left in RTL, right in LTR)
// ════════════════════════════════════════════════════════════════════════════
class CoreTextField extends StatelessWidget {
  final TextEditingController         controller;
  final String                        hintText;
  final bool                          obscureText;
  final Widget?                       suffixIcon;
  final TextInputType                 keyboardType;
  final List<TextInputFormatter>?     inputFormatters;
  final bool                          enabled;
  final String?                       errorText;
  final ValueChanged<String>?         onChanged;

  const CoreTextField({
    super.key,
    required this.controller,
    required this.hintText,
    this.obscureText    = false,
    this.suffixIcon,
    this.keyboardType   = TextInputType.text,
    this.inputFormatters,
    this.enabled        = true,
    this.errorText,
    this.onChanged,
  });

  static const _radius = 14.0;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller:      controller,
      obscureText:     obscureText,
      keyboardType:    keyboardType,
      inputFormatters: inputFormatters,
      enabled:         enabled,
      onChanged:       onChanged,
      // textAlign.start respects ambient RTL/LTR; no explicit textDirection needed
      textAlign: TextAlign.start,
      style: const TextStyle(
        fontFamily: 'Cairo',
        fontSize:   14,
        fontWeight: FontWeight.w500,
        color:      _C.textPrimary,
      ),
      decoration: InputDecoration(
        hintText:  hintText,
        hintStyle: const TextStyle(
          fontFamily: 'Tajawal',
          fontSize:   14,
          fontWeight: FontWeight.w400,
          color:      _C.textHint,
        ),
        suffixIcon: suffixIcon,
        errorText:  errorText,
        errorStyle: const TextStyle(
          fontFamily: 'Tajawal',
          fontSize:   12,
          color:      _C.error,
        ),
        filled:         true,
        fillColor:      Colors.white,
        contentPadding: const EdgeInsetsDirectional.symmetric(
          horizontal: 18,
          vertical:   18,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_radius),
          borderSide:   const BorderSide(color: _C.fieldBorder, width: 1.2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_radius),
          borderSide:   const BorderSide(color: _C.primary, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_radius),
          borderSide:   const BorderSide(color: _C.error, width: 1.2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_radius),
          borderSide:   const BorderSide(color: _C.error, width: 1.6),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_radius),
          borderSide:   const BorderSide(color: _C.divider, width: 1.2),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// 3. CoreCard
// ════════════════════════════════════════════════════════════════════════════
class CoreCard extends StatelessWidget {
  final Widget                 child;
  final EdgeInsetsGeometry?    padding;

  const CoreCard({
    super.key,
    required this.child,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width:   double.infinity,
      padding: padding ??
          const EdgeInsetsDirectional.symmetric(horizontal: 20, vertical: 24),
      decoration: const BoxDecoration(
        color:        Colors.white,
        borderRadius: BorderRadius.all(Radius.circular(16)),
        border: Border.fromBorderSide(
          BorderSide(color: Color(0x0D000000), width: 1.0),
        ),
        boxShadow: [
          BoxShadow(
            color:      Color(0x08000000),
            blurRadius: 10,
            offset:     Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}


// ════════════════════════════════════════════════════════════════════════════
// 4. AuthHeader
// ════════════════════════════════════════════════════════════════════════════
class AuthHeader extends StatelessWidget {
  final String  title;
  final String  subtitle;

  const AuthHeader({
    super.key,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontFamily: 'Cairo',
            fontSize:   26,
            fontWeight: FontWeight.w800,
            color:      _C.primary,
            height:     1.3,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontFamily: 'Tajawal',
            fontSize:   14,
            fontWeight: FontWeight.w500,
            color:      _C.textSub,
            height:     1.6,
          ),
        ),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// 5. CoreLiveBadge
//
// The label defaults to reading from AppLocalizations so it auto-translates.
// Pass an explicit [label] only when you need to override (e.g. in tests).
// ════════════════════════════════════════════════════════════════════════════
class CoreLiveBadge extends StatelessWidget {
  final String? label;
  const CoreLiveBadge({super.key, this.label});

  @override
  Widget build(BuildContext context) {
    final text = label ?? AppLocalizations.of(context)!.liveNow;
    return Container(
      padding: const EdgeInsetsDirectional.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color:        const Color(0xFF305544).withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color:      const Color(0xFF305544).withValues(alpha: 0.25),
            blurRadius: 8,
            offset:     const Offset(0, 2),
          ),
        ],
      ),
      // No hardcoded textDirection — Row respects ambient locale direction
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            text,
            style: const TextStyle(
              fontFamily: 'Cairo',
              fontSize:   11,
              fontWeight: FontWeight.w700,
              color:      Colors.white,
            ),
          ),
          const SizedBox(width: 4),
          const Icon(LucideIcons.radio, color: Colors.white, size: 10),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// 6. CoreUserAvatar
// ════════════════════════════════════════════════════════════════════════════
class CoreUserAvatar extends StatelessWidget {
  final double  size;
  final String? imageUrl;
  final bool    isLive;

  const CoreUserAvatar({
    super.key,
    required this.size,
    this.imageUrl,
    this.isLive = false,
  });

  ImageProvider? get _image {
    if (imageUrl == null) return null;
    if (imageUrl!.startsWith('assets/')) return AssetImage(imageUrl!);
    return NetworkImage(imageUrl!);
  }

  @override
  Widget build(BuildContext context) {
    final total = size + 4;
    return Stack(
      clipBehavior: Clip.none,
      alignment:    AlignmentDirectional.bottomCenter,
      children: [
        Container(
          width:  total,
          height: total,
          decoration: BoxDecoration(
            shape:  BoxShape.circle,
            color:  Colors.white,
            boxShadow: [
              BoxShadow(
                color:      const Color(0xFF305544).withValues(alpha: 0.08),
                blurRadius: 15,
                offset:     const Offset(0, 8),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(2),
            child: CircleAvatar(
              radius:          size / 2,
              backgroundImage: _image,
              backgroundColor: const Color(0xFF305544),
            ),
          ),
        ),
        if (isLive)
          const Positioned(
            bottom: -10,
            child:  CoreLiveBadge(),
          ),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// 7. CoreBackButton
//
// Icon auto-mirrors: chevronEnd points right in RTL (← back), left in LTR (→ back).
// Uses Directionality.of(context) to select the correct chevron at runtime.
// ════════════════════════════════════════════════════════════════════════════
class CoreBackButton extends StatelessWidget {
  const CoreBackButton({super.key});

  @override
  Widget build(BuildContext context) {
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    return GestureDetector(
      onTap: () => Navigator.maybePop(context),
      child: Container(
        width:  36,
        height: 36,
        decoration: BoxDecoration(
          color:        Colors.white,
          borderRadius: BorderRadius.circular(10),
          border:       Border.all(color: const Color(0xFFE2E2E2), width: 1.2),
        ),
        child: Icon(
          isRtl ? LucideIcons.chevronRight : LucideIcons.chevronLeft,
          color: const Color(0xFF051C16),
          size:  20,
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// 8. CoreSectionHeader
//
// [seeAllLabel] defaults to the localised string; override only in tests.
// Row no longer carries a hardcoded textDirection.
// ════════════════════════════════════════════════════════════════════════════
class CoreSectionHeader extends StatelessWidget {
  final String        title;
  final VoidCallback? onSeeAll;
  final String?       seeAllLabel;

  const CoreSectionHeader({
    super.key,
    required this.title,
    this.onSeeAll,
    this.seeAllLabel,
  });

  @override
  Widget build(BuildContext context) {
    final seeAll = seeAllLabel ?? AppLocalizations.of(context)!.seeAll;
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(
            fontFamily: 'Cairo',
            fontSize:   19,
            fontWeight: FontWeight.w800,
            color:      _C.primary,
          ),
        ),
        const Spacer(),
        if (onSeeAll != null)
          GestureDetector(
            onTap: onSeeAll,
            child: Text(
              seeAll,
              style: const TextStyle(
                fontFamily: 'Tajawal',
                fontSize:   13,
                fontWeight: FontWeight.w500,
                color:      _C.primary,
              ),
            ),
          ),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// 9. MubtaethCard
// ════════════════════════════════════════════════════════════════════════════
class MubtaethCard extends StatelessWidget {
  final Widget                 child;
  final EdgeInsetsGeometry?    padding;
  final double                 borderRadiusValue;

  const MubtaethCard({
    super.key,
    required this.child,
    this.padding,
    this.borderRadiusValue = 16,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width:   double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color:        Colors.white,
        borderRadius: BorderRadius.circular(borderRadiusValue),
        boxShadow: [
          BoxShadow(
            color:      const Color(0xFF305544).withValues(alpha: 0.08),
            blurRadius: 15,
            offset:     const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// 10. CoreAppBar
//
// Leading button padding uses EdgeInsetsDirectional.only(start: 16) so it
// sits on the correct side in both RTL and LTR layouts.
// ════════════════════════════════════════════════════════════════════════════
class CoreAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String         title;
  final bool           showBack;
  final Color?         backgroundColor;
  final List<Widget>?  actions;

  const CoreAppBar({
    super.key,
    required this.title,
    this.showBack       = true,
    this.backgroundColor,
    this.actions,
  });

  @override
  // 👈 تم التحديث إلى 64 ليتوافق مع الارتفاع العمودي المريح للتطبيق
  Size get preferredSize => const Size.fromHeight(64); 

  @override
  Widget build(BuildContext context) {
    return AppBar(
      toolbarHeight: 64, // 👈 إعطاء مساحة تنفس مريحة عمودياً للبار
      backgroundColor:          backgroundColor ?? const Color(0xFFF9F7F5),
      elevation:                 0,
      scrolledUnderElevation:    0,
      centerTitle:               true,
      automaticallyImplyLeading: false,
      leadingWidth: showBack ? 80 : 0, // 👈 مساحة عرض أفقية كافية تمنع انضغاط الزر نهائياً
      leading: showBack
          ? const Align(
              alignment: AlignmentDirectional.centerStart, // 👈 محاذاة ذكية للبداية (يمين بالعربي ويسار بالإنجليزي)
              child: Padding(
                padding: EdgeInsetsDirectional.only(start: 24), // 👈 مسافة جانبية أنيقة وموحدة 24 بكسل لراحة العين
                child:   CoreBackButton(),
              ),
            )
          : null,
      title: Text(
        title,
        style: const TextStyle(
          fontFamily: 'Cairo',
          fontSize:   17,
          fontWeight: FontWeight.w700,
          color:      Color(0xFF051C16),
        ),
      ),
      actions: actions,
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// 10B. SharedHeader — large page-level title with optional trailing widgets.
// Mirrors the Cairo 22 / w800 / primary style used across Community & Settings.
// ════════════════════════════════════════════════════════════════════════════
class SharedHeader extends StatelessWidget {
  final String       title;
  final bool         showBack;
  final List<Widget> trailing;

  const SharedHeader({
    super.key,
    required this.title,
    this.showBack = false,
    this.trailing = const [],
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (showBack) ...[
            const CoreBackButton(),
            const SizedBox(width: 12),
          ],
          Text(
            title,
            style: const TextStyle(
              fontFamily: 'Cairo',
              fontSize:   22,
              fontWeight: FontWeight.w800,
              color:      _C.primary,
            ),
          ),
          if (trailing.isNotEmpty) ...[
            const Spacer(),
            ...trailing,
          ],
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// 11. CoreLoadingIndicator
// ════════════════════════════════════════════════════════════════════════════
class CoreLoadingIndicator extends StatelessWidget {
  const CoreLoadingIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(
        color:       Color(0xFF305544),
        strokeWidth: 2.5,
      ),
    );
  }
}




// ════════════════════════════════════════════════════════════════════════════
// 12-A. RoomCardData
//
// Common interface implemented by RoomModel (home) and CommunityRoom
// (community). Allows CommunityRoomCard to be used in both tabs without
// knowing the concrete type, and keeps the widget API-ready.
// ════════════════════════════════════════════════════════════════════════════
abstract class RoomCardData {
  String get id;
  String get imageUrl;
  int    get listenerCount;
  bool   get isLive;
  /// Returns the room title for the given BCP-47 language code ('ar' | 'en').
  String localizedTitle(String lang);
}

// ════════════════════════════════════════════════════════════════════════════
// 12. CommunityRoomCard
//
// Directional fixes:
//   • PositionedDirectional replaces Positioned(right:) for the live badge
//   • textAlign.start replaces textAlign.right for the title
//   • CrossAxisAlignment.start on Column (start = right in RTL)
// ════════════════════════════════════════════════════════════════════════════
class CommunityRoomCard extends StatelessWidget {
  final RoomCardData room;
  final VoidCallback onTap;

  const CommunityRoomCard({super.key, required this.room, required this.onTap});

  static const double _kRadius = 22.0;

  @override
  Widget build(BuildContext context) {
    final lang = Localizations.localeOf(context).languageCode;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 130,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(_kRadius),
          boxShadow: [
            BoxShadow(
              color:      const Color(0xFF305544).withValues(alpha: 0.08),
              blurRadius: 15,
              offset:     const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(_kRadius),
          child: Stack(
            fit: StackFit.expand,
            children: [
              _RoomCardBg(url: room.imageUrl),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin:  AlignmentDirectional.topCenter,
                      end:    AlignmentDirectional.bottomCenter,
                      stops:  const [0.28, 1.0],
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.72),
                      ],
                    ),
                  ),
                ),
              ),
              // Title + listeners — aligned to directional start (right in RTL)
              PositionedDirectional(
                bottom: 14, start: 16, end: 16,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      room.localizedTitle(lang),
                      textAlign: TextAlign.start,
                      maxLines:  1,
                      overflow:  TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontSize:   15,
                        fontWeight: FontWeight.w700,
                        color:      Colors.white,
                        height:     1.3,
                      ),
                    ),
                    const SizedBox(height: 6),
                    // Unified live headcount — everyone in the room (speakers +
                    // listeners) behind a single people icon. 👥 12
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        BlocBuilder<RoomStatusCubit, RoomStatusState>(
                          buildWhen: (p, c) =>
                              p.counts[room.id] != c.counts[room.id],
                          builder: (ctx, status) => Text(
                            '${status.counts[room.id] ?? room.listenerCount}',
                            textAlign: TextAlign.start,
                            style: const TextStyle(
                              fontFamily: 'Tajawal',
                              fontSize:   13.5,
                              fontWeight: FontWeight.w700,
                              color:      Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 5),
                        const Icon(Icons.people_alt_rounded,
                            color: Colors.white, size: 16),
                      ],
                    ),
                  ],
                ),
              ),
              // Live badge — directional start corner (top-right in RTL, top-left in LTR)
              if (room.isLive)
                const PositionedDirectional(top: 10, start: 12, child: CoreLiveBadge()),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoomCardBg extends StatelessWidget {
  final String url;
  const _RoomCardBg({required this.url});

  @override
  Widget build(BuildContext context) {
    return Image.network(
      url,
      fit: BoxFit.cover,
      loadingBuilder: (_, child, p) => p == null
          ? child
          : Container(
              color: const Color(0xFF305544).withValues(alpha: 0.10),
              child: const Center(
                child: CircularProgressIndicator(
                  color: Color(0xFF305544), strokeWidth: 2,
                ),
              ),
            ),
      errorBuilder: (_, __, ___) => Container(
        color: const Color(0xFF305544).withValues(alpha: 0.12),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// 13. CoreEmptyState
// ════════════════════════════════════════════════════════════════════════════

class CoreEmptyState extends StatelessWidget {
  final IconData icon;
  final String   title;
  final String   subtitle;

  const CoreEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width:  80,
              height: 80,
              decoration: BoxDecoration(
                color:  const Color(0xFF305544).withValues(alpha: 0.08),
                shape:  BoxShape.circle,
              ),
              child: Icon(icon, size: 36, color: const Color(0xFF305544)),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Cairo',
                fontSize:   18,
                fontWeight: FontWeight.w700,
                color:      Color(0xFF305544),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Tajawal',
                fontSize:   14,
                fontWeight: FontWeight.w500,
                color:      Color(0xFF707070),
                height:     1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// 14. CoreLogoutButton
//
// Icon and label are ALWAYS centered (MainAxisAlignment.center) regardless
// of locale direction — this is an intentional design choice for a
// destructive action that should never be ambiguous.
// Use this widget in both Settings and Profile instead of custom logout cards.
// ════════════════════════════════════════════════════════════════════════════
class CoreLogoutButton extends StatelessWidget {
  final VoidCallback onTap;
  const CoreLogoutButton({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: double.infinity,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
          decoration: BoxDecoration(
            color:        Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _C.cardBorder, width: 1.2),
          ),
          child: Row(
            // Always center-aligned regardless of locale direction
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(LucideIcons.logOut, color: _C.logoutRed, size: 20),
              const SizedBox(width: 8),
              Text(
                l10n.logout,
                style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontSize:   16,
                  fontWeight: FontWeight.w700,
                  color:      _C.logoutRed,
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
// UNIVERSAL PROFILE AVATAR WIDGET (Main, Profile, & Chats)
// ─────────────────────────────────────────────────────────────────────────────
class CoreAvatar extends StatelessWidget {
  final String? imageUrl;
  final String initials;
  final double size; // 👈 يتحكم في حجم الأفاتار في أي مكان بالبرنامج
  final bool isPremium;

  const CoreAvatar({
    super.key,
    this.imageUrl,
    required this.initials,
    this.size = 40.0, // الحجم الافتراضي يناسب شريط القائمة الرئيسية
    this.isPremium = false,
  });

  @override
  Widget build(BuildContext context) {
    // الألوان الموحدة للهوية
    const primaryColor = Color(0xFF305544); // الأخضر الأساسي لمبتعث
    const goldColor = Color(0xFFD4AF37); // اللون الذهبي للحساب المتميز

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        border: Border.all(
          color: isPremium ? goldColor : primaryColor.withValues(alpha: 0.30),
          width: isPremium ? (size * 0.03).clamp(1.5, 3.0) : 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(isPremium ? 2.0 : 1.0), // مسافة جمالية داخل الإطار
        child: ClipOval(
          child: imageUrl != null && imageUrl!.isNotEmpty
              ? imageUrl!.startsWith('assets/')
                  ? Image.asset(
                      imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => _buildInitials(primaryColor),
                    )
                  : Image.network(
                      imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => _buildInitials(primaryColor),
                    )
              : _buildInitials(primaryColor),
        ),
      ),
    );
  }

  // في حال عدم وجود صورة، يظهر الحرف الأول من الاسم بتنسيق فخم ومتناسق
  Widget _buildInitials(Color primaryColor) {
    return Container(
      color: primaryColor.withOpacity(0.08),
      alignment: Alignment.center,
      child: Text(
        initials.isNotEmpty ? initials.trim().substring(0, 1) : 'م',
        style: TextStyle(
          fontFamily: 'Cairo',
          fontSize: size * 0.4, // يتغير حجم الخط تلقائياً بحجم الدائرة
          fontWeight: FontWeight.w800,
          color: primaryColor,
        ),
      ),
    );
  }
}


// lib/core/widgets/mubtaath_refresh.dart
//
// Branded pull-to-refresh. Unlike Material's RefreshIndicator (which slides a
// stock spinner DOWN over the content), this reveals the app's own
// [MubtaathLoader] pinned in a FIXED spot near the top: it's invisible above the
// fold, fades in as you drag the page down, spins in place (never translates),
// and — once you pull past the threshold and release — stays while the data
// refreshes, then fades away.
//
// The wrapped scrollable MUST be over-scrollable at the top (e.g.
// AlwaysScrollableScrollPhysics with BouncingScrollPhysics) so dragging past the
// top edge opens the gap the loader shows in.

import 'package:flutter/material.dart';
import 'package:mubtaath/core/theme/app_colors.dart';
import 'package:mubtaath/core/widgets/mubtaath_loader.dart';

class MubtaathRefresh extends StatefulWidget {
  final Future<void> Function() onRefresh;
  final Widget child;
  final Color color;

  const MubtaathRefresh({
    super.key,
    required this.onRefresh,
    required this.child,
    this.color = AppColors.primary,
  });

  @override
  State<MubtaathRefresh> createState() => _MubtaathRefreshState();
}

class _MubtaathRefreshState extends State<MubtaathRefresh> {
  // How far the content is dragged past the top edge (logical px).
  double _pull = 0;
  bool _refreshing = false;

  // Pull distance needed to arm a refresh, and the reveal ceiling.
  static const double _trigger = 82;
  static const double _maxReveal = 120;

  bool _handle(ScrollNotification n) {
    if (_refreshing) return false;

    // Overscroll at the top = pixels dragged below minScrollExtent.
    final past = n.metrics.minScrollExtent - n.metrics.pixels;

    if (n is ScrollUpdateNotification || n is OverscrollNotification) {
      final next = (past > 0 ? past : 0.0).clamp(0.0, _maxReveal);
      if ((next - _pull).abs() > 0.5) setState(() => _pull = next);
    } else if (n is ScrollEndNotification) {
      if (_pull >= _trigger) {
        _run();
      } else if (_pull != 0) {
        setState(() => _pull = 0);
      }
    }
    return false;
  }

  Future<void> _run() async {
    setState(() {
      _refreshing = true;
      _pull = _trigger; // hold the loader steadily visible while refreshing
    });
    try {
      await widget.onRefresh();
    } catch (_) {
      // Refresh failures surface through the page's own state; ignore here.
    }
    if (mounted) {
      setState(() {
        _refreshing = false;
        _pull = 0;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.of(context).padding.top;
    // Opacity/scale track the pull; fully shown while actually refreshing.
    final reveal = _refreshing ? 1.0 : (_pull / _trigger).clamp(0.0, 1.0);

    return Stack(
      children: [
        NotificationListener<ScrollNotification>(
          onNotification: _handle,
          child: widget.child,
        ),
        // Fixed loader — never moves with the drag; only its opacity/scale change.
        Positioned(
          top: topInset + 12,
          left: 0,
          right: 0,
          child: IgnorePointer(
            child: Center(
              child: AnimatedOpacity(
                opacity: reveal,
                duration: const Duration(milliseconds: 120),
                child: Transform.scale(
                  scale: 0.7 + 0.3 * reveal,
                  child: reveal <= 0
                      ? const SizedBox(width: 40, height: 40)
                      : Container(
                          width: 40,
                          height: 40,
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.black.withValues(alpha: 0.10),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: MubtaathLoader(
                            color: widget.color,
                            strokeWidth: 2.6,
                          ),
                        ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

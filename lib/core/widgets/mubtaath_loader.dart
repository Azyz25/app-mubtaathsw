// lib/core/widgets/mubtaath_loader.dart
//
// The app's single branded loading indicator — replaces the generic Material
// CircularProgressIndicator everywhere. A slim, rounded-cap arc with a
// gradient tail that glides continuously (no grow/shrink pulsing), so it
// reads as calm and premium rather than "stock Android spinner".
//
// Drop-in compatible with CircularProgressIndicator's common call pattern:
//   CircularProgressIndicator(color: X, strokeWidth: Y)
//   → MubtaathLoader(color: X, strokeWidth: Y)
// Sizes itself to the incoming constraints exactly like CircularProgressIndicator
// (fills a wrapping SizedBox; defaults to 36×36 if unconstrained).

import 'package:flutter/material.dart';

import 'package:mubtaath/core/theme/app_colors.dart';

class MubtaathLoader extends StatefulWidget {
  final Color  color;
  final double strokeWidth;

  const MubtaathLoader({
    super.key,
    this.color       = AppColors.primary,
    this.strokeWidth = 2.6,
  });

  @override
  State<MubtaathLoader> createState() => _MubtaathLoaderState();
}

class _MubtaathLoaderState extends State<MubtaathLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 36,
      height: 36,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => CustomPaint(
          size: Size.infinite,
          painter: _MubtaathLoaderPainter(
            progress:    _controller.value,
            color:       widget.color,
            strokeWidth: widget.strokeWidth,
          ),
        ),
      ),
    );
  }
}

class _MubtaathLoaderPainter extends CustomPainter {
  final double progress; // 0..1, one full loop
  final Color  color;
  final double strokeWidth;

  const _MubtaathLoaderPainter({
    required this.progress,
    required this.color,
    required this.strokeWidth,
  });

  static const double _sweep = 4.6; // radians of visible arc (~264°)

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.shortestSide - strokeWidth) / 2;
    final rect   = Rect.fromCircle(center: center, radius: radius);

    final rotation = progress * 2 * 3.141592653589793;

    final paint = Paint()
      ..style       = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap   = StrokeCap.round
      ..shader = SweepGradient(
        startAngle:   0,
        endAngle:     _sweep,
        transform:    GradientRotation(rotation),
        colors:       [color.withValues(alpha: 0.0), color],
        stops:        const [0.0, 1.0],
      ).createShader(rect);

    canvas.drawArc(rect, rotation, _sweep, false, paint);
  }

  @override
  bool shouldRepaint(_MubtaathLoaderPainter old) =>
      old.progress != progress || old.color != color || old.strokeWidth != strokeWidth;
}

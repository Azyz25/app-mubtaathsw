// lib/core/widgets/kaaba_outline_icon.dart
//
// A single elegant OUTLINE glyph of the Kaaba (cube + kiswa band), drawn by
// one shared function so it looks IDENTICAL everywhere it appears:
//   • the fixed marker at the top of the Qibla compass dial, and
//   • the small icon on the prayer-times "Qibla direction" preview card.
//
// Colour is always supplied by the caller (an AppColors value) — this file
// hardcodes no colours of its own.

import 'package:flutter/material.dart';

/// Draws the Kaaba glyph centred at [center], fitting a box of side [size].
/// This is the single source of truth for the mark — use it from every
/// CustomPainter, and via [KaabaOutlineIcon] from widget trees.
void paintKaabaGlyph(
  Canvas canvas,
  Offset center,
  double size,
  Color color, {
  double strokeWidth = 2,
}) {
  final half = size / 2;
  final stroke = Paint()
    ..color       = color
    ..style       = PaintingStyle.stroke
    ..strokeWidth = strokeWidth
    ..strokeJoin  = StrokeJoin.round;

  // Cube body.
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromCenter(center: center, width: size, height: size),
      const Radius.circular(2),
    ),
    stroke,
  );

  // Kiswa band near the top.
  final by = center.dy - half + size * 0.34;
  canvas.drawLine(
    Offset(center.dx - half, by),
    Offset(center.dx + half, by),
    Paint()
      ..color       = color
      ..strokeWidth = strokeWidth,
  );
}

class KaabaOutlineIcon extends StatelessWidget {
  final double size;
  final Color  color;
  final double strokeWidth;

  const KaabaOutlineIcon({
    super.key,
    required this.color,
    this.size        = 28,
    this.strokeWidth = 2,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width:  size,
      height: size,
      child: CustomPaint(
        painter: _KaabaOutlinePainter(color: color, strokeWidth: strokeWidth),
      ),
    );
  }
}

class _KaabaOutlinePainter extends CustomPainter {
  final Color  color;
  final double strokeWidth;

  const _KaabaOutlinePainter({required this.color, required this.strokeWidth});

  @override
  void paint(Canvas canvas, Size size) {
    // Leave a little padding so the stroke never clips the edges.
    final side = (size.shortestSide) - strokeWidth * 2;
    paintKaabaGlyph(
      canvas,
      Offset(size.width / 2, size.height / 2),
      side,
      color,
      strokeWidth: strokeWidth,
    );
  }

  @override
  bool shouldRepaint(_KaabaOutlinePainter old) =>
      old.color != color || old.strokeWidth != strokeWidth;
}

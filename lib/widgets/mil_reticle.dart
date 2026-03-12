import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';

class MilReticle extends StatelessWidget {
  final Offset center; // absolute position in parent coordinate space
  final double milToPx;

  const MilReticle({super.key, required this.center, required this.milToPx});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _ReticlePainter(center: center, milToPx: milToPx),
    );
  }
}

class _ReticlePainter extends CustomPainter {
  final Offset center;
  final double milToPx;

  _ReticlePainter({required this.center, required this.milToPx});

  static const Color _gold = Color(0xFFE8C84A);
  static const Color _goldDim = Color(0x99E8C84A);

  @override
  void paint(Canvas canvas, Size size) {
    final cx = center.dx;
    final cy = center.dy;

    final linePaint = Paint()
      ..color = _goldDim
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    final thickPaint = Paint()
      ..color = _gold
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final dotPaint = Paint()
      ..color = _gold
      ..style = PaintingStyle.fill;

    // Gap around center (0.5 MIL clear zone)
    final gap = milToPx * 0.5;

    // Crosshair lines — horizontal
    canvas.drawLine(Offset(0, cy), Offset(cx - gap, cy), linePaint);
    canvas.drawLine(Offset(cx + gap, cy), Offset(size.width, cy), linePaint);
    // Crosshair lines — vertical
    canvas.drawLine(Offset(cx, 0), Offset(cx, cy - gap), linePaint);
    canvas.drawLine(Offset(cx, cy + gap), Offset(cx, size.height), linePaint);

    // Hash marks and mil-dots along all four axes
    for (final axis in [_Axis.up, _Axis.down, _Axis.left, _Axis.right]) {
      for (int mil = 1; mil <= 12; mil++) {
        final dist = mil * milToPx;
        final Offset pos = switch (axis) {
          _Axis.up    => Offset(cx, cy - dist),
          _Axis.down  => Offset(cx, cy + dist),
          _Axis.left  => Offset(cx - dist, cy),
          _Axis.right => Offset(cx + dist, cy),
        };

        // Skip if outside canvas
        if (pos.dx < 0 || pos.dx > size.width || pos.dy < 0 || pos.dy > size.height) continue;

        final bool isFive = mil % 5 == 0;
        final double hashLen = isFive ? milToPx * 0.35 : milToPx * 0.18;
        final Paint paint = isFive ? thickPaint : linePaint;

        if (axis == _Axis.up || axis == _Axis.down) {
          canvas.drawLine(Offset(cx - hashLen, pos.dy), Offset(cx + hashLen, pos.dy), paint);
        } else {
          canvas.drawLine(Offset(pos.dx, cy - hashLen), Offset(pos.dx, cy + hashLen), paint);
        }

        // Mil-dots at 1–5 MIL
        if (mil <= 5) {
          canvas.drawCircle(pos, milToPx * 0.065, dotPaint);
        }
      }
    }

    // Center dot
    canvas.drawCircle(Offset(cx, cy), milToPx * 0.08, dotPaint);
  }

  @override
  bool shouldRepaint(_ReticlePainter old) =>
      old.center != center || old.milToPx != milToPx;
}

enum _Axis { up, down, left, right }

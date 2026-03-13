import 'package:flutter/material.dart';
import '../models/range_scenario.dart';
import '../models/range_target.dart';
import '../models/reticle_type.dart';
import 'reticle_painter.dart';

class RangeViewport extends StatelessWidget {
  final RangeScenario scenario;
  final Offset reticleOffset;
  final Offset sceneOffset;
  final double baseMilToPx;
  final double zoom;
  final ReticleType reticleType;
  final void Function(ScaleStartDetails) onScaleStart;
  final void Function(ScaleUpdateDetails) onScaleUpdate;

  const RangeViewport({
    super.key,
    required this.scenario,
    required this.reticleOffset,
    required this.sceneOffset,
    required this.baseMilToPx,
    required this.zoom,
    required this.reticleType,
    required this.onScaleStart,
    required this.onScaleUpdate,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onScaleStart: onScaleStart,
      onScaleUpdate: onScaleUpdate,
      child: ClipRect(
        child: CustomPaint(
          painter: _RangeViewportPainter(
            scenario: scenario,
            reticleOffset: reticleOffset,
            sceneOffset: sceneOffset,
            baseMilToPx: baseMilToPx,
            zoom: zoom,
            reticleType: reticleType,
          ),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

class _RangeViewportPainter extends CustomPainter {
  final RangeScenario scenario;
  final Offset reticleOffset;
  final Offset sceneOffset;
  final double baseMilToPx;
  final double zoom;
  final ReticleType reticleType;

  _RangeViewportPainter({
    required this.scenario,
    required this.reticleOffset,
    required this.sceneOffset,
    required this.baseMilToPx,
    required this.zoom,
    required this.reticleType,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Pass 1 — scene (landscape + targets):
    //   FFP zoom around reticle center, then apply scene pan offset.
    //   sceneOffset is in screen-space px; divide by zoom to get world units
    //   so that panning speed stays 1:1 at any zoom level.
    canvas.save();
    canvas.translate(reticleOffset.dx, reticleOffset.dy);
    canvas.scale(zoom, zoom);
    canvas.translate(-reticleOffset.dx, -reticleOffset.dy);
    canvas.translate(sceneOffset.dx / zoom, sceneOffset.dy / zoom);
    _drawLandscape(canvas, size);
    for (final target in scenario.allTargets) {
      _drawTarget(canvas, size, target, target == scenario.activeTarget);
    }
    canvas.restore();

    // Pass 2 — reticle:
    //   FFP zoom only — reticle is NOT shifted by scene pan, so your aim point
    //   stays fixed on screen while the background scrolls beneath it.
    canvas.save();
    canvas.translate(reticleOffset.dx, reticleOffset.dy);
    canvas.scale(zoom, zoom);
    canvas.translate(-reticleOffset.dx, -reticleOffset.dy);
    drawReticle(canvas, size, reticleOffset, baseMilToPx, reticleType);
    canvas.restore();
  }

  void _drawLandscape(Canvas canvas, Size size) {
    // Extend all drawing well beyond the viewport so that panning and zooming
    // never reveals a hard edge. The ClipRect in RangeViewport handles trimming.
    final double xL = -size.width  * 4;
    final double xR =  size.width  * 5;
    final double yT = -size.height * 4;
    final double yB =  size.height * 5;

    // Sky gradient — covers the entire extended world rect
    final skyRect = Rect.fromLTRB(xL, yT, xR, yB);
    final skyGrad = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      stops: const [0.0, 0.55, 0.68, 1.0],
      colors: const [
        Color(0xFF0D1A26),
        Color(0xFF1A2E3A),
        Color(0xFF1A2A18),
        Color(0xFF111A0D),
      ],
    );
    canvas.drawRect(skyRect, Paint()..shader = skyGrad.createShader(skyRect));

    // Ridge — flat at each edge, curved profile across the original viewport width
    final ridgePaint = Paint()..color = const Color(0xFF1A2E1A);
    final ridgePath = Path();
    ridgePath.moveTo(xL, size.height * 0.50);
    ridgePath.lineTo(0, size.height * 0.50);
    ridgePath.cubicTo(size.width * 0.15, size.height * 0.44,
                      size.width * 0.35, size.height * 0.48,
                      size.width * 0.50, size.height * 0.46);
    ridgePath.cubicTo(size.width * 0.65, size.height * 0.44,
                      size.width * 0.80, size.height * 0.50,
                      size.width,        size.height * 0.48);
    ridgePath.lineTo(xR, size.height * 0.48);
    ridgePath.lineTo(xR, yB);
    ridgePath.lineTo(xL, yB);
    ridgePath.close();
    canvas.drawPath(ridgePath, ridgePaint);

    // Berm — same treatment
    final bermPaint = Paint()..color = const Color(0xFF152010);
    final bermPath = Path();
    bermPath.moveTo(xL, size.height * 0.65);
    bermPath.lineTo(0, size.height * 0.65);
    bermPath.cubicTo(size.width * 0.20, size.height * 0.60,
                     size.width * 0.45, size.height * 0.67,
                     size.width * 0.60, size.height * 0.63);
    bermPath.cubicTo(size.width * 0.75, size.height * 0.59,
                     size.width * 0.88, size.height * 0.65,
                     size.width,        size.height * 0.63);
    bermPath.lineTo(xR, size.height * 0.63);
    bermPath.lineTo(xR, yB);
    bermPath.lineTo(xL, yB);
    bermPath.close();
    canvas.drawPath(bermPath, bermPaint);

    // Dark ground strip
    canvas.drawRect(
      Rect.fromLTRB(xL, size.height * 0.78, xR, yB),
      Paint()..color = const Color(0xFF0F1A0A),
    );
  }

  void _drawTarget(Canvas canvas, Size size, RangeTarget target, bool isActive) {
    final px = target.anchor.dx * size.width;
    final py = target.anchor.dy * size.height;

    final double baseH = size.height * 0.075;
    final double h = baseH * (300 / target.distanceMeters);
    final double w = h * 0.55;

    final Color fillColor = isActive ? const Color(0xFFD4A017) : const Color(0xFF5A5A4A);
    final Paint fill = Paint()..color = fillColor;
    final Paint stroke = Paint()
      ..color = isActive ? const Color(0xFFFFD700) : const Color(0xFF3A3A2A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = isActive ? 1.5 : 0.8;

    final bodyRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(px, py), width: w, height: h),
      Radius.circular(w * 0.15),
    );
    canvas.drawRRect(bodyRect, fill);
    canvas.drawRRect(bodyRect, stroke);

    final double headR = w * 0.28;
    canvas.drawCircle(Offset(px, py - h / 2 - headR * 0.6), headR, fill);
    canvas.drawCircle(Offset(px, py - h / 2 - headR * 0.6), headR, stroke);

    final labelStyle = TextStyle(
      color: isActive ? const Color(0xFFFFD700) : const Color(0xFF666655),
      fontSize: isActive ? 11.0 : 9.0,
      fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
      fontFamily: 'monospace',
    );
    final tp = TextPainter(
      text: TextSpan(text: '${target.distanceMeters}M', style: labelStyle),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(px - tp.width / 2, py + h / 2 + 4));
  }


  @override
  bool shouldRepaint(_RangeViewportPainter old) =>
      old.reticleOffset != reticleOffset ||
      old.sceneOffset != sceneOffset ||
      old.scenario != scenario ||
      old.baseMilToPx != baseMilToPx ||
      old.zoom != zoom ||
      old.reticleType != reticleType;
}

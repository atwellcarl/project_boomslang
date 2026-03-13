import 'package:flutter/material.dart';
import '../models/milling_scenario.dart';
import '../models/reticle_type.dart';
import 'reticle_painter.dart';

class MillingViewport extends StatelessWidget {
  final MillingScenario scenario;
  final Offset reticleOffset;
  final Offset sceneOffset;
  final double baseMilToPx;
  final double zoom;
  final ReticleType reticleType;
  final void Function(ScaleStartDetails) onScaleStart;
  final void Function(ScaleUpdateDetails) onScaleUpdate;

  const MillingViewport({
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
          painter: _MillingViewportPainter(
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

class _MillingViewportPainter extends CustomPainter {
  final MillingScenario scenario;
  final Offset reticleOffset;
  final Offset sceneOffset;
  final double baseMilToPx;
  final double zoom;
  final ReticleType reticleType;

  _MillingViewportPainter({
    required this.scenario,
    required this.reticleOffset,
    required this.sceneOffset,
    required this.baseMilToPx,
    required this.zoom,
    required this.reticleType,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Pass 1 — scene (landscape + target): FFP zoom around reticle center + scene pan.
    canvas.save();
    canvas.translate(reticleOffset.dx, reticleOffset.dy);
    canvas.scale(zoom, zoom);
    canvas.translate(-reticleOffset.dx, -reticleOffset.dy);
    canvas.translate(sceneOffset.dx / zoom, sceneOffset.dy / zoom);
    _drawLandscape(canvas, size);
    _drawTarget(canvas, size);
    canvas.restore();

    // Pass 2 — reticle: FFP zoom only, no scene pan.
    canvas.save();
    canvas.translate(reticleOffset.dx, reticleOffset.dy);
    canvas.scale(zoom, zoom);
    canvas.translate(-reticleOffset.dx, -reticleOffset.dy);
    drawReticle(canvas, size, reticleOffset, baseMilToPx, reticleType);
    canvas.restore();
  }

  void _drawLandscape(Canvas canvas, Size size) {
    final double xL = -size.width  * 4;
    final double xR =  size.width  * 5;
    final double yT = -size.height * 4;
    final double yB =  size.height * 5;

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

    canvas.drawRect(
      Rect.fromLTRB(xL, size.height * 0.78, xR, yB),
      Paint()..color = const Color(0xFF0F1A0A),
    );
  }

  void _drawTarget(Canvas canvas, Size size) {
    final px = scenario.anchor.dx * size.width;
    final py = scenario.anchor.dy * size.height;

    // MIL-correct sizing: height = (40in × 25.4mm/in) / distanceM MIL
    // baseMilToPx is unzoomed; canvas transform handles zoom (FFP).
    const double targetHeightIn = 40.0;
    const double targetWidthIn  = 19.5;
    final double heightMil = (targetHeightIn * 25.4) / scenario.trueDistanceMeters;
    final double widthMil  = (targetWidthIn  * 25.4) / scenario.trueDistanceMeters;
    final double h = heightMil * baseMilToPx;
    final double w = widthMil  * baseMilToPx;

    const double strokeW = 1.0;
    final Paint fill   = Paint()..color = const Color(0xFF4A4A40);
    final Paint stroke = Paint()
      ..color = const Color(0xFFAAAAAA)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeW;

    // Inset geometry by strokeW/2 so the OUTER edge of the stroke lands at the
    // MIL-correct boundary — the user measures to the outside of the line.
    final double hi = h - strokeW;
    final double wi = w - strokeW;
    final bodyRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(px, py), width: wi, height: hi),
      Radius.circular(wi * 0.15),
    );
    canvas.drawRRect(bodyRect, fill);
    canvas.drawRRect(bodyRect, stroke);

    // Head — inset radius by strokeW/2 for the same reason
    final double headR = wi * 0.28;
    final double headCy = py - hi / 2 - headR * 0.6;
    canvas.drawCircle(Offset(px, headCy), headR - strokeW / 2, fill);
    canvas.drawCircle(Offset(px, headCy), headR - strokeW / 2, stroke);
  }


  @override
  bool shouldRepaint(_MillingViewportPainter old) =>
      old.reticleOffset != reticleOffset ||
      old.sceneOffset != sceneOffset ||
      old.scenario != scenario ||
      old.baseMilToPx != baseMilToPx ||
      old.zoom != zoom ||
      old.reticleType != reticleType;
}

import 'package:flutter/material.dart';
import '../models/milling_scenario.dart';

class MillingViewport extends StatelessWidget {
  final MillingScenario scenario;
  final Offset reticleOffset;
  final Offset sceneOffset;
  final double baseMilToPx;
  final double zoom;
  final void Function(ScaleStartDetails) onScaleStart;
  final void Function(ScaleUpdateDetails) onScaleUpdate;

  const MillingViewport({
    super.key,
    required this.scenario,
    required this.reticleOffset,
    required this.sceneOffset,
    required this.baseMilToPx,
    required this.zoom,
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

  _MillingViewportPainter({
    required this.scenario,
    required this.reticleOffset,
    required this.sceneOffset,
    required this.baseMilToPx,
    required this.zoom,
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
    _drawReticle(canvas, size);
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

  void _drawReticle(Canvas canvas, Size size) {
    final double m2p = baseMilToPx;
    final cx = reticleOffset.dx;
    final cy = reticleOffset.dy;

    const Color wire      = Color(0xCCE0E0E0);
    const Color wireDim   = Color(0x88E0E0E0);
    const Color wireGhost = Color(0x44E0E0E0);

    final wirePaint = Paint()
      ..color = wire
      ..strokeWidth = 0.9
      ..strokeCap = StrokeCap.butt;
    final dimPaint = Paint()
      ..color = wireDim
      ..strokeWidth = 0.7
      ..strokeCap = StrokeCap.butt;
    final ghostPaint = Paint()
      ..color = wireGhost
      ..strokeWidth = 0.5
      ..strokeCap = StrokeCap.butt;
    final dotPaint = Paint()
      ..color = wire
      ..style = PaintingStyle.fill;

    final double labelFontSize       = (m2p * 0.52).clamp(6.5, 13.0);
    final double branchLabelFontSize = (m2p * 0.40).clamp(5.0, 10.0);

    final labelStyle = TextStyle(
      color: wire,
      fontSize: labelFontSize,
      fontFamily: 'monospace',
      height: 1.0,
    );
    final branchLabelStyle = TextStyle(
      color: wire,
      fontSize: branchLabelFontSize,
      fontFamily: 'monospace',
      height: 1.0,
    );

    void drawLabel(String text, Offset pos, {TextStyle? style}) {
      final tp = TextPainter(
        text: TextSpan(text: text, style: style ?? labelStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, pos);
    }

    // Full crosshair wires — thinner than tick marks so fine graduations stay readable
    final mainWirePaint = Paint()
      ..color = wire
      ..strokeWidth = 0.4
      ..strokeCap = StrokeCap.butt;
    canvas.drawLine(Offset(0, cy), Offset(size.width, cy), mainWirePaint);
    canvas.drawLine(Offset(cx, 0), Offset(cx, size.height), mainWirePaint);

    // Center dot
    canvas.drawCircle(Offset(cx, cy), m2p * 0.10, dotPaint);

    final double maxWindMil = (size.width  / m2p) + 1;

    // Horizontal: 0.2 ghost / 1 MIL minor / 2 MIL major + labels
    for (double m = 0.2; m <= maxWindMil; m += 0.2) {
      final bool isWhole = (m * 10).round() % 10 == 0;
      final bool isMajor = isWhole && (m.round() % 2 == 0);
      final bool isMinor = isWhole && !isMajor;

      final tickH = isMajor ? m2p * 0.55
                  : isMinor ? m2p * 0.28
                  : m2p * 0.10;
      final paint = isMajor ? wirePaint
                  : isMinor ? dimPaint
                  : ghostPaint;

      for (final sign in [-1.0, 1.0]) {
        final x = cx + sign * m * m2p;
        if (x < 0 || x > size.width) continue;
        canvas.drawLine(Offset(x, cy - tickH), Offset(x, cy + tickH), paint);
      }

      if (isMajor) {
        final mil = m.round();
        final tp = TextPainter(
          text: TextSpan(text: mil.toString(), style: labelStyle),
          textDirection: TextDirection.ltr,
        )..layout();
        for (final sign in [-1.0, 1.0]) {
          final x = cx + sign * m * m2p;
          if (x < 0 || x > size.width) continue;
          tp.paint(canvas, Offset(x - tp.width / 2, cy - m2p * 0.55 - tp.height - m2p * 0.08));
        }
      }
    }

    // Vertical above center: 0.2 ghost / 1 minor / 2 major + labels
    for (double m = 0.2; m <= 14.0; m += 0.2) {
      final y = cy - m * m2p;
      if (y < 0) continue;

      final bool isWhole = (m * 10).round() % 10 == 0;
      final bool isMajor = isWhole && (m.round() % 2 == 0);
      final bool isMinor = isWhole && !isMajor;

      final tickW = isMajor ? m2p * 0.55
                  : isMinor ? m2p * 0.28
                  : m2p * 0.10;
      final paint = isMajor ? wirePaint
                  : isMinor ? dimPaint
                  : ghostPaint;

      canvas.drawLine(Offset(cx - tickW, y), Offset(cx + tickW, y), paint);

      if (isMajor) {
        drawLabel(m.round().toString(),
            Offset(cx + tickW + m2p * 0.12, y - labelFontSize * 0.5));
      }
    }

    // Vertical below center: continuous through Christmas tree
    for (double m = 0.2; m <= 15.0; m += 0.2) {
      final y = cy + m * m2p;
      if (y > size.height) continue;

      final bool isWhole = (m * 10).round() % 10 == 0;
      final bool isMajor = isWhole && (m.round() % 2 == 0);
      final bool isMinor = isWhole && !isMajor;

      final bool isTreeRow = isMajor && m.round() >= 2 && m.round() <= 14;

      final tickW = isMajor ? m2p * 0.55
                  : isMinor ? m2p * 0.28
                  : m2p * 0.10;
      final paint = isMajor ? wirePaint
                  : isMinor ? dimPaint
                  : ghostPaint;

      if (!isTreeRow) {
        canvas.drawLine(Offset(cx - tickW, y), Offset(cx + tickW, y), paint);
      }
    }

    // Christmas tree
    const List<(double, double)> treeRows = [
      (2.0,  2.0),
      (4.0,  3.0),
      (6.0,  4.0),
      (8.0,  5.0),
      (10.0, 6.0),
      (12.0, 7.0),
      (14.0, 8.0),
    ];

    for (final (elevMil, windMil) in treeRows) {
      final double ry = cy + elevMil * m2p;
      if (ry > size.height) continue;
      final double windPx = windMil * m2p;

      canvas.drawLine(Offset(cx - windPx, ry), Offset(cx + windPx, ry), wirePaint);

      for (final sign in [-1.0, 1.0]) {
        final x = cx + sign * windPx;
        if (x >= 0 && x <= size.width) {
          canvas.drawCircle(Offset(x, ry), m2p * 0.12, dotPaint);
        }
      }

      for (double m = 0.2; m < windMil; m += 0.2) {
        final bool isWhole = (m * 10).round() % 10 == 0;
        final bool isMajor = isWhole && (m.round() % 2 == 0);
        final bool isMinor = isWhole && !isMajor;

        final tickH = isMajor ? m2p * 0.45
                    : isMinor ? m2p * 0.22
                    : m2p * 0.09;
        final paint = isMajor ? wirePaint
                    : isMinor ? dimPaint
                    : ghostPaint;

        for (final sign in [-1.0, 1.0]) {
          final x = cx + sign * m * m2p;
          if (x < 0 || x > size.width) continue;
          canvas.drawLine(Offset(x, ry - tickH), Offset(x, ry + tickH), paint);
        }

        if (isMajor) {
          final mil = m.round();
          final tp = TextPainter(
            text: TextSpan(text: mil.toString(), style: branchLabelStyle),
            textDirection: TextDirection.ltr,
          )..layout();
          for (final sign in [-1.0, 1.0]) {
            final x = cx + sign * m * m2p;
            if (x < 0 || x > size.width) continue;
            tp.paint(canvas, Offset(x - tp.width / 2, ry - m2p * 0.45 - tp.height - m2p * 0.05));
          }
        }
      }

      const double vertRange = 0.8;
      for (double mv = 0.2; mv <= vertRange; mv += 0.2) {
        final bool isWhole = (mv * 10).round() % 10 == 0;
        final tickW = isWhole ? m2p * 0.22 : m2p * 0.09;
        final paint = isWhole ? dimPaint : ghostPaint;

        for (final vsign in [-1.0, 1.0]) {
          final yv = ry + vsign * mv * m2p;
          canvas.drawLine(Offset(cx - tickW, yv), Offset(cx + tickW, yv), paint);
        }
      }

      final rightX = cx + windPx + m2p * 0.28;
      if (rightX + m2p < size.width) {
        drawLabel(elevMil.toStringAsFixed(0),
            Offset(rightX, ry - branchLabelFontSize * 0.5),
            style: branchLabelStyle);
      }
    }
  }

  @override
  bool shouldRepaint(_MillingViewportPainter old) =>
      old.reticleOffset != reticleOffset ||
      old.sceneOffset != sceneOffset ||
      old.scenario != scenario ||
      old.baseMilToPx != baseMilToPx ||
      old.zoom != zoom;
}

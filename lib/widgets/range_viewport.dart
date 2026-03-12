import 'package:flutter/material.dart';
import '../models/range_scenario.dart';
import '../models/range_target.dart';

class RangeViewport extends StatelessWidget {
  final RangeScenario scenario;
  final Offset reticleOffset;
  final Offset sceneOffset;
  final double baseMilToPx;
  final double zoom;
  final void Function(ScaleStartDetails) onScaleStart;
  final void Function(ScaleUpdateDetails) onScaleUpdate;

  const RangeViewport({
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
          painter: _RangeViewportPainter(
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

class _RangeViewportPainter extends CustomPainter {
  final RangeScenario scenario;
  final Offset reticleOffset;
  final Offset sceneOffset;
  final double baseMilToPx;
  final double zoom;

  _RangeViewportPainter({
    required this.scenario,
    required this.reticleOffset,
    required this.sceneOffset,
    required this.baseMilToPx,
    required this.zoom,
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
    _drawReticle(canvas, size);
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

  void _drawReticle(Canvas canvas, Size size) {
    // milToPx here is the BASE (unzoomed) value. The canvas transform handles
    // the visual zoom, so everything drawn at baseMilToPx scale appears at
    // baseMilToPx * zoom on screen — true FFP behavior.
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

    final double labelFontSize = (m2p * 0.52).clamp(6.5, 13.0);
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

    // ── Full crosshair wires ──────────────────────────────────────────────────
    canvas.drawLine(Offset(0, cy), Offset(size.width, cy), wirePaint);
    canvas.drawLine(Offset(cx, 0), Offset(cx, size.height), wirePaint);

    // Center dot
    canvas.drawCircle(Offset(cx, cy), m2p * 0.10, dotPaint);

    final double maxWindMil  = (size.width  / m2p) + 1;
    final double maxElevMil  = (size.height / m2p) + 1;

    // ── Horizontal wire: 0.2 ghost / 1 MIL minor / 2 MIL major + labels ─────
    for (double m = 0.2; m <= maxWindMil; m += 0.2) {
      final bool isWhole = (m * 10).round() % 10 == 0; // whole MIL
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
          final tickH2 = m2p * 0.55;
          tp.paint(canvas, Offset(x - tp.width / 2, cy - tickH2 - tp.height - m2p * 0.08));
        }
      }
    }

    // ── Vertical wire above center: 0.2 ghost / 1 minor / 2 major + labels ──
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

    // ── Vertical wire below center: same pattern, continuous through tree ────
    for (double m = 0.2; m <= 15.0; m += 0.2) {
      final y = cy + m * m2p;
      if (y > size.height) continue;

      final bool isWhole = (m * 10).round() % 10 == 0;
      final bool isMajor = isWhole && (m.round() % 2 == 0);
      final bool isMinor = isWhole && !isMajor;

      // Skip ticks that land exactly on a tree-row major stadia (already drawn there)
      final bool isTreeRow = isWhole && (m.round() % 2 == 0) &&
          m.round() >= 2 && m.round() <= 14;

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

    // ── Christmas tree: each branch is a mini crosshair ──────────────────────
    // Row: (elevation MIL, max wind MIL half-width)
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

      // ── Horizontal axis of the mini crosshair ──────────────────────────────
      // Full stadia line
      canvas.drawLine(Offset(cx - windPx, ry), Offset(cx + windPx, ry), wirePaint);

      // Endpoint dots
      for (final sign in [-1.0, 1.0]) {
        final x = cx + sign * windPx;
        if (x >= 0 && x <= size.width) {
          canvas.drawCircle(Offset(x, ry), m2p * 0.12, dotPaint);
        }
      }

      // 0.2 ghost / 1 MIL minor / 2 MIL major ticks along stadia
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
            final tickH2 = m2p * 0.45;
            tp.paint(canvas, Offset(x - tp.width / 2, ry - tickH2 - tp.height - m2p * 0.05));
          }
        }
      }

      // ── Vertical axis of the mini crosshair ────────────────────────────────
      // Ticks above AND below the stadia, up to ±0.8 MIL (stays clear of
      // adjacent rows which are 2 MIL apart)
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

      // Elevation label to the right of the stadia endpoint
      final rightX = cx + windPx + m2p * 0.28;
      if (rightX + m2p < size.width) {
        drawLabel(elevMil.toStringAsFixed(0),
            Offset(rightX, ry - branchLabelFontSize * 0.5),
            style: branchLabelStyle);
      }
    }
  }

  @override
  bool shouldRepaint(_RangeViewportPainter old) =>
      old.reticleOffset != reticleOffset ||
      old.sceneOffset != sceneOffset ||
      old.scenario != scenario ||
      old.baseMilToPx != baseMilToPx ||
      old.zoom != zoom;
}

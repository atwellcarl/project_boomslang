import 'package:flutter/material.dart';
import '../models/reticle_type.dart';

void drawReticle(
  Canvas canvas,
  Size size,
  Offset center,
  double baseMilToPx,
  ReticleType reticleType,
) {
  final double m2p = baseMilToPx;
  final cx = center.dx;
  final cy = center.dy;

  const Color wire = Color(0xCCE0E0E0);
  const Color wireDim = Color(0x88E0E0E0);
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

  // Derive tick intervals and tree rows based on reticle type
  late final double ghostTickInterval;
  late final double majorTickInterval;
  late final List<(double, double)> treeRows;
  late final double verticalLoopLimit;

  if (reticleType == ReticleType.mil) {
    ghostTickInterval = 0.2;
    majorTickInterval = 2.0;
    treeRows = const [
      (2.0, 2.0),
      (4.0, 3.0),
      (6.0, 4.0),
      (8.0, 5.0),
      (10.0, 6.0),
      (12.0, 7.0),
      (14.0, 8.0),
    ];
    verticalLoopLimit = 15.0;
  } else {
    // MOA: 1 MIL = 3.438 MOA
    ghostTickInterval = 0.5;
    majorTickInterval = 5.0;
    treeRows = const [
      (5.0, 5.0),
      (10.0, 7.0),
      (15.0, 10.0),
      (20.0, 12.0),
      (25.0, 15.0),
      (30.0, 17.0),
      (35.0, 20.0),
    ];
    verticalLoopLimit = 37.0;
  }

  // Precompute tree row elevations for skip logic
  final treeRowElevations = Set<int>.from(treeRows.map((r) => r.$1.round()));

  // Full crosshair wires — thinner than tick marks so fine graduations stay readable
  final mainWirePaint = Paint()
    ..color = wire
    ..strokeWidth = 0.4
    ..strokeCap = StrokeCap.butt;
  canvas.drawLine(Offset(0, cy), Offset(size.width, cy), mainWirePaint);
  canvas.drawLine(Offset(cx, 0), Offset(cx, size.height), mainWirePaint);

  // Center dot
  canvas.drawCircle(Offset(cx, cy), m2p * 0.10, dotPaint);

  final double maxWindUnit = (size.width / m2p) + 1;

  // Horizontal: ghost / minor / major + labels
  for (double u = ghostTickInterval; u <= maxWindUnit; u += ghostTickInterval) {
    final bool isWhole = _isWholeTick(u, ghostTickInterval);
    final bool isMajor = isWhole && _isMajorTick(u, majorTickInterval);
    final bool isMinor = isWhole && !isMajor;

    final tickH = isMajor ? m2p * 0.55 : isMinor ? m2p * 0.28 : m2p * 0.10;
    final paint = isMajor ? wirePaint : isMinor ? dimPaint : ghostPaint;

    for (final sign in [-1.0, 1.0]) {
      final x = cx + sign * u * m2p;
      if (x < 0 || x > size.width) continue;
      canvas.drawLine(Offset(x, cy - tickH), Offset(x, cy + tickH), paint);
    }

    if (isMajor) {
      final label = u.round().toString();
      final tp = TextPainter(
        text: TextSpan(text: label, style: labelStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      for (final sign in [-1.0, 1.0]) {
        final x = cx + sign * u * m2p;
        if (x < 0 || x > size.width) continue;
        tp.paint(
            canvas, Offset(x - tp.width / 2, cy - m2p * 0.55 - tp.height - m2p * 0.08));
      }
    }
  }

  // Vertical above center: ghost / minor / major + labels
  for (double u = ghostTickInterval; u <= 14.0; u += ghostTickInterval) {
    final y = cy - u * m2p;
    if (y < 0) continue;

    final bool isWhole = _isWholeTick(u, ghostTickInterval);
    final bool isMajor = isWhole && _isMajorTick(u, majorTickInterval);
    final bool isMinor = isWhole && !isMajor;

    final tickW = isMajor ? m2p * 0.55 : isMinor ? m2p * 0.28 : m2p * 0.10;
    final paint = isMajor ? wirePaint : isMinor ? dimPaint : ghostPaint;

    canvas.drawLine(Offset(cx - tickW, y), Offset(cx + tickW, y), paint);

    if (isMajor) {
      drawLabel(u.round().toString(), Offset(cx + tickW + m2p * 0.12, y - labelFontSize * 0.5));
    }
  }

  // Vertical below center: continuous through Christmas tree
  for (double u = ghostTickInterval; u <= verticalLoopLimit; u += ghostTickInterval) {
    final y = cy + u * m2p;
    if (y > size.height) continue;

    final bool isWhole = _isWholeTick(u, ghostTickInterval);
    final bool isMajor = isWhole && _isMajorTick(u, majorTickInterval);
    final bool isMinor = isWhole && !isMajor;

    // Skip vertical ticks that are tree row elevations
    final bool isTreeRow = isMajor && treeRowElevations.contains(u.round());

    final tickW = isMajor ? m2p * 0.55 : isMinor ? m2p * 0.28 : m2p * 0.10;
    final paint = isMajor ? wirePaint : isMinor ? dimPaint : ghostPaint;

    if (!isTreeRow) {
      canvas.drawLine(Offset(cx - tickW, y), Offset(cx + tickW, y), paint);
    }
  }

  // Christmas tree
  for (final (elevUnit, windUnit) in treeRows) {
    final double ry = cy + elevUnit * m2p;
    if (ry > size.height) continue;
    final double windPx = windUnit * m2p;

    canvas.drawLine(Offset(cx - windPx, ry), Offset(cx + windPx, ry), wirePaint);

    for (final sign in [-1.0, 1.0]) {
      final x = cx + sign * windPx;
      if (x >= 0 && x <= size.width) {
        canvas.drawCircle(Offset(x, ry), m2p * 0.12, dotPaint);
      }
    }

    // Tree row horizontal tick marks
    for (double u = ghostTickInterval; u < windUnit; u += ghostTickInterval) {
      final bool isWhole = _isWholeTick(u, ghostTickInterval);
      final bool isMajor = isWhole && _isMajorTick(u, majorTickInterval);
      final bool isMinor = isWhole && !isMajor;

      final tickH = isMajor ? m2p * 0.45 : isMinor ? m2p * 0.22 : m2p * 0.09;
      final paint = isMajor ? wirePaint : isMinor ? dimPaint : ghostPaint;

      for (final sign in [-1.0, 1.0]) {
        final x = cx + sign * u * m2p;
        if (x < 0 || x > size.width) continue;
        canvas.drawLine(Offset(x, ry - tickH), Offset(x, ry + tickH), paint);
      }

      if (isMajor) {
        final label = u.round().toString();
        final tp = TextPainter(
          text: TextSpan(text: label, style: branchLabelStyle),
          textDirection: TextDirection.ltr,
        )..layout();
        for (final sign in [-1.0, 1.0]) {
          final x = cx + sign * u * m2p;
          if (x < 0 || x > size.width) continue;
          tp.paint(
              canvas, Offset(x - tp.width / 2, ry - m2p * 0.45 - tp.height - m2p * 0.05));
        }
      }
    }

    // Vertical tick marks within tree row
    const double vertRange = 0.8;
    for (double v = ghostTickInterval; v <= vertRange; v += ghostTickInterval) {
      final bool isWhole = _isWholeTick(v, ghostTickInterval);
      final tickW = isWhole ? m2p * 0.22 : m2p * 0.09;
      final paint = isWhole ? dimPaint : ghostPaint;

      for (final vsign in [-1.0, 1.0]) {
        final yv = ry + vsign * v * m2p;
        canvas.drawLine(Offset(cx - tickW, yv), Offset(cx + tickW, yv), paint);
      }
    }

    // Elevation label to the right of tree row
    final rightX = cx + windPx + m2p * 0.28;
    if (rightX + m2p < size.width) {
      drawLabel(elevUnit.toStringAsFixed(0), Offset(rightX, ry - branchLabelFontSize * 0.5),
          style: branchLabelStyle);
    }
  }
}

/// Check if a value is a whole number at the given tick interval
bool _isWholeTick(double value, double interval) {
  // For 0.2 interval: (v * 10).round() % 10 == 0
  // For 0.5 interval: (v * 2).round() % 2 == 0
  final divisor = (1.0 / interval).round();
  return (value * divisor).round() % divisor == 0;
}

/// Check if a value is a major tick at the given interval
bool _isMajorTick(double value, double interval) {
  // Round to nearest integer first for stable comparisons
  return (value / interval).round() % 1 == 0;
}

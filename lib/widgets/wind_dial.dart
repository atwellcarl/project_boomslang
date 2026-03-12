import 'dart:math';
import 'package:flutter/material.dart';

class WindDial extends StatelessWidget {
  final double clockPosition;
  final double windSpeedMph;

  const WindDial({
    super.key,
    required this.clockPosition,
    required this.windSpeedMph,
  });

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: CustomPaint(
        painter: _WindDialPainter(
          clockPosition: clockPosition,
          windSpeedMph: windSpeedMph,
        ),
      ),
    );
  }
}

class _WindDialPainter extends CustomPainter {
  final double clockPosition;
  final double windSpeedMph;

  _WindDialPainter({
    required this.clockPosition,
    required this.windSpeedMph,
  });

  // 8-point compass positions: (clockPos, label, isCardinal)
  static const List<(double, String, bool)> _positions = [
    (12.0, '12', true),
    (1.5, '1:30', false),
    (3.0, '3', true),
    (4.5, '4:30', false),
    (6.0, '6', true),
    (7.5, '7:30', false),
    (9.0, '9', true),
    (10.5, '10:30', false),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 * 0.88;

    // Background circle
    canvas.drawCircle(
      center,
      radius,
      Paint()..color = const Color(0xFF1A1A2E),
    );

    // Outer ring
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = const Color(0xFF4A7C59)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );

    // 8-point tick marks and labels
    final tickPaint = Paint()
      ..color = const Color(0xFF8BA888)
      ..strokeWidth = 1.5;

    for (final (pos, label, isCardinal) in _positions) {
      final angle = (pos / 12.0) * 2 * pi - pi / 2;
      final tickLength = isCardinal ? radius * 0.14 : radius * 0.09;

      final outerPt = Offset(
        center.dx + radius * cos(angle),
        center.dy + radius * sin(angle),
      );
      final innerPt = Offset(
        center.dx + (radius - tickLength) * cos(angle),
        center.dy + (radius - tickLength) * sin(angle),
      );
      canvas.drawLine(outerPt, innerPt, tickPaint);

      final fontSize = isCardinal ? size.width * 0.072 : size.width * 0.052;
      final labelRadius = isCardinal ? radius * 0.72 : radius * 0.75;

      final textStyle = TextStyle(
        color: const Color(0xFFB8D4B0),
        fontSize: fontSize,
        fontWeight: isCardinal ? FontWeight.w600 : FontWeight.w400,
        fontFamily: 'monospace',
      );

      final labelPt = Offset(
        center.dx + labelRadius * cos(angle),
        center.dy + labelRadius * sin(angle),
      );
      final span = TextSpan(text: label, style: textStyle);
      final tp = TextPainter(text: span, textDirection: TextDirection.ltr)..layout();
      tp.paint(canvas, labelPt - Offset(tp.width / 2, tp.height / 2));
    }

    // Wind arrow
    final arrowAngle = (clockPosition / 12.0) * 2 * pi - pi / 2;
    final arrowLength = radius * 0.60;

    final arrowTip = Offset(
      center.dx + arrowLength * cos(arrowAngle),
      center.dy + arrowLength * sin(arrowAngle),
    );
    final arrowTail = Offset(
      center.dx - arrowLength * 0.35 * cos(arrowAngle),
      center.dy - arrowLength * 0.35 * sin(arrowAngle),
    );

    // Arrow shaft
    canvas.drawLine(
      arrowTail,
      arrowTip,
      Paint()
        ..color = const Color(0xFFE8C84A)
        ..strokeWidth = size.width * 0.025
        ..strokeCap = StrokeCap.round,
    );

    // Arrowhead
    const headAngle = 0.42;
    final headLength = radius * 0.18;
    final left = Offset(
      arrowTip.dx - headLength * cos(arrowAngle - headAngle),
      arrowTip.dy - headLength * sin(arrowAngle - headAngle),
    );
    final right = Offset(
      arrowTip.dx - headLength * cos(arrowAngle + headAngle),
      arrowTip.dy - headLength * sin(arrowAngle + headAngle),
    );

    final arrowPath = Path()
      ..moveTo(arrowTip.dx, arrowTip.dy)
      ..lineTo(left.dx, left.dy)
      ..lineTo(right.dx, right.dy)
      ..close();

    canvas.drawPath(arrowPath, Paint()..color = const Color(0xFFE8C84A));

    // Center dot
    canvas.drawCircle(center, size.width * 0.03, Paint()..color = const Color(0xFFE8C84A));

    // Wind speed label in center
    final speedStyle = TextStyle(
      color: Colors.white,
      fontSize: size.width * 0.11,
      fontWeight: FontWeight.bold,
      fontFamily: 'monospace',
    );
    final unitStyle = TextStyle(
      color: const Color(0xFF8BA888),
      fontSize: size.width * 0.065,
      fontFamily: 'monospace',
    );

    final speedSpan = TextSpan(
      children: [
        TextSpan(text: '${windSpeedMph.toInt()}', style: speedStyle),
        TextSpan(text: ' mph', style: unitStyle),
      ],
    );
    final speedTp = TextPainter(text: speedSpan, textDirection: TextDirection.ltr)..layout();
    speedTp.paint(
      canvas,
      Offset(center.dx - speedTp.width / 2, center.dy + radius * 0.30),
    );
  }

  @override
  bool shouldRepaint(_WindDialPainter old) =>
      old.clockPosition != clockPosition || old.windSpeedMph != windSpeedMph;
}

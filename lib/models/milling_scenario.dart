import 'dart:ui';

class MillingScenario {
  final int trueDistanceMeters;
  final Offset anchor; // fractional position in viewport (0..1 each axis)

  const MillingScenario({
    required this.trueDistanceMeters,
    required this.anchor,
  });
}

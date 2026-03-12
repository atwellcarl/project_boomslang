import 'dart:ui';

class RangeTarget {
  final int distanceMeters;
  // Fractional position (0.0–1.0) within the viewport
  final Offset anchor;

  const RangeTarget({
    required this.distanceMeters,
    required this.anchor,
  });
}

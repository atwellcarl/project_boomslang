import 'dart:math';
import 'dart:ui';
import '../models/milling_scenario.dart';

class MillingScenarioGenerator {
  static final _rng = Random();

  /// Generates a random milling scenario.
  /// Distance: 200–700 m in 25 m steps.
  /// Anchor: placed on the berm band so the target sits in the landscape.
  static MillingScenario generate() {
    // 21 possible distances: 200, 225, 250, … 700
    final dist = 200 + _rng.nextInt(21) * 25;

    // x: 0.20–0.80, y: 0.65–0.78 (berm region of the programmatic landscape)
    final ax = 0.20 + _rng.nextDouble() * 0.60;
    final ay = 0.65 + _rng.nextDouble() * 0.13;

    return MillingScenario(
      trueDistanceMeters: dist,
      anchor: Offset(ax, ay),
    );
  }
}

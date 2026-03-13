import 'dart:math';
import 'dart:ui';
import '../models/ballistic_profile.dart';
import '../models/difficulty_mode.dart';
import '../models/range_scenario.dart';
import '../models/range_target.dart';
import 'ballistic_solver.dart';

class RangeScenarioGenerator {
  static final Random _rng = Random();

  static const List<double> _expertClocks = [1.5, 3.0, 4.5, 6.0, 7.5, 9.0, 10.5, 12.0];
  static const List<double> _basicClocks  = [3.0, 6.0, 9.0, 12.0];

  static RangeScenario generate(BallisticProfile profile, DifficultyMode difficulty) {
    final clocks = difficulty == DifficultyMode.basic ? _basicClocks : _expertClocks;

    // Eligible distances: 200–800m and present in the profile's elevation table.
    final eligibleDists = profile.tableDistances
        .where((d) => d >= 200 && d <= 800)
        .toList();

    // Pick up to 5 distinct distances and place them across the viewport.
    final count = min(5, eligibleDists.length);
    final selectedDists = (List<int>.from(eligibleDists)..shuffle(_rng)).take(count).toList();
    final targets = _placeTargets(selectedDists);

    // Active target — any of the five.
    final RangeTarget active = targets[_rng.nextInt(targets.length)];

    final double speed = profile.tableWindSpeeds[_rng.nextInt(profile.tableWindSpeeds.length)];
    final double clock = clocks[_rng.nextInt(clocks.length)];

    final double multiplier = BallisticSolver.clockMultiplier(clock);
    final double windMil = BallisticSolver.windDriftMil(
        profile, active.distanceMeters, speed, multiplier);
    final bool isRightHold = BallisticSolver.isRightHold(clock);

    final int distIdx = profile.tableDistances.indexOf(active.distanceMeters);
    final double elevationMil = profile.elevationTable[distIdx];

    return RangeScenario(
      activeTarget: active,
      allTargets: targets,
      windSpeedMph: speed,
      clockPosition: clock,
      elevationMil: double.parse(elevationMil.toStringAsFixed(1)),
      windMil: double.parse(windMil.toStringAsFixed(1)),
      isRightHold: isRightHold,
    );
  }

  /// Generate wind/elevation for a specific [activeTarget] while keeping the
  /// existing [allTargets] layout — used when advancing to the next target
  /// within the same set of five.
  static RangeScenario generateForTarget(
    RangeTarget activeTarget,
    List<RangeTarget> allTargets,
    BallisticProfile profile,
    DifficultyMode difficulty,
  ) {
    final clocks = difficulty == DifficultyMode.basic ? _basicClocks : _expertClocks;
    final double speed = profile.tableWindSpeeds[_rng.nextInt(profile.tableWindSpeeds.length)];
    final double clock = clocks[_rng.nextInt(clocks.length)];
    final double multiplier = BallisticSolver.clockMultiplier(clock);
    final double windMil = BallisticSolver.windDriftMil(
        profile, activeTarget.distanceMeters, speed, multiplier);
    final bool isRightHold = BallisticSolver.isRightHold(clock);
    final int distIdx = profile.tableDistances.indexOf(activeTarget.distanceMeters);
    final double elevationMil = profile.elevationTable[distIdx];

    return RangeScenario(
      activeTarget: activeTarget,
      allTargets: allTargets,
      windSpeedMph: speed,
      clockPosition: clock,
      elevationMil: double.parse(elevationMil.toStringAsFixed(1)),
      windMil: double.parse(windMil.toStringAsFixed(1)),
      isRightHold: isRightHold,
    );
  }

  /// Distribute [distances] across equal x-bands (0.15–0.85) so targets are
  /// visually spread across the range. Distances are shuffled so left-to-right
  /// order is unpredictable.
  static List<RangeTarget> _placeTargets(List<int> distances) {
    final shuffled = List<int>.from(distances)..shuffle(_rng);
    final n = shuffled.length;
    final double bandWidth = 0.70 / n;

    return List.generate(n, (i) {
      final x = 0.15 + i * bandWidth + _rng.nextDouble() * bandWidth;
      final y = 0.65 + _rng.nextDouble() * 0.13;
      return RangeTarget(distanceMeters: shuffled[i], anchor: Offset(x, y));
    });
  }
}

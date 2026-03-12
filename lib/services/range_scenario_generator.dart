import 'dart:math';
import '../data/range_targets.dart';
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

    // Pick a random active target that exists in the profile's distance table
    final eligibleTargets = kRangeTargets
        .where((t) => profile.tableDistances.contains(t.distanceMeters))
        .toList();
    final RangeTarget active = eligibleTargets[_rng.nextInt(eligibleTargets.length)];

    final double speed = profile.tableWindSpeeds[_rng.nextInt(profile.tableWindSpeeds.length)];
    final double clock = clocks[_rng.nextInt(clocks.length)];

    final double multiplier = BallisticSolver.clockMultiplier(clock);
    final double windMil = BallisticSolver.windDriftMil(profile, active.distanceMeters, speed, multiplier);
    final bool isRightHold = BallisticSolver.isRightHold(clock);

    final int distIdx = profile.tableDistances.indexOf(active.distanceMeters);
    final double elevationMil = profile.elevationTable[distIdx];

    return RangeScenario(
      activeTarget: active,
      allTargets: kRangeTargets,
      windSpeedMph: speed,
      clockPosition: clock,
      elevationMil: double.parse(elevationMil.toStringAsFixed(1)),
      windMil: double.parse(windMil.toStringAsFixed(1)),
      isRightHold: isRightHold,
    );
  }
}

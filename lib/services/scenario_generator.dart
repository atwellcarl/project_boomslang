import 'dart:math';
import '../models/ballistic_profile.dart';
import '../models/difficulty_mode.dart';
import '../models/wind_scenario.dart';
import 'ballistic_solver.dart';

class ScenarioGenerator {
  static final Random _rng = Random();

  // Expert: all 8-point compass positions including zero-value (12 and 6 o'clock)
  static const List<double> _expertClocks = [1.5, 3.0, 4.5, 6.0, 7.5, 9.0, 10.5, 12.0];

  // Basic: full-value and zero-value positions
  static const List<double> _basicClocks = [3.0, 6.0, 9.0, 12.0];

  static WindScenario generate(BallisticProfile profile, DifficultyMode difficulty) {
    final clocks = difficulty == DifficultyMode.basic ? _basicClocks : _expertClocks;
    final int distance = profile.tableDistances[_rng.nextInt(profile.tableDistances.length)];
    final double speed = profile.tableWindSpeeds[_rng.nextInt(profile.tableWindSpeeds.length)];
    final double clock = clocks[_rng.nextInt(clocks.length)];

    final double multiplier = BallisticSolver.clockMultiplier(clock);
    final double mil = BallisticSolver.windDriftMil(profile, distance, speed, multiplier);
    final bool rightHold = BallisticSolver.isRightHold(clock);

    return WindScenario(
      distanceMeters: distance,
      windSpeedMph: speed,
      clockPosition: clock,
      correctMil: double.parse(mil.toStringAsFixed(1)),
      isRightWind: rightHold,
    );
  }
}

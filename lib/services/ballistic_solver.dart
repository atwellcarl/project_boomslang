import '../models/ballistic_profile.dart';

class BallisticSolver {
  /// Returns wind drift in MIL for a given scenario using the profile's wind table.
  /// [distanceMeters] and [windSpeedMph] must be exact values from the profile's table.
  /// [clockMultiplier] is 1.0 for full-value, 0.5 for half-value, 0.0 for no-value.
  static double windDriftMil(
    BallisticProfile profile,
    int distanceMeters,
    double windSpeedMph,
    double clockMultiplier,
  ) {
    final distIdx = profile.tableDistances.indexOf(distanceMeters);
    final speedIdx = profile.tableWindSpeeds.indexOf(windSpeedMph);
    final fullValueMil = profile.windTable[distIdx][speedIdx];
    return fullValueMil * clockMultiplier;
  }

  /// Returns the wind value multiplier for an 8-point clock position.
  /// 3.0 / 9.0  → full value (1.0)
  /// 1.5 / 4.5 / 7.5 / 10.5 → half value (0.5)
  /// 6.0 / 12.0 → no value (0.0)
  static double clockMultiplier(double clockPosition) {
    if (clockPosition == 3.0 || clockPosition == 9.0) return 1.0;
    if (clockPosition == 6.0 || clockPosition == 12.0) return 0.0;
    return 0.5;
  }

  /// True if the correct hold is to the RIGHT of the target.
  /// Clock 1:30–4:30: wind FROM the right → bullet pushed LEFT → hold RIGHT.
  /// Clock 7:30–10:30: wind FROM the left → bullet pushed RIGHT → hold LEFT.
  static bool isRightHold(double clockPosition) {
    return clockPosition >= 1.0 && clockPosition <= 5.0;
  }
}

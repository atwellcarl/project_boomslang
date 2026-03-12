import 'range_target.dart';

class RangeScenario {
  final RangeTarget activeTarget;
  final List<RangeTarget> allTargets;
  final double windSpeedMph;
  final double clockPosition;
  final double elevationMil; // provided to user
  final double windMil;      // correct wind MIL magnitude
  final bool isRightHold;    // true = hold right (aim right of target)

  const RangeScenario({
    required this.activeTarget,
    required this.allTargets,
    required this.windSpeedMph,
    required this.clockPosition,
    required this.elevationMil,
    required this.windMil,
    required this.isRightHold,
  });
}

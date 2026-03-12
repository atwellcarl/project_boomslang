import '../lib/services/ballistic_solver.dart';
import '../lib/data/ballistic_profiles.dart';

void main() {
  for (final profile in kBallisticProfiles) {
    print('\n${profile.name}');
    print('  Dist  | 10mph full-value wind drift');
    for (final dist in [300, 400, 500, 600, 700, 800, 900, 1000]) {
      final mil = BallisticSolver.windDriftMilAt10Mph(profile, dist);
      print('  ${dist}yd  | ${mil.toStringAsFixed(2)} MIL');
    }
  }
}

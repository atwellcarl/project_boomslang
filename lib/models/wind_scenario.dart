class WindScenario {
  final int distanceMeters;
  final double windSpeedMph;
  final double clockPosition; // 1.5, 3.0, 4.5, 6.0, 7.5, 9.0, 10.5, 12.0
  final double correctMil;
  final bool isRightWind; // true = wind from right, holdover to right

  const WindScenario({
    required this.distanceMeters,
    required this.windSpeedMph,
    required this.clockPosition,
    required this.correctMil,
    required this.isRightWind,
  });

  String get clockLabel {
    final intPart = clockPosition.floor();
    final frac = clockPosition - intPart;
    if (frac < 0.1) return '$intPart o\'clock';
    return '$intPart:30 o\'clock';
  }

  String get answerString =>
      '${correctMil.toStringAsFixed(1)} MIL ${isRightWind ? 'RIGHT' : 'LEFT'}';
}

class BallisticProfile {
  final String name;
  final String shortName;
  final List<int> tableDistances; // meters
  final List<double> tableWindSpeeds; // mph, full-value
  // windTable[distanceIndex][speedIndex] = MIL (full-value, 3/9 o'clock)
  final List<List<double>> windTable;
  // elevationTable[distanceIndex] = MIL come-up (zeroed at 100M)
  final List<double> elevationTable;

  const BallisticProfile({
    required this.name,
    required this.shortName,
    required this.tableDistances,
    required this.tableWindSpeeds,
    required this.windTable,
    required this.elevationTable,
  });

  @override
  bool operator ==(Object other) => other is BallisticProfile && other.name == name;

  @override
  int get hashCode => name.hashCode;
}

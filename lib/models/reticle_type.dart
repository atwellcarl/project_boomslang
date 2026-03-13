enum ReticleType { mil, moa }

extension ReticleTypeX on ReticleType {
  static const double _milsPerMoa = 3.438;

  String get label => switch (this) {
    ReticleType.mil => 'MIL',
    ReticleType.moa => 'MOA',
  };

  double get drumStep => switch (this) {
    ReticleType.mil => 0.1,
    ReticleType.moa => 0.25,
  };

  double get drumMax => switch (this) {
    ReticleType.mil => 5.0,
    ReticleType.moa => 17.0,
  };

  /// Convert a MIL value to this unit system
  double fromMil(double mil) => switch (this) {
    ReticleType.mil => mil,
    ReticleType.moa => mil * _milsPerMoa,
  };

  /// Convert a value in this unit system to MIL
  double toMil(double value) => switch (this) {
    ReticleType.mil => value,
    ReticleType.moa => value / _milsPerMoa,
  };

  /// Answer tolerance (angular accuracy matching)
  double get tolerance => switch (this) {
    ReticleType.mil => 0.1,      // 0.1 MIL
    ReticleType.moa => 0.35,     // ~0.1 MIL equivalent (0.344 MOA)
  };
}

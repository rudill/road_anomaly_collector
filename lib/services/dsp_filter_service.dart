/// Single Biquad (Second-Order Section) IIR Filter Stage.
/// Implemented using Direct-Form II Transposed structure for numerical stability.
class BiquadSection {
  final double b0, b1, b2;
  final double a1, a2;

  double _s1 = 0.0;
  double _s2 = 0.0;

  BiquadSection({
    required this.b0,
    required this.b1,
    required this.b2,
    required this.a1,
    required this.a2,
  });

  @pragma('vm:prefer-inline')
  double process(double input) {
    final y = b0 * input + _s1;
    _s1 = b1 * input - a1 * y + _s2;
    _s2 = b2 * input - a2 * y;
    return y;
  }

  void reset() {
    _s1 = 0.0;
    _s2 = 0.0;
  }
}

/// 4th-Order Butterworth Filter for real-time triaxial inertial data streaming.
///
/// Attenuates high-frequency engine vibration, chassis rattle, and acoustic noise
/// above 20 Hz, isolating road surface dynamic excitation transients (potholes/bumps).
class DspFilterService {
  // Cascaded 2nd-order sections for 4th-order Butterworth low-pass (fc = 20 Hz at fs = 100 Hz)
  // Section 1:
  // [0.0465829066, 0.0931658133, 0.0465829066, 1.0, -0.3289756774, 0.0645876549]
  // Section 2:
  // [1.0, 2.0, 1.0, 1.0, -0.4531195207, 0.4663255708]

  late final List<BiquadSection> _sectionsX;
  late final List<BiquadSection> _sectionsY;
  late final List<BiquadSection> _sectionsZ;

  bool enabled;

  DspFilterService({this.enabled = true}) {
    _sectionsX = _createSections();
    _sectionsY = _createSections();
    _sectionsZ = _createSections();
  }

  List<BiquadSection> _createSections() => [
    BiquadSection(
      b0: 0.04658290663644365,
      b1: 0.0931658132728873,
      b2: 0.04658290663644365,
      a1: -0.32897567737095307,
      a2: 0.064587654916443,
    ),
    BiquadSection(
      b0: 1.0,
      b1: 2.0,
      b2: 1.0,
      a1: -0.45311952065238476,
      a2: 0.4663255707632367,
    ),
  ];

  /// Process triaxial sample [ax, ay, az] in-place or returning filtered values.
  @pragma('vm:prefer-inline')
  List<double> filter(double ax, double ay, double az) {
    if (!enabled) return [ax, ay, az];

    double outX = ax;
    for (int i = 0; i < _sectionsX.length; i++) {
      outX = _sectionsX[i].process(outX);
    }

    double outY = ay;
    for (int i = 0; i < _sectionsY.length; i++) {
      outY = _sectionsY[i].process(outY);
    }

    double outZ = az;
    for (int i = 0; i < _sectionsZ.length; i++) {
      outZ = _sectionsZ[i].process(outZ);
    }

    return [outX, outY, outZ];
  }

  void reset() {
    for (final s in _sectionsX) {
      s.reset();
    }
    for (final s in _sectionsY) {
      s.reset();
    }
    for (final s in _sectionsZ) {
      s.reset();
    }
  }
}

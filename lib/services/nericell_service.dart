import 'dart:math' as math;
import 'dart:typed_data';

/// Represents a 3D coordinate vector.
class Vector3D {
  final double x;
  final double y;
  final double z;

  const Vector3D(this.x, this.y, this.z);

  double get norm => math.sqrt(x * x + y * y + z * z);

  Vector3D normalized() {
    final n = norm;
    if (n < 1e-6) return const Vector3D(0, 0, 1);
    return Vector3D(x / n, y / n, z / n);
  }

  Vector3D cross(Vector3D other) {
    return Vector3D(
      y * other.z - z * other.y,
      z * other.x - x * other.z,
      x * other.y - y * other.x,
    );
  }

  double dot(Vector3D other) => x * other.x + y * other.y + z * other.z;

  @override
  String toString() => 'Vector3D(${x.toStringAsFixed(3)}, ${y.toStringAsFixed(3)}, ${z.toStringAsFixed(3)})';
}

/// Nericell Euler-Rodrigues Virtual Coordinate Reorientation Service.
///
/// Automatically aligns arbitrary smartphone tilt orientation in vehicle cradles/mounts
/// to true vehicular coordinates:
/// - X: Lateral (side-to-side)
/// - Y: Longitudinal (forward driving)
/// - Z: Vertical (orthogonal to road plane, aligned with earth gravity [0, 0, 1])
class NericellService {
  static final NericellService _instance = NericellService._internal();
  factory NericellService() => _instance;
  NericellService._internal() {
    _resetToIdentity();
  }

  // 3x3 Rotation matrix R (row-major: R[row * 3 + col])
  final Float64List _rotationMatrix = Float64List(9);
  bool _isCalibrated = false;

  // Calibration buffer
  final List<Vector3D> _calibrationSamples = [];
  static const int defaultCalibrationSamples = 300; // ~3 seconds at 100Hz

  bool get isCalibrated => _isCalibrated;
  Float64List get rotationMatrix => _rotationMatrix;

  void _resetToIdentity() {
    _rotationMatrix[0] = 1.0; _rotationMatrix[1] = 0.0; _rotationMatrix[2] = 0.0;
    _rotationMatrix[3] = 0.0; _rotationMatrix[4] = 1.0; _rotationMatrix[5] = 0.0;
    _rotationMatrix[6] = 0.0; _rotationMatrix[7] = 0.0; _rotationMatrix[8] = 1.0;
    _isCalibrated = false;
  }

  /// Reset calibration back to identity (raw coordinates).
  void reset() {
    _calibrationSamples.clear();
    _resetToIdentity();
  }

  /// Add a sensor sample during calibration phase.
  /// Returns progress from 0.0 to 1.0.
  double addCalibrationSample(double ax, double ay, double az, {int targetSamples = defaultCalibrationSamples}) {
    _calibrationSamples.add(Vector3D(ax, ay, az));
    return (_calibrationSamples.length / targetSamples).clamp(0.0, 1.0);
  }

  /// Finalize calibration after accumulating samples.
  /// Derives rotation matrix R using Euler-Rodrigues rotation formula.
  /// Returns true if calibration succeeded (sufficient steady gravity detected).
  bool finalizeCalibration() {
    if (_calibrationSamples.length < 50) return false;

    // 1. Compute mean acceleration vector
    double sumX = 0, sumY = 0, sumZ = 0;
    for (final s in _calibrationSamples) {
      sumX += s.x;
      sumY += s.y;
      sumZ += s.z;
    }
    final int count = _calibrationSamples.length;
    final meanVec = Vector3D(sumX / count, sumY / count, sumZ / count);

    // 2. Check stability / variance
    double varX = 0, varY = 0, varZ = 0;
    for (final s in _calibrationSamples) {
      varX += (s.x - meanVec.x) * (s.x - meanVec.x);
      varY += (s.y - meanVec.y) * (s.y - meanVec.y);
      varZ += (s.z - meanVec.z) * (s.z - meanVec.z);
    }
    final totalVar = (varX + varY + varZ) / count;

    // If variance is too high (vehicle was actively accelerating or phone was moving), reject
    if (totalVar > 0.8) {
      _calibrationSamples.clear();
      return false;
    }

    final gravityNorm = meanVec.norm;
    // Check if gravity is approximately 9.8 m/s^2 (+/- 2.5)
    if (gravityNorm < 7.0 || gravityNorm > 12.5) {
      _calibrationSamples.clear();
      return false;
    }

    // 3. Compute Rodrigues rotation aligning mean gravity vector with [0, 0, 1]
    final gUnit = meanVec.normalized();
    const gRef = Vector3D(0.0, 0.0, 1.0);

    final v = gUnit.cross(gRef);
    final s = v.norm; // sin(theta)
    final c = gUnit.dot(gRef); // cos(theta)

    if (s > 1e-5) {
      // Skew-symmetric cross-product matrix [v]_x
      // [  0   -v.z   v.y ]
      // [ v.z    0   -v.x ]
      // [-v.y   v.x    0  ]
      final vx00 = 0.0, vx01 = -v.z, vx02 = v.y;
      final vx10 = v.z, vx11 = 0.0, vx12 = -v.x;
      final vx20 = -v.y, vx21 = v.x, vx22 = 0.0;

      // [v]_x^2
      final vx2_00 = vx01 * vx10 + vx02 * vx20;
      final vx2_01 = vx02 * vx21;
      final vx2_02 = vx01 * vx12;

      final vx2_10 = vx12 * vx20;
      final vx2_11 = vx10 * vx01 + vx12 * vx21;
      final vx2_12 = vx10 * vx02;

      final vx2_20 = vx21 * vx10;
      final vx2_21 = vx20 * vx01;
      final vx2_22 = vx20 * vx02 + vx21 * vx12;

      final factor = (1.0 - c) / (s * s);

      // R = I + [v]_x + [v]_x^2 * factor
      _rotationMatrix[0] = 1.0 + vx00 + vx2_00 * factor;
      _rotationMatrix[1] = 0.0 + vx01 + vx2_01 * factor;
      _rotationMatrix[2] = 0.0 + vx02 + vx2_02 * factor;

      _rotationMatrix[3] = 0.0 + vx10 + vx2_10 * factor;
      _rotationMatrix[4] = 1.0 + vx11 + vx2_11 * factor;
      _rotationMatrix[5] = 0.0 + vx12 + vx2_12 * factor;

      _rotationMatrix[6] = 0.0 + vx20 + vx2_20 * factor;
      _rotationMatrix[7] = 0.0 + vx21 + vx2_21 * factor;
      _rotationMatrix[8] = 1.0 + vx22 + vx2_22 * factor;
    } else {
      // Already aligned (or completely inverted)
      if (c < 0) {
        // Inverted 180 degrees
        _rotationMatrix[0] = 1.0; _rotationMatrix[1] = 0.0; _rotationMatrix[2] = 0.0;
        _rotationMatrix[3] = 0.0; _rotationMatrix[4] = -1.0; _rotationMatrix[5] = 0.0;
        _rotationMatrix[6] = 0.0; _rotationMatrix[7] = 0.0; _rotationMatrix[8] = -1.0;
      } else {
        _resetToIdentity();
      }
    }

    _isCalibrated = true;
    _calibrationSamples.clear();
    return true;
  }

  /// Sets pre-computed rotation matrix (e.g. from isolate or storage).
  void setMatrix(Float64List matrix) {
    assert(matrix.length == 9);
    for (int i = 0; i < 9; i++) {
      _rotationMatrix[i] = matrix[i];
    }
    _isCalibrated = true;
  }

  /// Reorient raw phone acceleration vector [ax, ay, az] into vehicular [rx, ry, rz].
  @pragma('vm:prefer-inline')
  Vector3D reorient(double ax, double ay, double az) {
    if (!_isCalibrated) return Vector3D(ax, ay, az);

    return Vector3D(
      _rotationMatrix[0] * ax + _rotationMatrix[1] * ay + _rotationMatrix[2] * az,
      _rotationMatrix[3] * ax + _rotationMatrix[4] * ay + _rotationMatrix[5] * az,
      _rotationMatrix[6] * ax + _rotationMatrix[7] * ay + _rotationMatrix[8] * az,
    );
  }
}

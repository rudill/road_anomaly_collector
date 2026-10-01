import 'dart:math';

/// Service implementing Spatial Differential Privacy via the Laplacian Mechanism.
///
/// Complies with Sri Lanka Personal Data Protection Act (PDPA) No. 9 of 2022
/// and Section 5.1 of Backend Pipeline Architecture Specification.
/// Scale b = 15.0 meters (epsilon = 1.0, sensitivity Delta_f = 15.0 m).
/// Produces a mean spatial shift of ~14.85 meters to prevent trajectory tracking
/// while preserving road-segment association.
class DifferentialPrivacyService {
  static final DifferentialPrivacyService _instance = DifferentialPrivacyService._internal();
  factory DifferentialPrivacyService() => _instance;
  DifferentialPrivacyService._internal();

  final Random _random = Random();

  /// Default privacy scale b in meters
  static const double defaultScaleB = 15.0; // b = Delta_f / epsilon = 15.0 / 1.0

  /// Meter-to-degree conversion constants (WGS84 spherical approximation)
  static const double metersPerDegreeLat = 111139.0;

  /// Perturbs (latitude, longitude) using Laplacian Differential Privacy.
  ///
  /// Returns a Map with 'latitude' and 'longitude'.
  Map<String, double> perturbCoordinates({
    required double latitude,
    required double longitude,
    double scaleB = defaultScaleB,
    bool enabled = true,
  }) {
    if (!enabled) {
      return {'latitude': latitude, 'longitude': longitude};
    }

    // Generate Laplacian noise along East-West (dx) and North-South (dy) in meters
    final double dx = _sampleLaplace(scaleB);
    final double dy = _sampleLaplace(scaleB);

    // Convert dy (meters) to change in latitude (degrees)
    final double deltaLat = dy / metersPerDegreeLat;

    // Convert dx (meters) to change in longitude (degrees), adjusted for latitude
    final double latRad = latitude * (pi / 180.0);
    final double cosLat = cos(latRad).abs();
    final double metersPerDegreeLng = (cosLat > 1e-6) ? (metersPerDegreeLat * cosLat) : metersPerDegreeLat;
    final double deltaLng = dx / metersPerDegreeLng;

    return {
      'latitude': latitude + deltaLat,
      'longitude': longitude + deltaLng,
    };
  }

  /// Inverse transform sampling of zero-mean Laplace distribution:
  /// z = -sgn(u) * b * ln(1 - 2|u|) where u in (-0.5, 0.5)
  double _sampleLaplace(double b) {
    // Generate u in (-0.5, 0.5), avoiding exact 0.5 to prevent ln(0)
    double u = _random.nextDouble() - 0.5;
    if (u.abs() >= 0.49999999) {
      u = u.sign * 0.49999999;
    }

    final double sgn = u >= 0 ? 1.0 : -1.0;
    return -sgn * b * log(1.0 - 2.0 * u.abs());
  }
}

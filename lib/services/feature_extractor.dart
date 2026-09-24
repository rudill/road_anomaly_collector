import 'dart:math' as math;
import 'dart:typed_data';

/// Feature Extractor for Road Anomaly Detection.
///
/// Converts a 50-sample sliding window (0.5s at 100Hz) of triaxial accelerometer telemetry
/// into the exact 41-dimensional domain-engineered feature vector required by the
/// Random Forest classifier:
/// - 8 statistical moments across 4 channels (X, Y, Z, SVM) = 32 features
/// - 3 spectral FFT moments across 3 channels (X, Y, Z) = 9 features
/// Total: 41 features.
class FeatureExtractor {
  static const int windowSize = 50;
  static const int halfSpectrumSize = 25; // 50 / 2
  static const int nFeatures = 41;

  // Precomputed DFT trigonometric tables (25 x 50)
  static final Float64List _cosTable = _generateCosTable();
  static final Float64List _sinTable = _generateSinTable();

  static Float64List _generateCosTable() {
    final tbl = Float64List(halfSpectrumSize * windowSize);
    for (int k = 0; k < halfSpectrumSize; k++) {
      for (int n = 0; n < windowSize; n++) {
        tbl[k * windowSize + n] = math.cos(2.0 * math.pi * k * n / windowSize);
      }
    }
    return tbl;
  }

  static Float64List _generateSinTable() {
    final tbl = Float64List(halfSpectrumSize * windowSize);
    for (int k = 0; k < halfSpectrumSize; k++) {
      for (int n = 0; n < windowSize; n++) {
        tbl[k * windowSize + n] = math.sin(2.0 * math.pi * k * n / windowSize);
      }
    }
    return tbl;
  }

  // Reusable scratch buffers to eliminate garbage collection in 100Hz streaming loop
  final Float64List _svmBuffer = Float64List(windowSize);
  final Float64List _sortBuffer = Float64List(windowSize);
  final Float64List _fftMagBuffer = Float64List(halfSpectrumSize);
  final Float64List _features = Float64List(nFeatures);

  /// Compute the 41-dimensional feature vector from 50 samples of [x, y, z].
  /// [x], [y], [z] must have length >= 50.
  Float64List extractFeatures(List<double> x, List<double> y, List<double> z) {
    assert(x.length >= windowSize && y.length >= windowSize && z.length >= windowSize);

    // Compute Signal Vector Magnitude (SVM = sqrt(x^2 + y^2 + z^2))
    for (int i = 0; i < windowSize; i++) {
      _svmBuffer[i] = math.sqrt(x[i] * x[i] + y[i] * y[i] + z[i] * z[i]);
    }

    int featOffset = 0;

    // 1. Time-Domain Statistical Moments for X, Y, Z, SVM (4 axes x 8 stats = 32)
    featOffset = _computeAxisStats(x, _features, featOffset);
    featOffset = _computeAxisStats(y, _features, featOffset);
    featOffset = _computeAxisStats(z, _features, featOffset);
    featOffset = _computeAxisStats(_svmBuffer, _features, featOffset);

    // 2. Frequency-Domain Spectral Moments for X, Y, Z (3 axes x 3 stats = 9)
    featOffset = _computeFftStats(x, _features, featOffset);
    featOffset = _computeFftStats(y, _features, featOffset);
    featOffset = _computeFftStats(z, _features, featOffset);

    return _features;
  }

  /// Computes: mean, std, min, max, median, p25, p75, variance
  int _computeAxisStats(List<double> data, Float64List out, int offset) {
    double sum = 0.0;
    double minVal = data[0];
    double maxVal = data[0];

    for (int i = 0; i < windowSize; i++) {
      final val = data[i];
      sum += val;
      if (val < minVal) minVal = val;
      if (val > maxVal) maxVal = val;
      _sortBuffer[i] = val;
    }

    final double mean = sum / windowSize;

    double varSum = 0.0;
    for (int i = 0; i < windowSize; i++) {
      final diff = data[i] - mean;
      varSum += diff * diff;
    }
    final double variance = varSum / windowSize; // ddof=0 matching NumPy default
    final double std = math.sqrt(variance);

    // Percentiles require sorted array
    _sortBuffer.sort();

    // NumPy percentile with linear interpolation:
    // index = q * (N - 1)
    // 25th percentile: 0.25 * 49 = 12.25 -> sortBuffer[12] + 0.25 * (sortBuffer[13] - sortBuffer[12])
    final p25 = _sortBuffer[12] + 0.25 * (_sortBuffer[13] - _sortBuffer[12]);
    // 50th percentile (median): 0.50 * 49 = 24.5 -> sortBuffer[24] + 0.50 * (sortBuffer[25] - sortBuffer[24])
    final median = (_sortBuffer[24] + _sortBuffer[25]) * 0.5;
    // 75th percentile: 0.75 * 49 = 36.75 -> sortBuffer[36] + 0.75 * (sortBuffer[37] - sortBuffer[36])
    final p75 = _sortBuffer[36] + 0.75 * (_sortBuffer[37] - _sortBuffer[36]);

    out[offset] = mean;
    out[offset + 1] = std;
    out[offset + 2] = minVal;
    out[offset + 3] = maxVal;
    out[offset + 4] = median;
    out[offset + 5] = p25;
    out[offset + 6] = p75;
    out[offset + 7] = variance;

    return offset + 8;
  }

  /// Computes: fft_mean, fft_max, fft_std across first 25 half-spectrum bins
  int _computeFftStats(List<double> data, Float64List out, int offset) {
    double sum = 0.0;
    double maxMag = 0.0;

    for (int k = 0; k < halfSpectrumSize; k++) {
      double real = 0.0;
      double imag = 0.0;
      final int rowOffset = k * windowSize;

      for (int n = 0; n < windowSize; n++) {
        final val = data[n];
        real += val * _cosTable[rowOffset + n];
        imag -= val * _sinTable[rowOffset + n];
      }

      final mag = math.sqrt(real * real + imag * imag);
      _fftMagBuffer[k] = mag;
      sum += mag;
      if (mag > maxMag) maxMag = mag;
    }

    final double mean = sum / halfSpectrumSize;

    double varSum = 0.0;
    for (int k = 0; k < halfSpectrumSize; k++) {
      final diff = _fftMagBuffer[k] - mean;
      varSum += diff * diff;
    }
    final double std = math.sqrt(varSum / halfSpectrumSize);

    out[offset] = mean;
    out[offset + 1] = maxMag;
    out[offset + 2] = std;

    return offset + 3;
  }
}

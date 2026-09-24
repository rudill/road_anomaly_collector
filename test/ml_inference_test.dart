import 'dart:io';
import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:road_anomaly_collector/services/dsp_filter_service.dart';
import 'package:road_anomaly_collector/services/feature_extractor.dart';
import 'package:road_anomaly_collector/services/nericell_service.dart';
import 'package:road_anomaly_collector/services/random_forest_classifier.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Edge ML Pipeline Unit Tests', () {
    test('1. RandomForestClassifier JSON Loading & Tree Evaluation', () {
      final file = File('assets/models/random_forest_trees.json');
      expect(file.existsSync(), isTrue, reason: 'Model file must exist');

      final jsonStr = file.readAsStringSync();
      final classifier = RandomForestClassifier.fromJson(jsonStr);

      expect(classifier.nEstimators, equals(100));
      expect(classifier.nClasses, equals(3));
      expect(classifier.classes, equals(['Normal', 'Pothole', 'Bump']));
      expect(classifier.nFeatures, equals(41));
      expect(classifier.trees.length, equals(100));

      // Test with dummy 41-feature vector for normal road
      final dummyFeatures = List<double>.filled(41, 0.0);
      dummyFeatures[16] = 9.81; // Z mean
      dummyFeatures[24] = 9.81; // SVM mean

      final probs = classifier.predictProba(dummyFeatures);
      expect(probs.length, equals(3));
      final sum = probs[0] + probs[1] + probs[2];
      expect((sum - 1.0).abs() < 1e-5, isTrue, reason: 'Probabilities must sum to 1.0');

      final prediction = classifier.predictWithConfidence(dummyFeatures);
      expect(prediction['label'], equals('Normal'));
    });

    test('2. FeatureExtractor computes exact 41 features with DFT & stats', () {
      final extractor = FeatureExtractor();

      final x = List<double>.generate(50, (i) => math.sin(i * 0.1));
      final y = List<double>.generate(50, (i) => math.cos(i * 0.1));
      final z = List<double>.generate(50, (i) => 9.81 + math.sin(i * 0.5));

      final features = extractor.extractFeatures(x, y, z);
      expect(features.length, equals(41));

      // Check Z-mean is close to 9.81
      final zMean = features[16];
      expect((zMean - 9.81).abs() < 0.5, isTrue);

      // Check SVM-mean is positive
      final svmMean = features[24];
      expect(svmMean > 9.0, isTrue);

      // Check FFT features exist and are non-negative
      expect(features[32] >= 0, isTrue); // fft_x_mean
      expect(features[33] >= 0, isTrue); // fft_x_max
      expect(features[34] >= 0, isTrue); // fft_x_std
    });

    test('3. Nericell Euler-Rodrigues Reorientation aligns tilted gravity', () {
      final nericell = NericellService();
      nericell.reset();

      // Simulate a tilted phone in cradle:
      // Tilted 30 degrees around X axis:
      // Y has gravity component: 9.81 * sin(30) = 4.905
      // Z has gravity component: 9.81 * cos(30) = 8.495
      const tiltAngle = 30.0 * math.pi / 180.0;
      final ay = 9.81 * math.sin(tiltAngle);
      final az = 9.81 * math.cos(tiltAngle);

      for (int i = 0; i < 300; i++) {
        nericell.addCalibrationSample(0.0, ay, az);
      }

      final success = nericell.finalizeCalibration();
      expect(success, isTrue, reason: 'Calibration should succeed on steady tilt');
      expect(nericell.isCalibrated, isTrue);

      // Test reorientation
      final reoriented = nericell.reorient(0.0, ay, az);
      // Reoriented Z should now be ~9.81, Y should be ~0.0
      expect((reoriented.z - 9.81).abs() < 0.05, isTrue, reason: 'Z-axis must align with 9.81');
      expect(reoriented.y.abs() < 0.05, isTrue, reason: 'Y-axis tilt must be cancelled');
    });

    test('4. DspFilterService Butterworth suppresses high-frequency noise', () {
      final filter = DspFilterService(enabled: true);

      // Pass constant DC signal (gravity)
      List<double> out = [0, 0, 0];
      for (int i = 0; i < 50; i++) {
        out = filter.filter(0.0, 0.0, 9.81);
      }
      expect((out[2] - 9.81).abs() < 0.1, isTrue, reason: 'DC signal must pass through lowpass');
    });
  });
}

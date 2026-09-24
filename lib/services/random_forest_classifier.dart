// AUTO-GENERATED - DO NOT MODIFY DIRECTLY
// Road Anomaly Detection: Pure Dart Random Forest Tree Evaluator
// Zero C++ / Native JNI dependencies. Fully Isolate-safe.

import 'dart:convert';
import 'dart:typed_data';

/// Single Decision Tree represented with flat contiguous typed arrays.
class DecisionTree {
  final int nodeCount;
  final Int32List childrenLeft;
  final Int32List childrenRight;
  final Int32List feature;
  final Float64List threshold;
  final Float64List probabilities; // Flattened [node_idx * n_classes + class_idx]
  final int nClasses;

  DecisionTree({
    required this.nodeCount,
    required this.childrenLeft,
    required this.childrenRight,
    required this.feature,
    required this.threshold,
    required this.probabilities,
    required this.nClasses,
  });

  factory DecisionTree.fromMap(Map<String, dynamic> map, int nClasses) {
    final int count = map['node_count'] as int;
    final left = Int32List.fromList(List<int>.from(map['children_left'] as List));
    final right = Int32List.fromList(List<int>.from(map['children_right'] as List));
    final feat = Int32List.fromList(List<int>.from(map['feature'] as List));

    final rawThresh = map['threshold'] as List;
    final thresh = Float64List(count);
    for (int i = 0; i < count; i++) {
      thresh[i] = (rawThresh[i] as num).toDouble();
    }

    final rawProbs = map['probabilities'] as List;
    final flatProbs = Float64List(count * nClasses);
    for (int i = 0; i < count; i++) {
      final nodeProb = rawProbs[i] as List;
      for (int c = 0; c < nClasses; c++) {
        flatProbs[i * nClasses + c] = (nodeProb[c] as num).toDouble();
      }
    }

    return DecisionTree(
      nodeCount: count,
      childrenLeft: left,
      childrenRight: right,
      feature: feat,
      threshold: thresh,
      probabilities: flatProbs,
      nClasses: nClasses,
    );
  }

  /// Evaluate this tree for given feature vector. Accumulates into [probAccumulator].
  @pragma('vm:prefer-inline')
  void evaluate(List<double> features, Float64List probAccumulator) {
    int node = 0;
    while (childrenLeft[node] != -1) {
      final int featIdx = feature[node];
      if (features[featIdx] <= threshold[node]) {
        node = childrenLeft[node];
      } else {
        node = childrenRight[node];
      }
    }
    final int offset = node * nClasses;
    for (int c = 0; c < nClasses; c++) {
      probAccumulator[c] += probabilities[offset + c];
    }
  }
}

/// Pure Dart Random Forest Classifier.
class RandomForestClassifier {
  final String modelType;
  final String version;
  final int nEstimators;
  final int nClasses;
  final List<String> classes;
  final int nFeatures;
  final List<String> featureNames;
  final List<DecisionTree> trees;

  RandomForestClassifier({
    required this.modelType,
    required this.version,
    required this.nEstimators,
    required this.nClasses,
    required this.classes,
    required this.nFeatures,
    required this.featureNames,
    required this.trees,
  });

  /// Parse model from parsed JSON map.
  factory RandomForestClassifier.fromMap(Map<String, dynamic> json) {
    final nClasses = json['n_classes'] as int;
    final rawTrees = json['trees'] as List;
    final trees = rawTrees
        .map((t) => DecisionTree.fromMap(t as Map<String, dynamic>, nClasses))
        .toList(growable: false);

    return RandomForestClassifier(
      modelType: json['model_type'] as String? ?? 'RandomForestClassifier',
      version: json['version'] as String? ?? '1.0.0',
      nEstimators: json['n_estimators'] as int,
      nClasses: nClasses,
      classes: List<String>.from(json['classes'] as List),
      nFeatures: json['n_features'] as int,
      featureNames: List<String>.from(json['feature_names'] as List),
      trees: trees,
    );
  }

  /// Parse model directly from JSON string.
  factory RandomForestClassifier.fromJson(String jsonStr) {
    final map = jsonDecode(jsonStr) as Map<String, dynamic>;
    return RandomForestClassifier.fromMap(map);
  }

  /// Predict class probability distribution for a 41-feature input vector.
  /// Returns a Float64List of size [nClasses] summing to 1.0.
  Float64List predictProba(List<double> features) {
    assert(features.length >= nFeatures, 'Expected $nFeatures features, got ${features.length}');
    final accumulator = Float64List(nClasses);

    for (int i = 0; i < trees.length; i++) {
      trees[i].evaluate(features, accumulator);
    }

    final double invTrees = 1.0 / trees.length;
    for (int c = 0; c < nClasses; c++) {
      accumulator[c] *= invTrees;
    }
    return accumulator;
  }

  /// Predict class index (0 = Normal, 1 = Pothole, 2 = Bump).
  int predict(List<double> features) {
    final probs = predictProba(features);
    int bestClass = 0;
    double maxProb = probs[0];
    for (int c = 1; c < nClasses; c++) {
      if (probs[c] > maxProb) {
        maxProb = probs[c];
        bestClass = c;
      }
    }
    return bestClass;
  }

  /// Predict class label name.
  String predictLabel(List<double> features) {
    final idx = predict(features);
    return classes[idx];
  }

  /// Predict with confidence threshold (default 0.65).
  /// If confidence < threshold, returns 'Normal' (default safety fallback).
  Map<String, dynamic> predictWithConfidence(List<double> features, {double threshold = 0.65}) {
    final probs = predictProba(features);
    int bestClass = 0;
    double maxProb = probs[0];
    for (int c = 1; c < nClasses; c++) {
      if (probs[c] > maxProb) {
        maxProb = probs[c];
        bestClass = c;
      }
    }

    final String label = (bestClass != 0 && maxProb < threshold)
        ? classes[0] // Normal fallback
        : classes[bestClass];

    return {
      'label': label,
      'classIndex': bestClass,
      'confidence': maxProb,
      'probabilities': probs,
      'isAnomaly': label != 'Normal',
    };
  }
}

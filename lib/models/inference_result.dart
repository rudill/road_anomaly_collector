/// Holds the output of a single TFLite model inference.
class InferenceResult {
  /// The predicted label (e.g. "Bump" or "Normal").
  final String label;

  /// The confidence score for the predicted label (0.0 – 1.0).
  final double confidence;

  /// When this inference was produced.
  final DateTime timestamp;

  /// Per-label probabilities, keyed by label name.
  final Map<String, double> scores;

  const InferenceResult({
    required this.label,
    required this.confidence,
    required this.timestamp,
    required this.scores,
  });

  /// Whether the prediction exceeds the model's confidence threshold.
  bool get isAboveThreshold => confidence >= 0.6;

  @override
  String toString() =>
      'InferenceResult($label: ${(confidence * 100).toStringAsFixed(1)}%)';
}

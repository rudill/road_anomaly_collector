import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:road_anomaly_collector/models/inference_result.dart';

/// Service that loads and runs the Edge Impulse TFLite model for road anomaly
/// detection.
///
/// The current model was trained at 5 Hz on Z-axis UserAccelerometer data.
/// When a 50 Hz model is available, set [downsampleFactor] to 1.
class TFLiteService {
  static final TFLiteService _instance = TFLiteService._internal();
  factory TFLiteService() => _instance;
  TFLiteService._internal();

  // ── Model configuration (from Edge Impulse model_metadata.h) ──────────

  /// Asset path to the TFLite model file.
  static const String _modelAssetPath = 'assets/models/trained.tflite';

  /// Labels matching the model's output order.
  static const List<String> _labels = ['Bump', 'Normal'];

  /// Number of raw samples the model expects per inference window.
  static const int rawSampleCount = 10;

  /// Number of axes the model uses (Z-axis only).
  static const int rawSamplesPerFrame = 1;

  /// Total raw input size = rawSampleCount × rawSamplesPerFrame.
  static const int dspInputFrameSize = rawSampleCount * rawSamplesPerFrame;

  /// Confidence threshold – predictions below this are considered uncertain.
  static const double confidenceThreshold = 0.6;

  /// Downsample factor: the app samples at 50 Hz, the model expects 5 Hz.
  /// Set to 1 when using a model trained at 50 Hz.
  static const int downsampleFactor = 10;

  // ── Internal state ────────────────────────────────────────────────────

  Interpreter? _interpreter;
  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  /// Circular buffer of Z-axis values (after downsampling).
  final List<double> _sampleBuffer = [];

  /// Counter to track samples for downsampling (pick every Nth sample).
  int _sampleCounter = 0;

  /// Stream controller that emits inference results.
  final _inferenceController = StreamController<InferenceResult>.broadcast();

  /// Listen to this for live inference results.
  Stream<InferenceResult> get inferenceStream => _inferenceController.stream;

  /// The most recent inference result (for quick access without streaming).
  InferenceResult? _lastResult;
  InferenceResult? get lastResult => _lastResult;

  // ── Lifecycle ─────────────────────────────────────────────────────────

  /// Load the TFLite model from assets. Call once at app startup.
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      _interpreter = await Interpreter.fromAsset(_modelAssetPath);
      _isInitialized = true;
      debugPrint('[TFLiteService] Model loaded successfully.');
      debugPrint(
        '[TFLiteService] Input shape: ${_interpreter!.getInputTensor(0).shape}',
      );
      debugPrint(
        '[TFLiteService] Output shape: ${_interpreter!.getOutputTensor(0).shape}',
      );
    } catch (e) {
      debugPrint('[TFLiteService] Failed to load model: $e');
      _isInitialized = false;
    }
  }

  /// Feed a single Z-axis value from the UserAccelerometer stream.
  ///
  /// Downsampling is applied internally: only every [downsampleFactor]-th
  /// sample is kept. When the buffer reaches [rawSampleCount], inference
  /// runs automatically.
  void feedSample(double zValue) {
    if (!_isInitialized) return;

    _sampleCounter++;

    // Downsample: keep only every Nth sample
    if (_sampleCounter % downsampleFactor != 0) return;

    _sampleBuffer.add(zValue);

    // Run inference when we have enough samples
    if (_sampleBuffer.length >= rawSampleCount) {
      _runInference(List<double>.from(_sampleBuffer));
      _sampleBuffer.clear();
    }
  }

  /// Run inference on a complete window of [rawSampleCount] Z-axis samples.
  void _runInference(List<double> samples) {
    if (_interpreter == null || samples.length != rawSampleCount) return;

    try {
      // Prepare input: shape [1, 10] — batch of 1, 10 raw Z-axis values
      final input = [samples];

      // Prepare output: shape [1, 2] — 2 class probabilities
      final output = List.filled(1, List.filled(_labels.length, 0.0));

      _interpreter!.run(input, output);

      final probabilities = output[0];

      // Find the label with the highest probability
      int maxIndex = 0;
      double maxProb = probabilities[0];
      for (int i = 1; i < probabilities.length; i++) {
        if (probabilities[i] > maxProb) {
          maxProb = probabilities[i];
          maxIndex = i;
        }
      }

      // Build scores map
      final scores = <String, double>{};
      for (int i = 0; i < _labels.length; i++) {
        scores[_labels[i]] = probabilities[i];
      }

      final result = InferenceResult(
        label: _labels[maxIndex],
        confidence: maxProb,
        timestamp: DateTime.now(),
        scores: scores,
      );

      _lastResult = result;
      _inferenceController.add(result);

      debugPrint('[TFLiteService] Inference: $result');
    } catch (e) {
      debugPrint('[TFLiteService] Inference error: $e');
    }
  }

  /// Reset the sample buffer (e.g. when stopping/restarting a session).
  void resetBuffer() {
    _sampleBuffer.clear();
    _sampleCounter = 0;
  }

  /// Release model resources.
  void dispose() {
    _interpreter?.close();
    _inferenceController.close();
    _isInitialized = false;
  }
}

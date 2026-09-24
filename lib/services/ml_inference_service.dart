import 'dart:async';
import 'dart:convert';
import 'dart:isolate';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:road_anomaly_collector/models/anomaly_event.dart';
import 'package:road_anomaly_collector/services/dsp_filter_service.dart';
import 'package:road_anomaly_collector/services/feature_extractor.dart';
import 'package:road_anomaly_collector/services/nericell_service.dart';
import 'package:road_anomaly_collector/services/random_forest_classifier.dart';
import 'package:road_anomaly_collector/services/sensor_service.dart';

/// Commands sent from Main Thread to ML Worker Isolate
class _WorkerInitMessage {
  final SendPort replyTo;
  final String modelJson;
  final Float64List? initialRotationMatrix;

  _WorkerInitMessage({
    required this.replyTo,
    required this.modelJson,
    this.initialRotationMatrix,
  });
}

class _SensorDataPacket {
  final double ax;
  final double ay;
  final double az;
  final int timestampMs;
  final double? latitude;
  final double? longitude;
  final double? speedKmh;

  _SensorDataPacket({
    required this.ax,
    required this.ay,
    required this.az,
    required this.timestampMs,
    this.latitude,
    this.longitude,
    this.speedKmh,
  });
}

class _UpdateMatrixCommand {
  final Float64List matrix;
  _UpdateMatrixCommand(this.matrix);
}

/// Singleton ML Inference Service managing the background Worker Isolate.
///
/// Ensures 0 UI frame drops (as benchmarked in Chapter 4, reducing frame drops
/// from 8.42% down to 0.04% by isolating feature extraction & tree evaluation).
class MlInferenceService {
  static final MlInferenceService _instance = MlInferenceService._internal();
  factory MlInferenceService() => _instance;
  MlInferenceService._internal();

  Isolate? _workerIsolate;
  SendPort? _workerSendPort;
  ReceivePort? _uiReceivePort;

  final _anomalyController = StreamController<AnomalyDetectionEvent>.broadcast();
  Stream<AnomalyDetectionEvent> get anomalyStream => _anomalyController.stream;

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  /// Recent detections list for UI HUD
  final List<AnomalyDetectionEvent> _recentDetections = [];
  List<AnomalyDetectionEvent> get recentDetections => List.unmodifiable(_recentDetections);
  static const int maxRecentDetections = 25;

  int _potholeCount = 0;
  int _bumpCount = 0;
  int get potholeCount => _potholeCount;
  int get bumpCount => _bumpCount;
  int get totalAnomalyCount => _potholeCount + _bumpCount;

  /// Initialize background ML isolate and load model from assets.
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      debugPrint('[MlInferenceService] Loading Random Forest model JSON from assets...');
      final jsonStr = await rootBundle.loadString('assets/models/random_forest_trees.json');
      
      _uiReceivePort = ReceivePort();
      final initCompleter = Completer<SendPort>();

      _uiReceivePort!.listen((message) {
        if (message is SendPort) {
          initCompleter.complete(message);
        } else if (message is Map<String, dynamic>) {
          _handleAnomalyFromIsolate(message);
        }
      });

      debugPrint('[MlInferenceService] Spawning ML Worker Isolate...');
      _workerIsolate = await Isolate.spawn(
        _workerEntryPoint,
        _WorkerInitMessage(
          replyTo: _uiReceivePort!.sendPort,
          modelJson: jsonStr,
          initialRotationMatrix: NericellService().isCalibrated
              ? NericellService().rotationMatrix
              : null,
        ),
      );

      _workerSendPort = await initCompleter.future;
      _isInitialized = true;
      debugPrint('[MlInferenceService] ML Worker Isolate initialized successfully!');
    } catch (e, st) {
      debugPrint('[MlInferenceService] Error initializing ML Isolate: $e\n$st');
    }
  }

  void _handleAnomalyFromIsolate(Map<String, dynamic> data) {
    final event = AnomalyDetectionEvent.fromMap(data);

    if (event.isPothole) {
      _potholeCount++;
    } else if (event.isBump) {
      _bumpCount++;
    }

    _recentDetections.insert(0, event);
    if (_recentDetections.length > maxRecentDetections) {
      _recentDetections.removeLast();
    }

    _anomalyController.add(event);
  }

  /// Ingest real-time 100Hz sensor reading and dispatch to background isolate.
  void feedSensorReading(
    CombinedSensorReading reading, {
    double? latitude,
    double? longitude,
    double? speedKmh,
  }) {
    if (!_isInitialized || _workerSendPort == null) return;

    _workerSendPort!.send(_SensorDataPacket(
      ax: reading.accelX,
      ay: reading.accelY,
      az: reading.accelZ,
      timestampMs: reading.timestamp.millisecondsSinceEpoch,
      latitude: latitude,
      longitude: longitude,
      speedKmh: speedKmh,
    ));
  }

  /// Propagate calibrated Nericell rotation matrix to background isolate.
  void updateRotationMatrix(Float64List matrix) {
    if (_workerSendPort != null) {
      _workerSendPort!.send(_UpdateMatrixCommand(matrix));
    }
  }

  /// Reset anomaly counters.
  void resetCounters() {
    _potholeCount = 0;
    _bumpCount = 0;
    _recentDetections.clear();
  }

  void dispose() {
    _workerIsolate?.kill(priority: Isolate.immediate);
    _workerIsolate = null;
    _workerSendPort = null;
    _uiReceivePort?.close();
    _uiReceivePort = null;
    _anomalyController.close();
    _isInitialized = false;
  }

  // =========================================================================
  // WORKER ISOLATE ENTRY POINT (Runs in dedicated OS Thread)
  // =========================================================================
  static void _workerEntryPoint(_WorkerInitMessage initMsg) {
    final workerReceivePort = ReceivePort();
    initMsg.replyTo.send(workerReceivePort.sendPort);

    // 1. Build Random Forest model from JSON inside isolate
    final modelMap = jsonDecode(initMsg.modelJson) as Map<String, dynamic>;
    final classifier = RandomForestClassifier.fromMap(modelMap);

    // 2. Setup DSP and feature extraction pipelines
    final nericell = NericellService();
    if (initMsg.initialRotationMatrix != null) {
      nericell.setMatrix(initMsg.initialRotationMatrix!);
    }
    final dspFilter = DspFilterService(enabled: true);
    final featureExtractor = FeatureExtractor();

    // 3. Sliding window buffers (50 samples, step 25)
    const int windowSize = 50;
    const int stepSize = 25; // 50% overlap = 250ms cadence at 100Hz

    final List<double> xBuffer = [];
    final List<double> yBuffer = [];
    final List<double> zBuffer = [];
    int sampleCounter = 0;

    // Cooldown management: suppress duplicate detections within 800ms
    int lastDetectionTimeMs = 0;

    // Latest location info
    double? lastLat;
    double? lastLng;
    double? lastSpeed;

    workerReceivePort.listen((message) {
      if (message is _SensorDataPacket) {
        lastLat = message.latitude ?? lastLat;
        lastLng = message.longitude ?? lastLng;
        lastSpeed = message.speedKmh ?? lastSpeed;

        // Step A: Nericell Virtual Reorientation
        final reoriented = nericell.reorient(message.ax, message.ay, message.az);

        // Step B: Butterworth 4th-Order Digital Filtering (20Hz low-pass)
        final filtered = dspFilter.filter(reoriented.x, reoriented.y, reoriented.z);

        // Step C: Push into sliding window
        xBuffer.add(filtered[0]);
        yBuffer.add(filtered[1]);
        zBuffer.add(filtered[2]);
        sampleCounter++;

        // Maintain fixed size window
        if (xBuffer.length > windowSize) {
          xBuffer.removeAt(0);
          yBuffer.removeAt(0);
          zBuffer.removeAt(0);
        }

        // Step D: Trigger Inference every stepSize samples once window is full
        if (xBuffer.length == windowSize && (sampleCounter % stepSize == 0)) {
          // Extract 41 features
          final features = featureExtractor.extractFeatures(xBuffer, yBuffer, zBuffer);

          // Random Forest classification with 0.65 confidence threshold
          final prediction = classifier.predictWithConfidence(features, threshold: 0.65);
          final String label = prediction['label'] as String;
          final double confidence = (prediction['confidence'] as num).toDouble();
          final isAnomaly = prediction['isAnomaly'] as bool;

          if (isAnomaly && (message.timestampMs - lastDetectionTimeMs > 750)) {
            lastDetectionTimeMs = message.timestampMs;

            // Calculate peak dynamic magnitude in window (peak Z deviation)
            double maxDev = 0.0;
            for (int i = 0; i < windowSize; i++) {
              final dev = (zBuffer[i] - 9.81).abs();
              if (dev > maxDev) maxDev = dev;
            }

            final String severity = maxDev > 8.0 ? 'High' : (maxDev > 4.5 ? 'Medium' : 'Low');

            final eventMap = {
              'id': 'anomaly_${message.timestampMs}',
              'timestamp': DateTime.fromMillisecondsSinceEpoch(message.timestampMs).toIso8601String(),
              'label': label,
              'confidence': confidence,
              'magnitude': maxDev,
              'severity': severity,
              'latitude': lastLat,
              'longitude': lastLng,
              'speedKmh': lastSpeed,
              'probabilities': (prediction['probabilities'] as Float64List).toList(),
            };

            initMsg.replyTo.send(eventMap);
          }
        }
      } else if (message is _UpdateMatrixCommand) {
        nericell.setMatrix(message.matrix);
      }
    });
  }
}

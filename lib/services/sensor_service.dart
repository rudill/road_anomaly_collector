import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:road_anomaly_collector/models/sensor_data_point.dart';

class SensorService {
  static final SensorService _instance = SensorService._internal();
  factory SensorService() => _instance;
  SensorService._internal();

  final List<SensorDataPoint> _dataBuffer = [];
  StreamSubscription<AccelerometerEvent>? _subscription;

  final _streamController = StreamController<AccelerometerEvent>.broadcast();

  bool _isRecording = false;
  bool get isRecording => _isRecording;

  String _currentLabel = "Normal"; // Variable to hold the manual tag

  Stream<AccelerometerEvent> get sensorStream => _streamController.stream;

  void ensureListening() {
    _startSensorListener();
  }

  // Allow UI to update the current road surface label
  void setLabel(String label) {
    _currentLabel = label;
  }

  Future<void> startRecording() async {
    _dataBuffer.clear();
    _isRecording = true;
    _startSensorListener();
  }

  Future<String?> stopRecording() async {
    if (!_isRecording) return null;

    _isRecording = false;
    _currentLabel = "Normal"; // Reset label after collection

    if (_dataBuffer.isEmpty) return null;

    try {
      final directory = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now()
          .toIso8601String()
          .replaceAll(':', '-')
          .split('.')
          .first;
      final file = File('${directory.path}/sensor_data_$timestamp.csv');

      String csvContent = "Timestamp,X,Y,Z,Label\n";
      final bufferStrings = _dataBuffer.map((e) => e.toCsvRow()).join();
      csvContent += bufferStrings;

      await file.writeAsString(csvContent);
      debugPrint("File saved to ${file.path}");
      return file.path;
    } catch (e) {
      debugPrint("Error saving file: $e");
      return null;
    }
  }

  void _startSensorListener() {
    // Accelerometer stream for display and CSV recording
    _subscription ??= accelerometerEventStream(
      samplingPeriod: const Duration(milliseconds: 20),
    ).listen((event) {
      _streamController.add(event);

      if (_isRecording) {
        _dataBuffer.add(
          SensorDataPoint(
            DateTime.now(),
            event.x,
            event.y,
            event.z,
            _currentLabel, // Dynamic label injected here
          ),
        );
      }
    });
  }

  void dispose() {
    _subscription?.cancel();
    _subscription = null;
    _streamController.close();
  }
}

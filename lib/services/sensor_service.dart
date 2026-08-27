import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:road_anomaly_collector/models/sensor_data_point.dart';

/// Unified sensor reading holding both Accelerometer and Gyroscope readings at a specific timestamp.
class CombinedSensorReading {
  final DateTime timestamp;
  final double accelX;
  final double accelY;
  final double accelZ;
  final double gyroX;
  final double gyroY;
  final double gyroZ;

  CombinedSensorReading({
    required this.timestamp,
    required this.accelX,
    required this.accelY,
    required this.accelZ,
    required this.gyroX,
    required this.gyroY,
    required this.gyroZ,
  });

  // Backward compatibility getters for existing code expecting .x, .y, .z
  double get x => accelX;
  double get y => accelY;
  double get z => accelZ;
}

class SensorService {
  static final SensorService _instance = SensorService._internal();
  factory SensorService() => _instance;
  SensorService._internal();

  // 100Hz sampling period = 10,000 microseconds (10ms)
  static const Duration samplingInterval = Duration(microseconds: 10000);

  final List<SensorDataPoint> _dataBuffer = [];
  StreamSubscription<AccelerometerEvent>? _accelSubscription;
  StreamSubscription<GyroscopeEvent>? _gyroSubscription;

  final _streamController =
      StreamController<CombinedSensorReading>.broadcast();

  bool _isRecording = false;
  bool get isRecording => _isRecording;

  String _currentLabel = "Normal"; // Variable to hold the manual tag

  // Cache latest gyroscope readings for synchronization with accelerometer events
  double _latestGyroX = 0.0;
  double _latestGyroY = 0.0;
  double _latestGyroZ = 0.0;

  Stream<CombinedSensorReading> get sensorStream => _streamController.stream;

  void ensureListening() {
    _startSensorListeners();
  }

  // Allow UI to update the current road surface label
  void setLabel(String label) {
    _currentLabel = label;
  }

  Future<void> startRecording() async {
    _dataBuffer.clear();
    _isRecording = true;
    _startSensorListeners();
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
      final file = File('${directory.path}/sensor_data_100hz_$timestamp.csv');

      final buffer = StringBuffer();
      buffer.writeln(
        "Timestamp,Accel_X,Accel_Y,Accel_Z,Gyro_X,Gyro_Y,Gyro_Z,Label",
      );
      for (final point in _dataBuffer) {
        buffer.write(point.toCsvRow());
      }

      await file.writeAsString(buffer.toString());
      debugPrint(
        "100Hz sensor file saved to ${file.path} (${_dataBuffer.length} records)",
      );
      return file.path;
    } catch (e) {
      debugPrint("Error saving file: $e");
      return null;
    }
  }

  void _startSensorListeners() {
    // 1. Gyroscope stream at 100Hz
    _gyroSubscription ??= gyroscopeEventStream(
      samplingPeriod: samplingInterval,
    ).listen((event) {
      _latestGyroX = event.x;
      _latestGyroY = event.y;
      _latestGyroZ = event.z;
    });

    // 2. Accelerometer stream at 100Hz (synchronizes with latest gyro values)
    _accelSubscription ??= accelerometerEventStream(
      samplingPeriod: samplingInterval,
    ).listen((event) {
      final now = DateTime.now();

      final reading = CombinedSensorReading(
        timestamp: now,
        accelX: event.x,
        accelY: event.y,
        accelZ: event.z,
        gyroX: _latestGyroX,
        gyroY: _latestGyroY,
        gyroZ: _latestGyroZ,
      );

      _streamController.add(reading);

      if (_isRecording) {
        _dataBuffer.add(
          SensorDataPoint(
            timestamp: now,
            accelX: event.x,
            accelY: event.y,
            accelZ: event.z,
            gyroX: _latestGyroX,
            gyroY: _latestGyroY,
            gyroZ: _latestGyroZ,
            label: _currentLabel,
          ),
        );
      }
    });
  }

  void dispose() {
    _accelSubscription?.cancel();
    _accelSubscription = null;
    _gyroSubscription?.cancel();
    _gyroSubscription = null;
    _streamController.close();
  }
}

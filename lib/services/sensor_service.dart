import 'dart:async';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:road_anomaly_collector/models/sensor_data_point.dart';
import 'package:road_anomaly_collector/services/tflite_service.dart';

class SensorService {
  static final SensorService _instance = SensorService._internal();
  factory SensorService() => _instance;
  SensorService._internal();

  final List<SensorDataPoint> _dataBuffer = [];
  StreamSubscription<AccelerometerEvent>? _subscription;

  /// Separate subscription for user accelerometer (gravity-removed) data
  /// that feeds the TFLite inference model.
  StreamSubscription<UserAccelerometerEvent>? _userAccelSubscription;

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
      print("File saved to ${file.path}");
      return file.path;
    } catch (e) {
      print("Error saving file: $e");
      return null;
    }
  }

  void _startSensorListener() {
    // Existing accelerometer stream for display and CSV recording
    if (_subscription == null) {
      _subscription =
          accelerometerEventStream(
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

    // User accelerometer stream (gravity-removed) for TFLite inference.
    // This matches the model's training data which used UserAccelerometerEvent.
    if (_userAccelSubscription == null) {
      _userAccelSubscription =
          userAccelerometerEventStream(
            samplingPeriod: const Duration(milliseconds: 20),
          ).listen((event) {
            TFLiteService().feedSample(event.z);
          });
    }
  }

  void dispose() {
    _subscription?.cancel();
    _userAccelSubscription?.cancel();
    _streamController.close();
    TFLiteService().resetBuffer();
  }
}

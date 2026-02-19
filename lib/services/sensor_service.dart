import 'dart:async';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:road_anomaly_collector/models/sensor_data_point.dart';

class SensorService {
  static final SensorService _instance = SensorService._internal();
  factory SensorService() => _instance;
  SensorService._internal();

  final List<SensorDataPoint> _dataBuffer = [];
  StreamSubscription<UserAccelerometerEvent>? _subscription;
  final _streamController =
      StreamController<UserAccelerometerEvent>.broadcast();

  bool _isRecording = false;
  bool get isRecording => _isRecording;

  Stream<UserAccelerometerEvent> get sensorStream => _streamController.stream;

  void ensureListening() {
    _startSensorListener();
  }

  Future<void> startRecording() async {
    _dataBuffer.clear();
    _isRecording = true;

    // Ensure we are listening to sensors
    _startSensorListener();
  }

  Future<String?> stopRecording() async {
    if (!_isRecording) return null;

    _isRecording = false;
    // We keep the listener active for the UI graph, but stop buffering

    // Save buffer to file
    if (_dataBuffer.isEmpty) return null;

    try {
      final directory = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now()
          .toIso8601String()
          .replaceAll(':', '-')
          .split('.')
          .first;
      final file = File('${directory.path}/sensor_data_$timestamp.csv');

      // Add header
      String csvContent = "Timestamp,X,Y,Z,Label\n";

      // Add data
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
    if (_subscription != null) return;

    _subscription = userAccelerometerEventStream().listen((event) {
      // Always add to stream for UI
      _streamController.add(event);

      // Only buffer if recording
      if (_isRecording) {
        _dataBuffer.add(
          SensorDataPoint(
            DateTime.now(),
            event.x,
            event.y,
            event.z,
            "Normal", // TODO: Make this dynamic if needed
          ),
        );
      }
    });
  }

  void dispose() {
    _subscription?.cancel();
    _streamController.close();
  }
}

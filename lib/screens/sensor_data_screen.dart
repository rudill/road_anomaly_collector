import 'dart:async';
import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:sensors_plus/sensors_plus.dart';

class SensorDataScreen extends StatefulWidget {
  const SensorDataScreen({super.key});

  @override
  State<SensorDataScreen> createState() => _SensorDataScreenState();
}

class _SensorDataScreenState extends State<SensorDataScreen> {
  // Store the raw user accelerometer values
  double _x = 0;
  double _y = 0;
  double _z = 0;

  // StreamSubscription to listen to sensor events
  StreamSubscription<UserAccelerometerEvent>? _accelerometerSubscription;

  @override
  void initState() {
    super.initState();
    _startListening();
  }

  void _startListening() {
    // Listen to userAccelerometerEvents (accelerometer without gravity)
    _accelerometerSubscription = userAccelerometerEventStream().listen((
      UserAccelerometerEvent event,
    ) {
      if (mounted) {
        setState(() {
          _x = event.x;
          _y = event.y;
          _z = event.z;
        });
      }
    });
  }

  @override
  void dispose() {
    _accelerometerSubscription?.cancel();
    super.dispose();
  }

  // Calculate magnitude to determine activity
  double get _magnitude => sqrt(_x * _x + _y * _y + _z * _z);

  // Simple activity classification based on magnitude threshold
  String get _currentActivity {
    // Threshold can be adjusted based on testing, 0.5 is a reasonable starting point for movement
    if (_magnitude < 0.2) {
      return 'Stationary';
    } else if (_magnitude < 1.0) {
      return 'Slow Movement';
    } else {
      return 'Active Movement';
    }
  }

  Color get _activityColor {
    if (_magnitude < 0.2) {
      return CupertinoColors.systemGreen;
    } else if (_magnitude < 1.0) {
      return CupertinoColors
          .systemYellow; // Or systemOrange depends on preference
    } else {
      return CupertinoColors.systemRed;
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(middle: Text('Sensor Data')),
      child: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Activity Status
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: _activityColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _activityColor, width: 2),
                ),
                child: Text(
                  _currentActivity,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: _activityColor,
                  ),
                ),
              ),
              const SizedBox(height: 40),

              // Accelerometer Values
              _buildSensorRow('X-Axis', _x),
              _buildSensorRow('Y-Axis', _y),
              _buildSensorRow('Z-Axis', _z),

              const SizedBox(height: 20),

              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  'Move the device to see real-time updates based on User Accelerometer (without gravity).',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: CupertinoColors.systemGrey),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSensorRow(String label, double value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 32.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
          ),
          Text(
            value.toStringAsFixed(3),
            style: const TextStyle(
              fontSize: 18,
              fontFamily: 'Courier', // Monospaced for better number alignment
            ),
          ),
        ],
      ),
    );
  }
}

import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:road_anomaly_collector/models/sensor_data_point.dart';

class WaveformPainter extends StatefulWidget {
  final bool isActive;
  const WaveformPainter({super.key, required this.isActive});

  @override
  State<WaveformPainter> createState() => _WaveformPainterState();
}

class _WaveformPainterState extends State<WaveformPainter>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  List<double> points = List.generate(50, (_) => 50.0);
  StreamSubscription<UserAccelerometerEvent>? _streamSubscription;

  // --- New Variables for ML Collection ---
  List<SensorDataPoint> mlDataBuffer = [];
  String currentLabel =
      "Normal"; // This will change when you press "Pothole" or "Speed Bump"

  @override
  void initState() {
    super.initState();

    // 1. DATA LOGGING: This runs at the sensor's native hardware speed
    _streamSubscription =
        userAccelerometerEventStream(
          // Optional: If using the latest sensors_plus package, force a high sample rate
          // samplingPeriod: SensorInterval.gameInterval,
        ).listen((event) {
          if (mounted) {
            // Log X, Y, Z immediately with a timestamp for your dataset
            mlDataBuffer.add(
              SensorDataPoint(
                DateTime.now(),
                event.x,
                event.y,
                event.z,
                currentLabel,
              ),
            );

            // Calculate the UI visualizer (we only plot Z for the UI)
            double plottedValue = 50 - (event.z * 5);
            plottedValue = plottedValue.clamp(0.0, 100.0);

            // Add to UI list and keep it at 50 items
            points.add(plottedValue);
            points.removeAt(0);
          }
        });

    // 2. UI REFRESH: This runs independently just to redraw the screen
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat();

    _controller.addListener(() {
      // By calling setState here, we just tell the screen to draw
      // whatever the current state of the 'points' list is, without dropping sensor frames.
      if (widget.isActive && mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _streamSubscription?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: GraphPainter(points));
  }
}

class GraphPainter extends CustomPainter {
  final List<double> points;
  GraphPainter(this.points);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = CupertinoColors.activeBlue.withOpacity(0.5)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    final step = size.width / (points.length - 1);
    for (int i = 0; i < points.length; i++) {
      double x = i * step;
      double h = (points[i] / 100) * size.height;

      // Color spikes red
      if (points[i] > 65 || points[i] < 35) {
        paint.color = CupertinoColors.systemRed.withOpacity(0.8);
      } else {
        paint.color = CupertinoColors.activeBlue.withOpacity(
          0.3 + (i / points.length) * 0.7,
        );
      }

      canvas.drawLine(
        Offset(x, size.height),
        Offset(x, size.height - h),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

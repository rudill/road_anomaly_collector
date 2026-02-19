import 'dart:async';
import 'package:flutter/cupertino.dart';

import 'package:road_anomaly_collector/services/sensor_service.dart';

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
  // ignore: cancel_subscriptions
  StreamSubscription? _subscription;

  @override
  void initState() {
    super.initState();

    // Ensure service is listening
    SensorService().ensureListening();

    _subscription = SensorService().sensorStream.listen((event) {
      if (mounted) {
        double plottedValue = 50 - (event.z * 5);
        plottedValue = plottedValue.clamp(0.0, 100.0);
        points.add(plottedValue);
        points.removeAt(0);
      }
    });

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat();

    _controller.addListener(() {
      if (widget.isActive && mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: GraphPainter(points));
  }
}

// Keeping the original class name for compatibility
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

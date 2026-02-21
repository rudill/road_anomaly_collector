import 'dart:async';
import 'dart:math';
import 'package:flutter/cupertino.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:road_anomaly_collector/services/sensor_service.dart';
import 'package:road_anomaly_collector/manual_data_collection/widgets/diagnostic_card.dart';

class ManualDataCollectionScreen extends StatefulWidget {
  const ManualDataCollectionScreen({super.key});

  @override
  State<ManualDataCollectionScreen> createState() =>
      _ManualDataCollectionScreenState();
}

class _ManualDataCollectionScreenState
    extends State<ManualDataCollectionScreen> {
  StreamSubscription<UserAccelerometerEvent>? _subscription;

  double _x = 0, _y = 0, _z = 0;
  
  // FIX: Use List.generate to create growable lists instead of List.filled
  final List<double> _xHistory = List.generate(50, (_) => 0.0);
  final List<double> _yHistory = List.generate(50, (_) => 0.0);
  final List<double> _zHistory = List.generate(50, (_) => 0.0);

  double _maxX = 0, _maxY = 0, _maxZ = 0;
  String _currentLabel = "Normal"; // Default label for manual collection

  @override
  void initState() {
    super.initState();
    SensorService().setLabel(_currentLabel); // Initialize service label
    _startListening();
  }

  void _startListening() {
    SensorService().ensureListening();

    _subscription = SensorService().sensorStream.listen(
      (event) {
        if (mounted) {
          setState(() {
            _x = event.x;
            _y = event.y;
            _z = event.z;

            _maxX = max(_maxX, event.x.abs());
            _maxY = max(_maxY, event.y.abs());
            _maxZ = max(_maxZ, event.z.abs());

            _xHistory.removeAt(0);
            _xHistory.add(event.x);
            _yHistory.removeAt(0);
            _yHistory.add(event.y);
            _zHistory.removeAt(0);
            _zHistory.add(event.z);
          });
        }
      },
      onError: (error) {
        debugPrint("Sensor Error in Diagnostics: $error");
      },
    );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isRecording = SensorService().isRecording;

    return CupertinoPageScaffold(
      backgroundColor: const Color(0xFF0A0A0B),
      navigationBar: CupertinoNavigationBar(
        backgroundColor: const Color(0xFF0A0A0B).withOpacity(0.8),
        middle: const Text(
          "MANUAL COLLECTION",
          style: TextStyle(
            color: CupertinoColors.white,
            fontSize: 14,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
          ),
        ),
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: const Icon(CupertinoIcons.back, color: CupertinoColors.white),
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  _buildLiveIndicator(),
                  const SizedBox(height: 24),
                  _buildDiagnosticsGrid(),
                  const SizedBox(height: 24),
                  _buildRealTimeChart(),
                  const SizedBox(height: 24),
                  _buildLabelSelector(), // Added label selector
                  const SizedBox(height: 24),
                  _buildSessionInfo(),
                ],
              ),
            ),
            _buildActionFooter(isRecording),
          ],
        ),
      ),
    );
  }

  Widget _buildLabelSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "ANOMALY TAGGING",
          style: TextStyle(
            color: CupertinoColors.systemGrey,
            fontSize: 10,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: CupertinoSlidingSegmentedControl<String>(
            backgroundColor: CupertinoColors.white.withOpacity(0.05),
            thumbColor: CupertinoColors.activeBlue,
            groupValue: _currentLabel,
            children: {
              "Normal": _buildSegmentText("Normal"),
              "Pothole": _buildSegmentText("Pothole"),
              "Bump": _buildSegmentText("Bump"),
            },
            onValueChanged: (String? value) {
              if (value != null) {
                setState(() {
                  _currentLabel = value;
                });
                SensorService().setLabel(value); // Send new label to service
              }
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSegmentText(String text) {
    final isSelected = _currentLabel == text;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Text(
        text,
        style: TextStyle(
          color: isSelected ? CupertinoColors.white : CupertinoColors.systemGrey,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }

  // ... [Keep _buildLiveIndicator, _buildDiagnosticsGrid, _buildRealTimeChart, _buildSessionInfo exactly as they were] ...
  
  Widget _buildLiveIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: CupertinoColors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: CupertinoColors.white.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          const _PulseIndicator(),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "LIVE DIAGNOSTICS",
                  style: TextStyle(
                    color: CupertinoColors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    letterSpacing: 1,
                  ),
                ),
                Text(
                  "Sampling rate: 100Hz (Active)",
                  style: TextStyle(
                    color: CupertinoColors.systemGrey,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Text(
            DateTime.now().toString().split(' ').last.substring(0, 8),
            style: const TextStyle(
              color: CupertinoColors.systemGrey,
              fontSize: 13,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDiagnosticsGrid() {
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 0.8,
      children: [
        DiagnosticCard(
          title: "X-AXIS",
          value: _x.toStringAsFixed(2),
          subtitle: "Max: ${_maxX.toStringAsFixed(1)}",
          color: CupertinoColors.systemBlue,
          icon: CupertinoIcons.arrow_left_right,
        ),
        DiagnosticCard(
          title: "Y-AXIS",
          value: _y.toStringAsFixed(2),
          subtitle: "Max: ${_maxY.toStringAsFixed(1)}",
          color: CupertinoColors.systemGreen,
          icon: CupertinoIcons.arrow_up_down,
        ),
        DiagnosticCard(
          title: "Z-AXIS",
          value: _z.toStringAsFixed(2),
          subtitle: "Max: ${_maxZ.toStringAsFixed(1)}",
          color: CupertinoColors.systemPurple,
          icon: CupertinoIcons.layers_alt,
        ),
      ],
    );
  }

  Widget _buildRealTimeChart() {
    return Container(
      height: 200,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CupertinoColors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: CupertinoColors.white.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "WAVEFORM DATA",
            style: TextStyle(
              color: CupertinoColors.systemGrey,
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: CustomPaint(
              painter: _MultiAxisPainter(
                xHistory: _xHistory,
                yHistory: _yHistory,
                zHistory: _zHistory,
              ),
              size: Size.infinite,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionInfo() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: CupertinoColors.activeBlue.withOpacity(0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: CupertinoColors.activeBlue.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          const _InfoRow(label: "Device Info", value: "Mobile Unit #041"),
          Container(height: 1, color: CupertinoColors.white.withOpacity(0.05)),
          const _InfoRow(
            label: "Location",
            value: "GPS Locked (High Accuracy)",
          ),
          Container(height: 1, color: CupertinoColors.white.withOpacity(0.05)),
          const _InfoRow(label: "Status", value: "Awaiting Trigger"),
        ],
      ),
    );
  }

  Widget _buildActionFooter(bool isRecording) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0A0B),
        boxShadow: [
          BoxShadow(
            color: CupertinoColors.black.withOpacity(0.5),
            blurRadius: 40,
            offset: const Offset(0, -10),
          ),
        ],
      ),
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: () async {
          if (isRecording) {
            await SensorService().stopRecording();
          } else {
            await SensorService().startRecording();
          }
          setState(() {});
        },
        child: Container(
          width: double.infinity,
          height: 60,
          decoration: BoxDecoration(
            color: isRecording
                ? CupertinoColors.systemRed
                : CupertinoColors.activeBlue,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color:
                    (isRecording
                            ? CupertinoColors.systemRed
                            : CupertinoColors.activeBlue)
                        .withOpacity(0.3),
                blurRadius: 20,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isRecording
                      ? CupertinoIcons.stop_fill
                      : CupertinoIcons.play_fill,
                  color: CupertinoColors.white,
                ),
                const SizedBox(width: 10),
                Text(
                  isRecording ? "STOP COLLECTION" : "START COLLECTION",
                  style: const TextStyle(
                    color: CupertinoColors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ... [Keep _PulseIndicator, _InfoRow, and _MultiAxisPainter exactly as they were] ...

class _PulseIndicator extends StatefulWidget {
  const _PulseIndicator();

  @override
  State<_PulseIndicator> createState() => _PulseIndicatorState();
}

class _PulseIndicatorState extends State<_PulseIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: CupertinoColors.activeGreen,
            boxShadow: [
              BoxShadow(
                color: CupertinoColors.activeGreen.withOpacity(
                  0.5 * _controller.value,
                ),
                blurRadius: 8,
                spreadRadius: 4 * _controller.value,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: CupertinoColors.systemGrey,
              fontSize: 13,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: CupertinoColors.white,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _MultiAxisPainter extends CustomPainter {
  final List<double> xHistory;
  final List<double> yHistory;
  final List<double> zHistory;

  _MultiAxisPainter({
    required this.xHistory,
    required this.yHistory,
    required this.zHistory,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final xPaint = Paint()
      ..color = CupertinoColors.systemBlue
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final yPaint = Paint()
      ..color = CupertinoColors.systemGreen
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final zPaint = Paint()
      ..color = CupertinoColors.systemPurple
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    _drawPath(canvas, size, xHistory, xPaint);
    _drawPath(canvas, size, yHistory, yPaint);
    _drawPath(canvas, size, zHistory, zPaint);
  }

  void _drawPath(Canvas canvas, Size size, List<double> history, Paint paint) {
    if (history.isEmpty) return;

    final path = Path();
    final stepX = size.width / (history.length - 1);
    final centerY = size.height / 2;
    final scaleY = size.height / 20;

    path.moveTo(0, centerY - (history[0] * scaleY));

    for (int i = 1; i < history.length; i++) {
      path.lineTo(i * stepX, centerY - (history[i] * scaleY));
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _MultiAxisPainter oldDelegate) => true;
}
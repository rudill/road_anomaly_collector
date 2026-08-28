import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:road_anomaly_collector/services/sensor_service.dart';
import 'package:road_anomaly_collector/widgets/detection_tile.dart';
import 'package:road_anomaly_collector/widgets/stat_card.dart';
import 'package:road_anomaly_collector/widgets/waveform_painter.dart';

class SensorAnomalyEvent {
  final String label;
  final double magnitude;
  final DateTime timestamp;
  final String severity;

  const SensorAnomalyEvent({
    required this.label,
    required this.magnitude,
    required this.timestamp,
    required this.severity,
  });
}

class SensingTab extends StatefulWidget {
  final bool isRecording;
  final int potholeCount;
  final VoidCallback onToggle;

  const SensingTab({
    super.key,
    required this.isRecording,
    required this.potholeCount,
    required this.onToggle,
  });

  @override
  State<SensingTab> createState() => _SensingTabState();
}

class _SensingTabState extends State<SensingTab> {
  StreamSubscription<CombinedSensorReading>? _sensorSubscription;

  /// Live sensor state
  double _currentZ = 0.0;
  int _anomalyCount = 0;
  final List<SensorAnomalyEvent> _recentDetections = [];
  static const int _maxRecentDetections = 10;
  DateTime _lastDetectionTime = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void initState() {
    super.initState();
    _subscribeToSensors();
  }

  void _subscribeToSensors() {
    SensorService().ensureListening();
    _sensorSubscription = SensorService().sensorStream.listen((event) {
      if (mounted) {
        setState(() {
          _currentZ = event.accelZ;

          // Physical threshold anomaly detection when recording
          if (widget.isRecording) {
            final zDeviation = (event.z - 9.8).abs();
            final now = DateTime.now();
            if (zDeviation > 5.0 &&
                now.difference(_lastDetectionTime).inMilliseconds > 800) {
              _lastDetectionTime = now;
              _anomalyCount++;
              final severity = zDeviation > 10.0 ? "High" : "Medium";
              _recentDetections.insert(
                0,
                SensorAnomalyEvent(
                  label: event.accelZ > 9.8 ? "Bump" : "Pothole / Dip",
                  magnitude: zDeviation,
                  timestamp: now,
                  severity: severity,
                ),
              );
              if (_recentDetections.length > _maxRecentDetections) {
                _recentDetections.removeLast();
              }
            }
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _sensorSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: const Color(0xFF0A0A0B),
      child: Stack(
        children: [
          SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const SizedBox(height: 20),
                _buildHeader(),
                const SizedBox(height: 24),
                _buildStatusIndicator(),
                const SizedBox(height: 24),
                _buildLiveGraph(),
                const SizedBox(height: 24),
                _buildStatsGrid(),
                const SizedBox(height: 24),
                _buildDetectionList(),
                const SizedBox(height: 100), // Space for FAB
              ],
            ),
          ),
          // Floating Action Button
          Positioned(
            bottom: 100,
            right: 20,
            child: GestureDetector(
              onTap: () async {
                if (SensorService().isRecording) {
                  await SensorService().stopRecording();
                } else {
                  await SensorService().startRecording();
                }
                widget.onToggle();
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  color: widget.isRecording
                      ? CupertinoColors.systemRed
                      : CupertinoColors.activeBlue,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color:
                          (widget.isRecording
                                  ? CupertinoColors.systemRed
                                  : CupertinoColors.activeBlue)
                              .withOpacity(0.3),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: Icon(
                  widget.isRecording
                      ? CupertinoIcons.stop_fill
                      : CupertinoIcons.play_fill,
                  color: CupertinoColors.white,
                  size: 30,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "RoadTrack",
              style: TextStyle(
                fontSize: 34,
                fontWeight: FontWeight.bold,
                letterSpacing: -1,
                color: CupertinoColors.white,
              ),
            ),
            Text(
              "Sensor Data Collection",
              style: TextStyle(color: CupertinoColors.systemGrey, fontSize: 14),
            ),
          ],
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color:
                (widget.isRecording
                        ? CupertinoColors.systemRed
                        : CupertinoColors.activeGreen)
                    .withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color:
                  (widget.isRecording
                          ? CupertinoColors.systemRed
                          : CupertinoColors.activeGreen)
                      .withOpacity(0.3),
            ),
          ),
          child: Row(
            children: [
              Icon(
                CupertinoIcons.circle_fill,
                size: 8,
                color: widget.isRecording
                    ? CupertinoColors.systemRed
                    : CupertinoColors.activeGreen,
              ),
              const SizedBox(width: 6),
              Text(
                widget.isRecording ? "RECORDING" : "SENSORS READY",
                style: TextStyle(
                  color: widget.isRecording
                      ? CupertinoColors.systemRed
                      : CupertinoColors.activeGreen,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Live sensor collection status indicator
  Widget _buildStatusIndicator() {
    final indicatorColor = widget.isRecording
        ? CupertinoColors.systemRed
        : CupertinoColors.activeGreen;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: indicatorColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: indicatorColor.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: indicatorColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              widget.isRecording
                  ? CupertinoIcons.waveform_path_badge_plus
                  : CupertinoIcons.checkmark_shield_fill,
              color: indicatorColor,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.isRecording ? "RECORDING ACTIVE" : "SYSTEM STANDBY",
                  style: TextStyle(
                    color: indicatorColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  widget.isRecording
                      ? "Logging 100Hz 6-DOF sensor stream to CSV"
                      : "Tap play button to begin collection",
                  style: const TextStyle(
                    color: CupertinoColors.systemGrey,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Text(
            "LIVE",
            style: TextStyle(
              color: indicatorColor,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLiveGraph() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: CupertinoColors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: CupertinoColors.white.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    CupertinoIcons.waveform,
                    size: 18,
                    color: CupertinoColors.activeBlue,
                  ),
                  SizedBox(width: 8),
                  Text(
                    "Z-Axis Acceleration",
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: CupertinoColors.white,
                    ),
                  ),
                ],
              ),
              Text(
                "100Hz",
                style: TextStyle(
                  color: CupertinoColors.systemGrey,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 100,
            width: double.infinity,
            child: WaveformPainter(isActive: widget.isRecording),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid() {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      childAspectRatio: 1.5,
      children: [
        StatCard(
          label: "ANOMALIES",
          value: "$_anomalyCount",
          unit: "Spikes",
          icon: CupertinoIcons.exclamationmark_triangle,
          color: CupertinoColors.systemRed,
        ),
        const StatCard(
          label: "SAMPLING",
          value: "100",
          unit: "Hz",
          icon: CupertinoIcons.waveform_path,
          color: CupertinoColors.systemYellow,
        ),
        const StatCard(
          label: "SPEED",
          value: "—",
          unit: "km/h",
          icon: CupertinoIcons.speedometer,
          color: CupertinoColors.activeBlue,
        ),
        StatCard(
          label: "Z-FORCE",
          value: _currentZ.toStringAsFixed(1),
          unit: "m/s²",
          icon: CupertinoIcons.layers_alt,
          color: CupertinoColors.systemPurple,
        ),
      ],
    );
  }

  Widget _buildDetectionList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "RECENT DETECTIONS",
          style: TextStyle(
            color: CupertinoColors.systemGrey,
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 12),
        if (_recentDetections.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: CupertinoColors.white.withOpacity(0.03),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: CupertinoColors.white.withOpacity(0.06),
              ),
            ),
            child: const Center(
              child: Text(
                "No anomalies detected yet",
                style: TextStyle(
                  color: CupertinoColors.systemGrey,
                  fontSize: 13,
                ),
              ),
            ),
          )
        else
          ..._recentDetections.map((detection) {
            final ago = DateTime.now().difference(detection.timestamp);
            final timeAgo = ago.inMinutes < 1
                ? '${ago.inSeconds}s ago'
                : '${ago.inMinutes}m ago';
            return DetectionTile(
              title: detection.label,
              conf: 'Δ ${detection.magnitude.toStringAsFixed(1)} m/s²',
              time: timeAgo,
              severity: detection.severity,
            );
          }),
      ],
    );
  }
}

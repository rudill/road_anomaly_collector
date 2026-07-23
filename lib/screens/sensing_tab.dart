// ... (imports remain the same)
import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:road_anomaly_collector/services/sensor_service.dart';
import 'package:road_anomaly_collector/services/tflite_service.dart';
import 'package:road_anomaly_collector/models/inference_result.dart';
import 'package:road_anomaly_collector/widgets/detection_tile.dart';
import 'package:road_anomaly_collector/widgets/stat_card.dart';
import 'package:road_anomaly_collector/widgets/waveform_painter.dart';

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
  StreamSubscription<InferenceResult>? _inferenceSubscription;

  /// Live inference state
  String _currentLabel = 'Normal';
  double _currentConfidence = 0.0;

  /// Tracked detections
  int _anomalyCount = 0;
  final List<InferenceResult> _recentDetections = [];
  static const int _maxRecentDetections = 10;

  @override
  void initState() {
    super.initState();
    _subscribeToInference();
  }

  void _subscribeToInference() {
    _inferenceSubscription = TFLiteService().inferenceStream.listen((result) {
      if (mounted) {
        setState(() {
          _currentLabel = result.label;
          _currentConfidence = result.confidence;

          // Track bump detections that exceed confidence threshold
          if (result.label == 'Bump' && result.isAboveThreshold) {
            _anomalyCount++;
            _recentDetections.insert(0, result);
            if (_recentDetections.length > _maxRecentDetections) {
              _recentDetections.removeLast();
            }
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _inferenceSubscription?.cancel();
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
                _buildInferenceIndicator(),
                const SizedBox(height: 24),
                // Pass true/false to painter based on service or prop
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
                // Call the parent toggle to update UI (if parent still controls state)
                // Or force rebuild if we switch to local state.
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
              "RoadTrack AI",
              style: TextStyle(
                fontSize: 34,
                fontWeight: FontWeight.bold,
                letterSpacing: -1,
                color: CupertinoColors.white,
              ),
            ),
            Text(
              "Session: #RS-2024-082",
              style: TextStyle(color: CupertinoColors.systemGrey, fontSize: 14),
            ),
          ],
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color:
                (TFLiteService().isInitialized
                        ? CupertinoColors.activeGreen
                        : CupertinoColors.systemYellow)
                    .withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color:
                  (TFLiteService().isInitialized
                          ? CupertinoColors.activeGreen
                          : CupertinoColors.systemYellow)
                      .withOpacity(0.3),
            ),
          ),
          child: Row(
            children: [
              Icon(
                CupertinoIcons.circle_fill,
                size: 8,
                color: TFLiteService().isInitialized
                    ? CupertinoColors.activeGreen
                    : CupertinoColors.systemYellow,
              ),
              const SizedBox(width: 6),
              Text(
                TFLiteService().isInitialized ? "MODEL READY" : "NO MODEL",
                style: TextStyle(
                  color: TFLiteService().isInitialized
                      ? CupertinoColors.activeGreen
                      : CupertinoColors.systemYellow,
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

  /// Live inference result indicator
  Widget _buildInferenceIndicator() {
    final isBump = _currentLabel == 'Bump' && _currentConfidence >= 0.6;
    final indicatorColor = isBump
        ? CupertinoColors.systemRed
        : CupertinoColors.activeGreen;
    final confidencePercent = (_currentConfidence * 100).toStringAsFixed(1);

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
              isBump
                  ? CupertinoIcons.exclamationmark_triangle_fill
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
                  _currentLabel.toUpperCase(),
                  style: TextStyle(
                    color: indicatorColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  "Confidence: $confidencePercent%",
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
                "50Hz",
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
          label: "DETECTED",
          value: "$_anomalyCount",
          unit: "Anomalies",
          icon: CupertinoIcons.exclamationmark_triangle,
          color: CupertinoColors.systemRed,
        ),
        const StatCard(
          label: "IRI INDEX",
          value: "—",
          unit: "m/km",
          icon: CupertinoIcons.graph_square,
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
          label: "CONFIDENCE",
          value: (_currentConfidence * 100).toStringAsFixed(0),
          unit: "%",
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
              conf: '${(detection.confidence * 100).toStringAsFixed(0)}%',
              time: timeAgo,
              severity: detection.confidence >= 0.8 ? "High" : "Medium",
            );
          }),
      ],
    );
  }
}

import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:road_anomaly_collector/models/anomaly_event.dart';
import 'package:road_anomaly_collector/services/ml_inference_service.dart';
import 'package:road_anomaly_collector/services/nericell_service.dart';
import 'package:road_anomaly_collector/services/sensor_service.dart';
import 'package:road_anomaly_collector/widgets/detection_tile.dart';
import 'package:road_anomaly_collector/widgets/nericell_calibration_dialog.dart';
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
  StreamSubscription<CombinedSensorReading>? _sensorSubscription;
  StreamSubscription<AnomalyDetectionEvent>? _anomalySubscription;

  /// Live sensor state
  double _currentZ = 0.0;
  AnomalyDetectionEvent? _latestAlertEvent;
  Timer? _alertDismissTimer;

  @override
  void initState() {
    super.initState();
    _initMlPipeline();
    _subscribeToSensors();
  }

  Future<void> _initMlPipeline() async {
    await MlInferenceService().initialize();
    _anomalySubscription = MlInferenceService().anomalyStream.listen((event) {
      if (!mounted) return;

      // Haptic feedback alert
      if (event.isPothole) {
        HapticFeedback.heavyImpact();
      } else {
        HapticFeedback.mediumImpact();
      }

      setState(() {
        _latestAlertEvent = event;
      });

      _alertDismissTimer?.cancel();
      _alertDismissTimer = Timer(const Duration(milliseconds: 2500), () {
        if (mounted) {
          setState(() {
            _latestAlertEvent = null;
          });
        }
      });
    });
  }

  void _subscribeToSensors() {
    SensorService().ensureListening();
    _sensorSubscription = SensorService().sensorStream.listen((event) {
      if (mounted) {
        setState(() {
          _currentZ = event.accelZ;
        });
      }
    });
  }

  @override
  void dispose() {
    _sensorSubscription?.cancel();
    _anomalySubscription?.cancel();
    _alertDismissTimer?.cancel();
    super.dispose();
  }

  void _showCalibrationDialog() {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => const NericellCalibrationDialog(),
    ).then((_) {
      if (mounted) setState(() {});
    });
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
                const SizedBox(height: 10),
                _buildHeader(),
                const SizedBox(height: 16),
                if (_latestAlertEvent != null) ...[
                  _buildLiveAlertBanner(_latestAlertEvent!),
                  const SizedBox(height: 16),
                ],
                _buildStatusIndicator(),
                const SizedBox(height: 20),
                _buildLiveGraph(),
                const SizedBox(height: 20),
                _buildStatsGrid(),
                const SizedBox(height: 20),
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
                      color: (widget.isRecording
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
    final isCalibrated = NericellService().isCalibrated;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "RoadTrack",
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -1,
                    color: CupertinoColors.white,
                  ),
                ),
                Text(
                  "Edge AI Road Surveillance",
                  style: TextStyle(color: CupertinoColors.systemGrey, fontSize: 13),
                ),
              ],
            ),
            // Recording status pill
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: (widget.isRecording
                        ? CupertinoColors.systemRed
                        : CupertinoColors.activeGreen)
                    .withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: (widget.isRecording
                          ? CupertinoColors.systemRed
                          : CupertinoColors.activeGreen)
                      .withOpacity(0.35),
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
                    widget.isRecording ? "RECORDING" : "ML ACTIVE",
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
        ),
        const SizedBox(height: 12),
        // Nericell Mount Calibration Badge Button
        GestureDetector(
          onTap: _showCalibrationDialog,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: (isCalibrated
                      ? CupertinoColors.activeGreen
                      : CupertinoColors.systemOrange)
                  .withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: (isCalibrated
                        ? CupertinoColors.activeGreen
                        : CupertinoColors.systemOrange)
                    .withOpacity(0.3),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  CupertinoIcons.compass,
                  size: 14,
                  color: isCalibrated
                      ? CupertinoColors.activeGreen
                      : CupertinoColors.systemOrange,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    isCalibrated ? "MOUNT: CALIBRATED (NERICELL)" : "MOUNT: UNCALIBRATED (TAP TO CALIBRATE)",
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isCalibrated
                          ? CupertinoColors.activeGreen
                          : CupertinoColors.systemOrange,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  CupertinoIcons.chevron_right,
                  size: 11,
                  color: (isCalibrated
                          ? CupertinoColors.activeGreen
                          : CupertinoColors.systemOrange)
                      .withOpacity(0.8),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// High-visibility flash alert banner when an anomaly is detected
  Widget _buildLiveAlertBanner(AnomalyDetectionEvent event) {
    final isPothole = event.isPothole;
    final color = isPothole ? CupertinoColors.systemRed : CupertinoColors.systemOrange;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.3),
            blurRadius: 15,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isPothole
                  ? CupertinoIcons.exclamationmark_triangle_fill
                  : CupertinoIcons.arrow_up_circle_fill,
              color: CupertinoColors.white,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "${event.label.toUpperCase()} DETECTED",
                  style: const TextStyle(
                    color: CupertinoColors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  "Confidence: ${(event.confidence * 100).toStringAsFixed(0)}% • Impact: ${event.magnitude.toStringAsFixed(1)} m/s² (${event.severity})",
                  style: TextStyle(
                    color: CupertinoColors.white.withOpacity(0.85),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
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
                  widget.isRecording ? "RECORDING ACTIVE" : "EDGE AI ACTIVE",
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
                      ? "Logging 100Hz 6-DOF stream & running ML Isolate"
                      : "Real-time Pure Dart Random Forest running in Isolate",
                  style: const TextStyle(
                    color: CupertinoColors.systemGrey,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Text(
            "100 Hz",
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Row(
                  children: [
                    Icon(
                      CupertinoIcons.waveform,
                      size: 18,
                      color: CupertinoColors.activeBlue,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "Z-Axis Acceleration (Vehicular)",
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: CupertinoColors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                "4th-Order Butterworth",
                style: TextStyle(
                  color: CupertinoColors.systemGrey,
                  fontSize: 11,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 100,
            width: double.infinity,
            child: WaveformPainter(isActive: true),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid() {
    final speed = SensorService().latestPosition?.speed;
    final speedText = (speed != null && speed >= 0)
        ? (speed * 3.6).toStringAsFixed(0)
        : "—";

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      childAspectRatio: 1.5,
      children: [
        StatCard(
          label: "POTHOLES",
          value: "${MlInferenceService().potholeCount}",
          unit: "ML Found",
          icon: CupertinoIcons.exclamationmark_triangle,
          color: CupertinoColors.systemRed,
        ),
        StatCard(
          label: "SPEED BUMPS",
          value: "${MlInferenceService().bumpCount}",
          unit: "ML Found",
          icon: CupertinoIcons.arrow_up_circle,
          color: CupertinoColors.systemOrange,
        ),
        StatCard(
          label: "GPS SPEED",
          value: speedText,
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
    final detections = MlInferenceService().recentDetections;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              "REAL-TIME ML DETECTIONS",
              style: TextStyle(
                color: CupertinoColors.systemGrey,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
            if (detections.isNotEmpty)
              GestureDetector(
                onTap: () {
                  setState(() {
                    MlInferenceService().resetCounters();
                  });
                },
                child: const Text(
                  "Clear",
                  style: TextStyle(
                    color: CupertinoColors.activeBlue,
                    fontSize: 12,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (detections.isEmpty)
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
                "No road anomalies detected by ML yet",
                style: TextStyle(
                  color: CupertinoColors.systemGrey,
                  fontSize: 13,
                ),
              ),
            ),
          )
        else
          ...detections.map((detection) {
            final ago = DateTime.now().difference(detection.timestamp);
            final timeAgo = ago.inMinutes < 1
                ? '${ago.inSeconds}s ago'
                : '${ago.inMinutes}m ago';
            return DetectionTile(
              title: detection.label,
              conf: '${(detection.confidence * 100).toStringAsFixed(0)}% • Δ ${detection.magnitude.toStringAsFixed(1)} m/s²',
              time: timeAgo,
              severity: detection.severity,
            );
          }),
      ],
    );
  }
}

import 'package:flutter/cupertino.dart';
import 'package:road_anomaly_collector/widgets/waveform_painter.dart';
import 'package:road_anomaly_collector/widgets/stat_card.dart';
import 'package:road_anomaly_collector/widgets/detection_tile.dart';

class SensingTab extends StatelessWidget {
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
            bottom: 30,
            right: 20,
            child: GestureDetector(
              onTap: onToggle,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  color: isRecording
                      ? CupertinoColors.systemRed
                      : CupertinoColors.activeBlue,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color:
                          (isRecording
                                  ? CupertinoColors.systemRed
                                  : CupertinoColors.activeBlue)
                              .withOpacity(0.3),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: Icon(
                  isRecording
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
            color: CupertinoColors.activeGreen.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: CupertinoColors.activeGreen.withOpacity(0.3),
            ),
          ),
          child: const Row(
            children: [
              Icon(
                CupertinoIcons.circle_fill,
                size: 8,
                color: CupertinoColors.activeGreen,
              ),
              SizedBox(width: 6),
              Text(
                "READY",
                style: TextStyle(
                  color: CupertinoColors.activeGreen,
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
                    style: TextStyle(fontWeight: FontWeight.w600),
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
            child: WaveformPainter(isActive: isRecording),
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
      children: const [
        StatCard(
          label: "DETECTED",
          value: "14",
          unit: "Anomalies",
          icon: CupertinoIcons.exclamationmark_triangle,
          color: CupertinoColors.systemRed,
        ),
        StatCard(
          label: "IRI INDEX",
          value: "2.4",
          unit: "m/km",
          icon: CupertinoIcons.graph_square,
          color: CupertinoColors.systemYellow,
        ),
        StatCard(
          label: "SPEED",
          value: "45",
          unit: "km/h",
          icon: CupertinoIcons.speedometer,
          color: CupertinoColors.activeBlue,
        ),
        StatCard(
          label: "ACCURACY",
          value: "94",
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
        const DetectionTile(
          title: "Pothole",
          conf: "98%",
          time: "2m ago",
          severity: "High",
        ),
        const DetectionTile(
          title: "Surface Crack",
          conf: "82%",
          time: "5m ago",
          severity: "Low",
        ),
      ],
    );
  }
}

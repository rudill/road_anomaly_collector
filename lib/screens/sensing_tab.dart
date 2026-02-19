// ... (imports remain the same)
import 'package:flutter/cupertino.dart';
import 'package:road_anomaly_collector/services/sensor_service.dart';
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
  // We need to manage local state for the button or rely on parent.
  // The prompt implies I should refactor to use SensorService.
  // However, the HomeScreen (parent) currently manages 'isRecording' state and passes it down.
  // I should probably lift that state management to SensorService entirely or update the parent.
  // For least friction, let's update this widget to call Service,
  // and arguably the parent should rebuild or we convert this to check service state.

  // Actually, HomeScreen passes `onToggle`. If I change `SensingTab` freely,
  // I should probably ignore the props and use Service state,
  // BUT HomeScreen might display other things.
  // efficient approach: Update HomeScreen to call Service, OR make SensingTab smart.
  // Let's make SensingTab smart and simple.

  @override
  Widget build(BuildContext context) {
    // We will listen to the service state if we add a stream for it, or just use setState here
    // wrapping the service calls.
    // Since SensorService is a singleton, let's just use it directly for logic
    // and use a local setState to reflect the change if we want to decouple from HomeScreen.
    // But HomeScreen passes parameters...

    // Let's assume for now we keep the props for display but hook the callback.
    // Wait, the task said "Refactor lib/screens/sensing_tab.dart to use SensorService".

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
            bottom: 30,
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

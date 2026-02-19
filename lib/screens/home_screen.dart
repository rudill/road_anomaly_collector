import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:sensors_plus/sensors_plus.dart';
// Used sparingly for specific icons/themes

void main() {
  runApp(const RoadTrackApp());
}

class RoadTrackApp extends StatelessWidget {
  const RoadTrackApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const CupertinoApp(
      theme: CupertinoThemeData(
        brightness: Brightness.dark,
        primaryColor: CupertinoColors.activeBlue,
        textTheme: CupertinoTextThemeData(primaryColor: CupertinoColors.white),
      ),
      home: MainTabScaffold(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class MainTabScaffold extends StatefulWidget {
  const MainTabScaffold({super.key});

  @override
  State<MainTabScaffold> createState() => _MainTabScaffoldState();
}

class _MainTabScaffoldState extends State<MainTabScaffold> {
  bool isRecording = false;
  int potholeCount = 0;

  @override
  Widget build(BuildContext context) {
    return CupertinoTabScaffold(
      tabBar: CupertinoTabBar(
        backgroundColor: CupertinoColors.black.withOpacity(0.8),
        activeColor: CupertinoColors.activeBlue,
        inactiveColor: CupertinoColors.systemGrey,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.waveform_path_ecg),
            label: 'Sensing',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.map),
            label: 'Explore',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.square_list),
            label: 'History',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.settings),
            label: 'Config',
          ),
        ],
      ),
      tabBuilder: (context, index) {
        return CupertinoTabView(
          builder: (context) {
            switch (index) {
              case 0:
                return _SensingTab(
                  isRecording: isRecording,
                  potholeCount: potholeCount,
                  onToggle: () => setState(() => isRecording = !isRecording),
                );
              case 1:
                return const _MapTab();
              case 2:
                return const _HistoryTab();
              default:
                return const Center(child: Text('Settings'));
            }
          },
        );
      },
    );
  }
}

// --- Sensing Tab ---

class _SensingTab extends StatelessWidget {
  final bool isRecording;
  final int potholeCount;
  final VoidCallback onToggle;

  const _SensingTab({
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
        _StatCard(
          label: "DETECTED",
          value: "14",
          unit: "Anomalies",
          icon: CupertinoIcons.exclamationmark_triangle,
          color: CupertinoColors.systemRed,
        ),
        _StatCard(
          label: "IRI INDEX",
          value: "2.4",
          unit: "m/km",
          icon: CupertinoIcons.graph_square,
          color: CupertinoColors.systemYellow,
        ),
        _StatCard(
          label: "SPEED",
          value: "45",
          unit: "km/h",
          icon: CupertinoIcons.speedometer,
          color: CupertinoColors.activeBlue,
        ),
        _StatCard(
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
        _DetectionTile(
          title: "Pothole",
          conf: "98%",
          time: "2m ago",
          severity: "High",
        ),
        _DetectionTile(
          title: "Surface Crack",
          conf: "82%",
          time: "5m ago",
          severity: "Low",
        ),
      ],
    );
  }
}

// --- Helpers & Small Components ---

class _StatCard extends StatelessWidget {
  final String label, value, unit;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.unit,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CupertinoColors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: CupertinoColors.white.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 10,
                  color: CupertinoColors.systemGrey,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                unit,
                style: const TextStyle(
                  fontSize: 12,
                  color: CupertinoColors.systemGrey,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DetectionTile extends StatelessWidget {
  final String title, conf, time, severity;

  const _DetectionTile({
    required this.title,
    required this.conf,
    required this.time,
    required this.severity,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CupertinoColors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color:
                  (severity == "High"
                          ? CupertinoColors.systemRed
                          : CupertinoColors.systemYellow)
                      .withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              CupertinoIcons.exclamationmark_triangle,
              color: severity == "High"
                  ? CupertinoColors.systemRed
                  : CupertinoColors.systemYellow,
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  "$time • Conf: $conf",
                  style: const TextStyle(
                    color: CupertinoColors.systemGrey,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            CupertinoIcons.chevron_right,
            color: CupertinoColors.systemGrey,
            size: 16,
          ),
        ],
      ),
    );
  }
}

class WaveformPainter extends StatefulWidget {
  final bool isActive;
  const WaveformPainter({super.key, required this.isActive});

  @override
  State<WaveformPainter> createState() => _WaveformPainterState();
}

// 1. Create a simple data structure to hold your ML rows
class SensorDataPoint {
  final DateTime timestamp;
  final double x;
  final double y;
  final double z;
  final String label;

  SensorDataPoint(this.timestamp, this.x, this.y, this.z, this.label);

  // Helper method to easily convert this to a CSV string later
  String toCsvRow() => '${timestamp.toIso8601String()},$x,$y,$z,$label\n';
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
    return CustomPaint(painter: _GraphPainter(points));
  }
}

class _GraphPainter extends CustomPainter {
  final List<double> points;
  _GraphPainter(this.points);

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

// --- Map Tab ---

class _MapTab extends StatelessWidget {
  const _MapTab();

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      child: Stack(
        children: [
          Container(
            color: const Color(0xFF0F172A),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    CupertinoIcons.location_north_fill,
                    color: CupertinoColors.activeBlue,
                    size: 40,
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: CupertinoColors.activeBlue.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: CupertinoColors.activeBlue.withOpacity(0.5),
                      ),
                    ),
                    child: const Text(
                      "SIMULATED GPS TRACK",
                      style: TextStyle(
                        color: CupertinoColors.activeBlue,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: CupertinoColors.black.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "COORDINATES",
                          style: TextStyle(
                            fontSize: 10,
                            color: CupertinoColors.systemGrey,
                          ),
                        ),
                        Text(
                          "34.0522° N, 118.2437° W",
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                    ),
                  ),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    color: CupertinoColors.black.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(16),
                    child: const Icon(
                      CupertinoIcons.layers,
                      color: CupertinoColors.white,
                    ),
                    onPressed: () {},
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// --- History Tab ---

class _HistoryTab extends StatelessWidget {
  const _HistoryTab();

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: const Color(0xFF0A0A0B),
      child: CustomScrollView(
        slivers: [
          const CupertinoSliverNavigationBar(
            largeTitle: Text("Research Logs"),
            backgroundColor: Color(0xFF0A0A0B),
            border: null,
          ),
          SliverPadding(
            padding: const EdgeInsets.all(20),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) => Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: CupertinoColors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "Session #RS-202${3 - index}-00${index + 1}",
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            "${(index + 1) * 1.2} GB",
                            style: const TextStyle(
                              color: CupertinoColors.systemGrey,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Icon(
                            CupertinoIcons.circle_grid_3x3,
                            size: 14,
                            color: CupertinoColors.systemGrey,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            "${400 + index * 80} points",
                            style: const TextStyle(
                              fontSize: 12,
                              color: CupertinoColors.systemGrey,
                            ),
                          ),
                          const SizedBox(width: 16),
                          const Icon(
                            CupertinoIcons.map_pin,
                            size: 14,
                            color: CupertinoColors.systemGrey,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            "${12 + index * 4} km",
                            style: const TextStyle(
                              fontSize: 12,
                              color: CupertinoColors.systemGrey,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                childCount: 3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

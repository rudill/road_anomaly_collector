import 'package:flutter/cupertino.dart';
import 'package:road_anomaly_collector/screens/sensing_tab.dart';
import 'package:road_anomaly_collector/screens/map_tab.dart';
import 'package:road_anomaly_collector/screens/history_tab.dart';
import 'package:road_anomaly_collector/manual_data_collection/manual_data_collection_screen.dart';
import 'package:road_anomaly_collector/widgets/nericell_calibration_dialog.dart';
import 'package:road_anomaly_collector/services/backend_sync_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool isRecording = false;
  int potholeCount = 0;

  @override
  void initState() {
    super.initState();
    BackendSyncService().initialize();
  }

  void _showBackendUrlDialog() {
    final syncService = BackendSyncService();
    final textController = TextEditingController(text: syncService.baseUrl);

    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text("Backend Server URL"),
        content: Padding(
          padding: const EdgeInsets.only(top: 12.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "Enter FastAPI backend URL (include port, e.g. :8000)",
                style: TextStyle(fontSize: 12, color: CupertinoColors.systemGrey),
              ),
              const SizedBox(height: 12),
              CupertinoTextField(
                controller: textController,
                placeholder: "http://10.0.2.2:8000",
                style: const TextStyle(color: CupertinoColors.white, fontSize: 13),
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  CupertinoButton(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    color: CupertinoColors.white.withOpacity(0.1),
                    child: const Text("Emulator", style: TextStyle(fontSize: 11)),
                    onPressed: () {
                      textController.text = "http://10.0.2.2:8000";
                    },
                  ),
                  CupertinoButton(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    color: CupertinoColors.white.withOpacity(0.1),
                    child: const Text("Localhost", style: TextStyle(fontSize: 11)),
                    onPressed: () {
                      textController.text = "http://127.0.0.1:8000";
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: const Text("Cancel"),
            onPressed: () => Navigator.pop(ctx),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            child: const Text("Save & Connect"),
            onPressed: () {
              final newUrl = textController.text.trim();
              if (newUrl.isNotEmpty) {
                syncService.setBaseUrl(newUrl);
              }
              Navigator.pop(ctx);
            },
          ),
        ],
      ),
    );
  }

  Future<void> _testConnection() async {
    final isConnected = await BackendSyncService().checkConnection();
    if (!mounted) return;

    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text(isConnected ? "Backend Reachable" : "Connection Failed"),
        content: Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: Text(
            isConnected
                ? "Successfully connected to FastAPI PostGIS server at ${BackendSyncService().baseUrl}"
                : "Could not connect to ${BackendSyncService().baseUrl}. Ensure the FastAPI server is running with --host 0.0.0.0.",
          ),
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text("OK"),
            onPressed: () => Navigator.pop(ctx),
          ),
        ],
      ),
    );
  }

  Future<void> _triggerManualSync() async {
    final result = await BackendSyncService().syncPendingAnomalies();
    if (!mounted) return;

    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text(result.isSuccess ? "Sync Complete" : "Sync Failed"),
        content: Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: Text(result.message),
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text("OK"),
            onPressed: () => Navigator.pop(ctx),
          ),
        ],
      ),
    );
  }

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
                return SensingTab(
                  isRecording: isRecording,
                  potholeCount: potholeCount,
                  onToggle: () => setState(() => isRecording = !isRecording),
                );
              case 1:
                return const MapTab();
              case 2:
                return const HistoryTab();
              default:
                return CupertinoPageScaffold(
                  backgroundColor: const Color(0xFF0A0A0B),
                  navigationBar: const CupertinoNavigationBar(
                    backgroundColor: Color(0xFF0A0A0B),
                    middle: Text(
                      "CONFIGURATION",
                      style: TextStyle(
                        color: CupertinoColors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                  child: SafeArea(
                    child: ListView(
                      padding: const EdgeInsets.all(20),
                      children: [
                        const Text(
                          "CLOUD BACKEND & EDGE SYNC",
                          style: TextStyle(
                            color: CupertinoColors.systemGrey,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ValueListenableBuilder<String>(
                          valueListenable: BackendSyncService().baseUrlNotifier,
                          builder: (context, url, _) {
                            return _buildSettingItem(
                              context,
                              title: "Backend Server URL",
                              subtitle: url,
                              icon: CupertinoIcons.cloud,
                              color: CupertinoColors.activeBlue,
                              onTap: _showBackendUrlDialog,
                            );
                          },
                        ),
                        const SizedBox(height: 12),
                        ValueListenableBuilder<bool?>(
                          valueListenable: BackendSyncService().isBackendConnectedNotifier,
                          builder: (context, isConnected, _) {
                            final String statusText;
                            final Color statusColor;
                            final IconData statusIcon;

                            if (isConnected == null) {
                              statusText = "Checking connection...";
                              statusColor = CupertinoColors.systemGrey;
                              statusIcon = CupertinoIcons.question_circle;
                            } else if (isConnected) {
                              statusText = "Online • Connected to PostGIS";
                              statusColor = CupertinoColors.activeGreen;
                              statusIcon = CupertinoIcons.check_mark_circled_solid;
                            } else {
                              statusText = "Offline / Unreachable • Tap to retry";
                              statusColor = CupertinoColors.systemRed;
                              statusIcon = CupertinoIcons.exclamationmark_circle_solid;
                            }

                            return _buildSettingItem(
                              context,
                              title: "Connection Status",
                              subtitle: statusText,
                              icon: statusIcon,
                              color: statusColor,
                              onTap: _testConnection,
                            );
                          },
                        ),
                        const SizedBox(height: 12),
                        ValueListenableBuilder<int>(
                          valueListenable: BackendSyncService().pendingCountNotifier,
                          builder: (context, count, _) {
                            return ValueListenableBuilder<bool>(
                              valueListenable: BackendSyncService().isSyncingNotifier,
                              builder: (context, isSyncing, _) {
                                return _buildSettingItem(
                                  context,
                                  title: isSyncing ? "Syncing Telemetry..." : "Offline Outbox Queue",
                                  subtitle: isSyncing
                                      ? "Uploading compressed GZIP batch to backend"
                                      : "$count anomaly events pending sync • Tap to Sync Now",
                                  icon: isSyncing
                                      ? CupertinoIcons.arrow_2_circlepath
                                      : CupertinoIcons.arrow_up_doc_fill,
                                  color: count > 0 ? CupertinoColors.systemOrange : CupertinoColors.systemGrey,
                                  onTap: isSyncing ? () {} : _triggerManualSync,
                                );
                              },
                            );
                          },
                        ),
                        const SizedBox(height: 28),
                        const Text(
                          "DIAGNOSTICS & COLLECTION",
                          style: TextStyle(
                            color: CupertinoColors.systemGrey,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildSettingItem(
                          context,
                          title: "Manual Data Collection",
                          subtitle: "Real-time diagnostics & manual trigger",
                          icon: CupertinoIcons.ant_fill,
                          color: CupertinoColors.activeBlue,
                          onTap: () {
                            Navigator.push(
                              context,
                              CupertinoPageRoute(
                                builder: (context) =>
                                    const ManualDataCollectionScreen(),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 12),
                        _buildSettingItem(
                          context,
                          title: "Nericell Mount Calibration",
                          subtitle: "Align phone coordinate frame with vehicle axes",
                          icon: CupertinoIcons.compass,
                          color: CupertinoColors.activeGreen,
                          onTap: () {
                            showCupertinoModalPopup(
                              context: context,
                              builder: (context) =>
                                  const NericellCalibrationDialog(),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                );
            }
          },
        );
      },
    );
  }

  Widget _buildSettingItem(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: CupertinoColors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: CupertinoColors.white.withOpacity(0.1)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: CupertinoColors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  Text(
                    subtitle,
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
      ),
    );
  }
}

import 'package:flutter/cupertino.dart';
import 'package:road_anomaly_collector/screens/sensing_tab.dart';
import 'package:road_anomaly_collector/screens/map_tab.dart';
import 'package:road_anomaly_collector/screens/history_tab.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
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
                return const Center(child: Text('Settings'));
            }
          },
        );
      },
    );
  }
}

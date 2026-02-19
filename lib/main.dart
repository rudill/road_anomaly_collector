import 'package:flutter/cupertino.dart';
import 'package:road_anomaly_collector/screens/home_screen.dart';
import 'package:road_anomaly_collector/screens/sensor_data_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const CupertinoApp(
      title: 'Road Anomaly Collector',
      theme: CupertinoThemeData(
        brightness: Brightness.light,
        primaryColor: CupertinoColors.systemBlue,
      ),
      home: RoadTrackApp(),
    );
  }
}

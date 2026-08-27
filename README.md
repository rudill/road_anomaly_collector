# Road Anomaly Collector

A Flutter-based mobile application for detecting and collecting road anomaly data using device sensors.

## Overview

Road Anomaly Collector is a cross-platform mobile application that leverages smartphone sensors (accelerometer, gyroscope, and GPS) to collect and record road surface anomalies such as potholes, bumps, and rough patches. The app collects high-frequency sensor data, provides real-time waveform visualization, and allows users to tag, save, and share collected CSV datasets.

## Features

- **Real-time Sensor Monitoring**: View live data from accelerometer and device sensors
- **Anomaly Tagging & Tracking**: Record road anomalies and physical movement spikes
- **GPS Tracking**: Records location coordinates for data sessions
- **Data Collection**: Save sensor readings and anomaly tags directly to CSV files
- **Map Visualization**: Interactive map viewing current location
- **History & Sharing**: Access past recordings and share collected CSV logs
- **Cross-platform Support**: Runs on Android, iOS, Windows, macOS, Linux, and Web

## Project Structure

```
lib/
├── main.dart                 # Application entry point
├── manual_data_collection/   # Manual data collection utilities
├── models/                   # Data models
├── screens/                  # UI screens
│   ├── home_screen.dart      # Main navigation screen
│   ├── sensing_tab.dart      # Real-time sensing & data collection
│   ├── map_tab.dart          # Map visualization
│   ├── history_tab.dart      # History of collected data
│   └── sensor_data_screen.dart # Raw sensor data display
├── services/                 # Business logic services
│   └── sensor_service.dart   # Sensor data collection and CSV export
└── widgets/                  # Reusable UI components
```

## Dependencies

Key packages used in this project:

- **flutter_map** & **latlong2**: Interactive maps and geospatial data
- **sensors_plus**: Access to device sensors (accelerometer)
- **geolocator**: GPS location services
- **permission_handler**: Runtime permission management
- **csv**: CSV file generation for data export
- **path_provider**: File system access for data storage
- **share_plus**: Share collected data with other apps

## Getting Started

### Prerequisites

- Flutter SDK (version 3.10.7 or higher)
- Dart SDK
- Android Studio / Xcode (for mobile development)
- Device with required sensors (for testing)

### Installation

1. Clone the repository:
   ```bash
   git clone <repository-url>
   cd road_anomaly_collector
   ```

2. Install dependencies:
   ```bash
   flutter pub get
   ```

3. Run the app:
   ```bash
   flutter run
   ```

### Permissions

The app requires the following permissions:
- Location (for GPS tracking)
- Sensors (accelerometer access)
- Storage (for saving collected data)

Permissions are handled automatically at runtime using the `permission_handler` package.

## Usage

1. **Home Screen**: Navigate between different tabs (Sensing, Map, History, Config)
2. **Sensing Tab**: Start real-time sensor recording and monitor live acceleration waveforms
3. **Map Tab**: View GPS position and coordinates
4. **History Tab**: Review and export previously collected CSV files
5. **Diagnostics & Collection**: Real-time 3-axis acceleration diagnostics with manual anomaly tagging (Normal, Pothole, Bump)

## Contributing

Contributions are welcome! Please feel free to submit issues and pull requests.

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Acknowledgments

- [Flutter](https://flutter.dev/)
- [OpenStreetMap](https://www.openstreetmap.org/) (via flutter_map)

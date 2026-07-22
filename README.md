# Road Anomaly Collector

A Flutter-based mobile application for detecting and collecting road anomaly data using device sensors and machine learning.

## Overview

Road Anomaly Collector is a cross-platform mobile application that leverages smartphone sensors (accelerometer, gyroscope, and GPS) combined with a TensorFlow Lite machine learning model to detect road surface anomalies such as potholes, bumps, and rough patches. The app collects sensor data, performs real-time inference, and allows users to save and share collected data.

## Features

- **Real-time Sensor Monitoring**: View live data from accelerometer, gyroscope, and other device sensors
- **ML-powered Anomaly Detection**: Uses a trained TensorFlow Lite model to classify road conditions
- **GPS Tracking**: Records location data for each detected anomaly
- **Data Collection**: Save sensor readings and anomaly detections to CSV files
- **Map Visualization**: View collected anomalies on an interactive map
- **History & Sharing**: Access past recordings and share collected data
- **Cross-platform Support**: Runs on Android, iOS, Windows, macOS, Linux, and Web

## Project Structure

```
lib/
├── main.dart                 # Application entry point
├── manual_data_collection/   # Manual data collection utilities
├── models/                   # Data models
├── screens/                  # UI screens
│   ├── home_screen.dart      # Main navigation screen
│   ├── sensing_tab.dart      # Real-time anomaly detection
│   ├── map_tab.dart          # Map visualization of anomalies
│   ├── history_tab.dart      # History of collected data
│   └── sensor_data_screen.dart # Raw sensor data display
├── services/                 # Business logic services
│   ├── sensor_service.dart   # Sensor data collection
│   └── tflite_service.dart   # TensorFlow Lite inference
└── widgets/                  # Reusable UI components

assets/
└── models/
    ├── trained.tflite        # ML model for anomaly detection
    └── model-parameters/     # Model configuration files
```

## Dependencies

Key packages used in this project:

- **flutter_map** & **latlong2**: Interactive maps and geospatial data
- **sensors_plus**: Access to device sensors (accelerometer, gyroscope)
- **geolocator**: GPS location services
- **permission_handler**: Runtime permission management
- **tflite_flutter**: TensorFlow Lite inference engine
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
- Sensors (accelerometer, gyroscope access)
- Storage (for saving collected data)

Permissions are handled automatically at runtime using the `permission_handler` package.

## Usage

1. **Home Screen**: Navigate between different tabs (Sensing, Map, History)
2. **Sensing Tab**: Start real-time anomaly detection while moving
3. **Map Tab**: View detected anomalies plotted on a map
4. **History Tab**: Review and export previously collected data
5. **Sensor Data**: Access raw sensor readings for debugging/analysis

## Model Information

The app includes a pre-trained TensorFlow Lite model (`trained.tflite`) located in `assets/models/`. The model processes sensor data to classify road surface conditions.

## Contributing

Contributions are welcome! Please feel free to submit issues and pull requests.

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Acknowledgments

- [Flutter](https://flutter.dev/)
- [TensorFlow Lite](https://www.tensorflow.org/lite)
- [OpenStreetMap](https://www.openstreetmap.org/) (via flutter_map)

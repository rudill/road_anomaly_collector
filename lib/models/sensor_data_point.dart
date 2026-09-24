class SensorDataPoint {
  final DateTime timestamp;
  final double accelX;
  final double accelY;
  final double accelZ;
  final double gyroX;
  final double gyroY;
  final double gyroZ;
  final String label;

  SensorDataPoint({
    required this.timestamp,
    required this.accelX,
    required this.accelY,
    required this.accelZ,
    required this.gyroX,
    required this.gyroY,
    required this.gyroZ,
    required this.label,
  });

  // Backward compatibility getters
  double get x => accelX;
  double get y => accelY;
  double get z => accelZ;

  // CSV Row: Timestamp,Accel_X,Accel_Y,Accel_Z,Gyro_X,Gyro_Y,Gyro_Z,Label
  String toCsvRow() =>
      '${timestamp.toIso8601String()},$accelX,$accelY,$accelZ,$gyroX,$gyroY,$gyroZ,$label\n';
}

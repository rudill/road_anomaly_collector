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

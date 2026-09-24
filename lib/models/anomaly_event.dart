/// Represents a detected road anomaly event classified by the edge ML pipeline.
class AnomalyDetectionEvent {
  final String id;
  final DateTime timestamp;
  final String label; // "Pothole" | "Bump" | "Normal"
  final double confidence;
  final double magnitude; // peak-to-peak or deviation in m/s^2
  final String severity; // "High" | "Medium" | "Low"
  final double? latitude;
  final double? longitude;
  final double? speedKmh;
  final List<double>? probabilities;

  const AnomalyDetectionEvent({
    required this.id,
    required this.timestamp,
    required this.label,
    required this.confidence,
    required this.magnitude,
    required this.severity,
    this.latitude,
    this.longitude,
    this.speedKmh,
    this.probabilities,
  });

  bool get isAnomaly => label == 'Pothole' || label == 'Bump';
  bool get isPothole => label == 'Pothole';
  bool get isBump => label == 'Bump';

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'timestamp': timestamp.toIso8601String(),
      'label': label,
      'confidence': confidence,
      'magnitude': magnitude,
      'severity': severity,
      'latitude': latitude,
      'longitude': longitude,
      'speedKmh': speedKmh,
      'probabilities': probabilities,
    };
  }

  factory AnomalyDetectionEvent.fromMap(Map<String, dynamic> map) {
    return AnomalyDetectionEvent(
      id: map['id'] as String,
      timestamp: DateTime.parse(map['timestamp'] as String),
      label: map['label'] as String,
      confidence: (map['confidence'] as num).toDouble(),
      magnitude: (map['magnitude'] as num).toDouble(),
      severity: map['severity'] as String,
      latitude: (map['latitude'] as num?)?.toDouble(),
      longitude: (map['longitude'] as num?)?.toDouble(),
      speedKmh: (map['speedKmh'] as num?)?.toDouble(),
      probabilities: (map['probabilities'] as List<dynamic>?)
          ?.map((e) => (e as num).toDouble())
          .toList(),
    );
  }
}

import 'dart:convert';

/// Represents a single anomaly detection record prepared for backend ingestion.
/// Strictly matches the FastAPI SyncRecord schema.
class SyncRecordPayload {
  final String uuid;
  final String timestampUtc;
  final double latitudePerturbed;
  final double longitudePerturbed;
  final String h3Index;
  final String classLabel; // 'pothole' | 'speed_bump' | 'normal'
  final double confidence;
  final double speedKmh;
  final double peakAzMS2;
  final String mountingConfig; // 'dash_mount' | 'windshield_mount' | 'cup_holder' | 'pocket' | 'unknown'

  SyncRecordPayload({
    required this.uuid,
    required this.timestampUtc,
    required this.latitudePerturbed,
    required this.longitudePerturbed,
    this.h3Index = '',
    required this.classLabel,
    required this.confidence,
    required this.speedKmh,
    required this.peakAzMS2,
    this.mountingConfig = 'dash_mount',
  });

  Map<String, dynamic> toJson() {
    return {
      'uuid': uuid,
      'timestamp_utc': timestampUtc,
      'latitude_perturbed': latitudePerturbed,
      'longitude_perturbed': longitudePerturbed,
      'h3_index': h3Index,
      'class_label': classLabel,
      'confidence': confidence,
      'speed_kmh': speedKmh,
      'peak_az_m_s2': peakAzMS2,
      'mounting_config': mountingConfig,
    };
  }

  factory SyncRecordPayload.fromJson(Map<String, dynamic> json) {
    return SyncRecordPayload(
      uuid: json['uuid'] as String,
      timestampUtc: json['timestamp_utc'] as String,
      latitudePerturbed: (json['latitude_perturbed'] as num).toDouble(),
      longitudePerturbed: (json['longitude_perturbed'] as num).toDouble(),
      h3Index: json['h3_index'] as String? ?? '',
      classLabel: json['class_label'] as String,
      confidence: (json['confidence'] as num).toDouble(),
      speedKmh: (json['speed_kmh'] as num).toDouble(),
      peakAzMS2: (json['peak_az_m_s2'] as num).toDouble(),
      mountingConfig: json['mounting_config'] as String? ?? 'dash_mount',
    );
  }
}

/// Batch ingestion payload sent to POST /api/v1/anomalies/sync.
class SyncBatchPayload {
  final String deviceIdHash;
  final int batchSize;
  final List<SyncRecordPayload> records;

  SyncBatchPayload({
    required this.deviceIdHash,
    required this.records,
  }) : batchSize = records.length;

  Map<String, dynamic> toJson() {
    return {
      'device_id_hash': deviceIdHash,
      'batch_size': batchSize,
      'records': records.map((r) => r.toJson()).toList(),
    };
  }
}

/// Response returned from POST /api/v1/anomalies/sync.
class SyncResponse {
  final String status;
  final String processedAt;
  final int ingestedCount;
  final List<String> ingestedUuids;

  SyncResponse({
    required this.status,
    required this.processedAt,
    required this.ingestedCount,
    required this.ingestedUuids,
  });

  factory SyncResponse.fromJson(Map<String, dynamic> json) {
    return SyncResponse(
      status: json['status'] as String? ?? 'SUCCESS',
      processedAt: json['processed_at'] as String? ?? '',
      ingestedCount: json['ingested_count'] as int? ?? 0,
      ingestedUuids: (json['ingested_uuids'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
    );
  }
}

/// Verified defect centroid returned from GET /api/v1/hazards/verified.
class VerifiedHazard {
  final int hazardId;
  final String primaryClass; // 'pothole' | 'speed_bump'
  final int detectionCount;
  final double avgConfidence;
  final double maxPeakAz;
  final double centroidLat;
  final double centroidLng;
  final String h3Index;
  final String roadName;
  final DateTime firstDetectedAt;
  final DateTime lastDetectedAt;
  final String status; // 'ACTIVE' | 'REPAIRED' | 'VERIFIED'

  VerifiedHazard({
    required this.hazardId,
    required this.primaryClass,
    required this.detectionCount,
    required this.avgConfidence,
    required this.maxPeakAz,
    required this.centroidLat,
    required this.centroidLng,
    required this.h3Index,
    required this.roadName,
    required this.firstDetectedAt,
    required this.lastDetectedAt,
    required this.status,
  });

  bool get isPothole => primaryClass.toLowerCase() == 'pothole';
  bool get isSpeedBump => primaryClass.toLowerCase() == 'speed_bump';

  factory VerifiedHazard.fromJson(Map<String, dynamic> json) {
    return VerifiedHazard(
      hazardId: json['hazard_id'] as int,
      primaryClass: json['primary_class'] as String,
      detectionCount: json['detection_count'] as int,
      avgConfidence: (json['avg_confidence'] as num).toDouble(),
      maxPeakAz: (json['max_peak_az'] as num).toDouble(),
      centroidLat: (json['centroid_lat'] as num).toDouble(),
      centroidLng: (json['centroid_lng'] as num).toDouble(),
      h3Index: json['h3_index'] as String? ?? '',
      roadName: json['road_name'] as String? ?? 'Municipal Road',
      firstDetectedAt: DateTime.tryParse(json['first_detected_at'] as String? ?? '') ?? DateTime.now(),
      lastDetectedAt: DateTime.tryParse(json['last_detected_at'] as String? ?? '') ?? DateTime.now(),
      status: json['status'] as String? ?? 'ACTIVE',
    );
  }
}

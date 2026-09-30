import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:road_anomaly_collector/models/anomaly_event.dart';
import 'package:road_anomaly_collector/models/backend_models.dart';
import 'package:road_anomaly_collector/services/ml_inference_service.dart';
import 'package:road_anomaly_collector/services/backend_sync_service.dart';

class MapTab extends StatefulWidget {
  const MapTab({super.key});

  @override
  State<MapTab> createState() => _MapTabState();
}

class _MapTabState extends State<MapTab> {
  final MapController _mapController = MapController();
  LatLng? _currentPosition;
  bool _isLoading = true;
  bool _isMapReady = false;
  String _locationError = '';

  List<VerifiedHazard> _verifiedHazards = [];
  bool _isLoadingHazards = false;

  StreamSubscription<AnomalyDetectionEvent>? _anomalySub;

  @override
  void initState() {
    super.initState();
    _determinePosition();
    _subscribeToAnomalies();
    _fetchVerifiedHazards();
  }

  void _subscribeToAnomalies() {
    _anomalySub = MlInferenceService().anomalyStream.listen((_) {
      if (mounted) setState(() {});
    });
  }

  Future<void> _fetchVerifiedHazards() async {
    if (_isLoadingHazards) return;
    setState(() => _isLoadingHazards = true);

    try {
      final hazards = await BackendSyncService().fetchVerifiedHazards();
      if (mounted) {
        setState(() {
          _verifiedHazards = hazards;
          _isLoadingHazards = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingHazards = false);
      }
    }
  }

  @override
  void dispose() {
    _anomalySub?.cancel();
    super.dispose();
  }

  Future<void> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) {
        setState(() {
          _locationError = 'Location services are disabled.';
          _isLoading = false;
        });
      }
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (mounted) {
          setState(() {
            _locationError = 'Location permissions are denied';
            _isLoading = false;
          });
        }
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      if (mounted) {
        setState(() {
          _locationError =
              'Location permissions are permanently denied, we cannot request permissions.';
          _isLoading = false;
        });
      }
      return;
    }

    try {
      Position position = await Geolocator.getCurrentPosition();
      if (mounted) {
        setState(() {
          _currentPosition = LatLng(position.latitude, position.longitude);
          _isLoading = false;
        });
        if (_isMapReady) {
          _mapController.move(_currentPosition!, 15);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _locationError = 'Failed to get location: $e';
          _isLoading = false;
        });
      }
    }
  }

  void _showAnomalyDetails(AnomalyDetectionEvent anomaly) {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Color(0xFF161618),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: anomaly.isPothole
                              ? CupertinoColors.systemRed
                              : CupertinoColors.systemOrange,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          anomaly.isPothole
                              ? CupertinoIcons.exclamationmark_triangle_fill
                              : CupertinoIcons.arrow_up_circle_fill,
                          color: CupertinoColors.white,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        anomaly.label.toUpperCase(),
                        style: const TextStyle(
                          color: CupertinoColors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: CupertinoColors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${(anomaly.confidence * 100).toStringAsFixed(0)}% Conf',
                      style: const TextStyle(
                        color: CupertinoColors.activeGreen,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _buildDetailRow('Source', 'On-Device Edge ML (Recent)'),
              _buildDetailRow('Impact Severity', anomaly.severity),
              _buildDetailRow('Peak Z-Force Deviation', '${anomaly.magnitude.toStringAsFixed(2)} m/s²'),
              if (anomaly.speedKmh != null)
                _buildDetailRow('Vehicle Speed', '${anomaly.speedKmh!.toStringAsFixed(1)} km/h'),
              if (anomaly.latitude != null && anomaly.longitude != null)
                _buildDetailRow('GPS Coordinates', '${anomaly.latitude!.toStringAsFixed(5)}, ${anomaly.longitude!.toStringAsFixed(5)}'),
              _buildDetailRow('Detection Time', anomaly.timestamp.toLocal().toString().split('.').first),
              const SizedBox(height: 20),
              CupertinoButton.filled(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showVerifiedHazardDetails(VerifiedHazard hazard) {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Color(0xFF161618),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: CupertinoColors.activeBlue,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          CupertinoIcons.checkmark_shield_fill,
                          color: CupertinoColors.white,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            hazard.primaryClass.replaceAll('_', ' ').toUpperCase(),
                            style: const TextStyle(
                              color: CupertinoColors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Status: ${hazard.status}',
                            style: const TextStyle(
                              color: CupertinoColors.activeGreen,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: CupertinoColors.activeBlue.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: CupertinoColors.activeBlue.withOpacity(0.4)),
                    ),
                    child: Text(
                      '${hazard.detectionCount}x Verified',
                      style: const TextStyle(
                        color: CupertinoColors.activeBlue,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _buildDetailRow('Corridor', hazard.roadName),
              _buildDetailRow('DBSCAN Cluster', 'Merged from ${hazard.detectionCount} vehicle passes'),
              _buildDetailRow('Avg ML Confidence', '${(hazard.avgConfidence * 100).toStringAsFixed(1)}%'),
              _buildDetailRow('Max Peak Impact', '${hazard.maxPeakAz.toStringAsFixed(2)} m/s²'),
              _buildDetailRow('Centroid Coordinates', '${hazard.centroidLat.toStringAsFixed(5)}, ${hazard.centroidLng.toStringAsFixed(5)}'),
              _buildDetailRow('H3 Spatial Cell', hazard.h3Index),
              _buildDetailRow('Last Verified', hazard.lastDetectedAt.toLocal().toString().split('.').first),
              const SizedBox(height: 20),
              CupertinoButton.filled(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: CupertinoColors.systemGrey, fontSize: 13)),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: CupertinoColors.white, fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      child: Stack(
        children: [
          _buildMap(),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildCoordinatesOverlay(),
                      Row(
                        children: [
                          CupertinoButton(
                            padding: EdgeInsets.zero,
                            color: CupertinoColors.black.withOpacity(0.7),
                            borderRadius: BorderRadius.circular(16),
                            onPressed: _fetchVerifiedHazards,
                            child: _isLoadingHazards
                                ? const CupertinoActivityIndicator(radius: 9)
                                : const Icon(
                                    CupertinoIcons.cloud_download,
                                    color: CupertinoColors.activeBlue,
                                    size: 20,
                                  ),
                          ),
                          const SizedBox(width: 8),
                          CupertinoButton(
                            padding: EdgeInsets.zero,
                            color: CupertinoColors.black.withOpacity(0.7),
                            borderRadius: BorderRadius.circular(16),
                            child: const Icon(
                              CupertinoIcons.location_fill,
                              color: CupertinoColors.white,
                              size: 20,
                            ),
                            onPressed: () {
                              if (_currentPosition != null) {
                                if (_isMapReady) {
                                  _mapController.move(_currentPosition!, 15);
                                }
                              } else {
                                _determinePosition();
                              }
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _buildAnomalySummaryBadge(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnomalySummaryBadge() {
    final potholes = MlInferenceService().potholeCount;
    final bumps = MlInferenceService().bumpCount;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: CupertinoColors.black.withOpacity(0.75),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: CupertinoColors.white.withOpacity(0.1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(CupertinoIcons.map_pin_ellipse, size: 14, color: CupertinoColors.activeBlue),
          const SizedBox(width: 8),
          Text(
            "Live: ${potholes}P • ${bumps}B  |  Cloud Verified: ${_verifiedHazards.length}",
            style: const TextStyle(
              color: CupertinoColors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMap() {
    if (_isLoading) {
      return const Center(child: CupertinoActivityIndicator());
    }

    if (_locationError.isNotEmpty) {
      return Container(
        color: const Color(0xFF0F172A),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Text(
              _locationError,
              textAlign: TextAlign.center,
              style: const TextStyle(color: CupertinoColors.systemRed),
            ),
          ),
        ),
      );
    }

    final center = _currentPosition ?? const LatLng(6.9271, 79.8612); // Default Colombo
    final detections = MlInferenceService().recentDetections;

    final markers = <Marker>[];

    // 1. Current position marker
    if (_currentPosition != null) {
      markers.add(
        Marker(
          point: _currentPosition!,
          width: 60,
          height: 60,
          child: const Icon(
            CupertinoIcons.location_solid,
            color: CupertinoColors.activeBlue,
            size: 36,
          ),
        ),
      );
    }

    // 2. Cloud Tier 2 Verified Hazard Centroids
    for (final hazard in _verifiedHazards) {
      markers.add(
        Marker(
          point: LatLng(hazard.centroidLat, hazard.centroidLng),
          width: 50,
          height: 50,
          child: GestureDetector(
            onTap: () => _showVerifiedHazardDetails(hazard),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF1E3A8A),
                shape: BoxShape.circle,
                border: Border.all(color: CupertinoColors.activeBlue, width: 2.5),
                boxShadow: [
                  BoxShadow(
                    color: CupertinoColors.activeBlue.withOpacity(0.6),
                    blurRadius: 10,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Icon(
                    hazard.isPothole
                        ? CupertinoIcons.exclamationmark_shield_fill
                        : CupertinoIcons.shield_fill,
                    color: CupertinoColors.white,
                    size: 22,
                  ),
                  Positioned(
                    top: 1,
                    right: 1,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: CupertinoColors.systemRed,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${hazard.detectionCount}',
                        style: const TextStyle(
                          color: CupertinoColors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // 3. Local Edge Anomaly Pins (Recent)
    for (final anomaly in detections) {
      if (anomaly.latitude != null && anomaly.longitude != null) {
        markers.add(
          Marker(
            point: LatLng(anomaly.latitude!, anomaly.longitude!),
            width: 44,
            height: 44,
            child: GestureDetector(
              onTap: () => _showAnomalyDetails(anomaly),
              child: Container(
                decoration: BoxDecoration(
                  color: anomaly.isPothole
                      ? CupertinoColors.systemRed
                      : CupertinoColors.systemOrange,
                  shape: BoxShape.circle,
                  border: Border.all(color: CupertinoColors.white, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: (anomaly.isPothole
                              ? CupertinoColors.systemRed
                              : CupertinoColors.systemOrange)
                          .withOpacity(0.5),
                      blurRadius: 8,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Icon(
                  anomaly.isPothole
                      ? CupertinoIcons.exclamationmark
                      : CupertinoIcons.arrow_up,
                  color: CupertinoColors.white,
                  size: 20,
                ),
              ),
            ),
          ),
        );
      }
    }

    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: center,
        initialZoom: 14.0,
        onMapReady: () {
          _isMapReady = true;
        },
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.example.road_anomaly_collector',
        ),
        MarkerLayer(markers: markers),
      ],
    );
  }

  Widget _buildCoordinatesOverlay() {
    String coordText = "Searching...";
    if (_currentPosition != null) {
      coordText =
          "${_currentPosition!.latitude.toStringAsFixed(4)}°, ${_currentPosition!.longitude.toStringAsFixed(4)}°";
    } else if (_locationError.isNotEmpty) {
      coordText = "Location Error";
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: CupertinoColors.black.withOpacity(0.7),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "GPS POSITION",
            style: TextStyle(fontSize: 10, color: CupertinoColors.systemGrey),
          ),
          Text(
            coordText,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              fontFamily: 'monospace',
              color: CupertinoColors.white,
            ),
          ),
        ],
      ),
    );
  }
}

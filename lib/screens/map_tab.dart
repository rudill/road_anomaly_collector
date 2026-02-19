import 'package:flutter/cupertino.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';

class MapTab extends StatefulWidget {
  const MapTab({super.key});

  @override
  State<MapTab> createState() => _MapTabState();
}

class _MapTabState extends State<MapTab> {
  final MapController _mapController = MapController();
  LatLng? _currentPosition;
  bool _isLoading = true;
  String _locationError = '';

  @override
  void initState() {
    super.initState();
    _determinePosition();
  }

  Future<void> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Test if location services are enabled.
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
      // Permissions are denied forever, handle appropriately.
      if (mounted) {
        setState(() {
          _locationError =
              'Location permissions are permanently denied, we cannot request permissions.';
          _isLoading = false;
        });
      }
      return;
    }

    // When we reach here, permissions are granted and we can
    // continue accessing the position of the device.
    try {
      Position position = await Geolocator.getCurrentPosition();
      if (mounted) {
        setState(() {
          _currentPosition = LatLng(position.latitude, position.longitude);
          _isLoading = false;
        });
        _mapController.move(_currentPosition!, 15);
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

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      child: Stack(
        children: [
          _buildMap(),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildCoordinatesOverlay(),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    color: CupertinoColors.black.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(16),
                    child: const Icon(
                      CupertinoIcons.location_fill,
                      color: CupertinoColors.white,
                    ),
                    onPressed: () {
                      if (_currentPosition != null) {
                        _mapController.move(_currentPosition!, 15);
                      } else {
                        _determinePosition();
                      }
                    },
                  ),
                ],
              ),
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

    // Default to London if position is null for some reason but no error
    final center = _currentPosition ?? const LatLng(51.509364, -0.128928);

    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(initialCenter: center, initialZoom: 15.0),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.example.road_anomaly_collector',
        ),
        if (_currentPosition != null)
          MarkerLayer(
            markers: [
              Marker(
                point: _currentPosition!,
                width: 80,
                height: 80,
                child: const Icon(
                  CupertinoIcons.location_solid,
                  color: CupertinoColors.activeBlue,
                  size: 40,
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildCoordinatesOverlay() {
    String coordText = "Searching...";
    if (_currentPosition != null) {
      coordText =
          "${_currentPosition!.latitude.toStringAsFixed(4)}° N, ${_currentPosition!.longitude.toStringAsFixed(4)}° W";
    } else if (_locationError.isNotEmpty) {
      coordText = "Location Error";
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CupertinoColors.black.withOpacity(0.7),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "COORDINATES",
            style: TextStyle(fontSize: 10, color: CupertinoColors.systemGrey),
          ),
          Text(
            coordText,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:geolocator/geolocator.dart' hide Position;

class PickedLocation {
  final double latitude;
  final double longitude;
  PickedLocation({required this.latitude, required this.longitude});
}

class LocationPickerPage extends StatefulWidget {
  const LocationPickerPage({super.key});

  @override
  State<LocationPickerPage> createState() => _LocationPickerPageState();
}

class _LocationPickerPageState extends State<LocationPickerPage> {
  MapboxMap? mapController;
  Position? centerPosition;
  bool isLoading = true;
  String? locationNote;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Select Location')),
      body: Stack(
        children: [
          MapWidget(
            styleUri: MapboxStyles.STANDARD,
            onMapCreated: (controller) async {
              mapController = controller;
              await _goToCurrentLocation();
              if (mounted) setState(() => isLoading = false);
            },
            onCameraChangeListener: (data) {
              centerPosition = data.cameraState.center.coordinates;
            },
          ),
          const Center(
            child: Padding(
              padding: EdgeInsets.only(bottom: 40),
              child: Icon(Icons.location_pin, size: 48, color: Colors.red),
            ),
          ),
          if (isLoading) const Center(child: CircularProgressIndicator()),
          if (locationNote != null)
            Positioned(
              top: 12,
              left: 12,
              right: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  locationNote!,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          Positioned(
            bottom: 24,
            left: 16,
            right: 16,
            child: ElevatedButton(
              onPressed: _confirmLocation,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text('Confirm This Location'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _goToCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) {
        setState(() {
          locationNote =
              'Location services are off. Drag the map to pick a spot manually.';
        });
      }
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      if (mounted) {
        setState(() {
          locationNote =
              'Location permission denied. Drag the map to pick a spot manually.';
        });
      }
      return;
    }

    final current = await Geolocator.getCurrentPosition();
    centerPosition = Position(current.longitude, current.latitude);

    await mapController?.setCamera(
      CameraOptions(center: Point(coordinates: centerPosition!), zoom: 15),
    );

    mapController?.location.updateSettings(
      LocationComponentSettings(enabled: true, pulsingEnabled: true),
    );
  }

  void _confirmLocation() {
    if (centerPosition == null) return;
    Navigator.pop(
      context,
      PickedLocation(
        latitude: centerPosition!.lat.toDouble(),
        longitude: centerPosition!.lng.toDouble(),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:geolocator/geolocator.dart' hide Position;

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  MapboxMap? mapController;
  @override
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: MapWidget(
        onMapCreated: (controller) async {
          setState(() {
            mapController = controller;
          });

          await _setupPositionTracking();
          var latlong = await Geolocator.getCurrentPosition();
          var pnt = Point(
            coordinates: Position(latlong.longitude, latlong.latitude),
          );

          // Add custom marker pin
          Future.delayed(Duration(milliseconds: 500), () {
            mapController?.annotations.createPointAnnotationManager().then((
              manager,
            ) {
              manager.create(
                PointAnnotationOptions(
                  geometry: pnt,
                  textField: "📍",
                  textSize: 30,
                ),
              );
            });
          });

          // Enable built-in location indicator (blue dot)
          mapController?.location.updateSettings(
            LocationComponentSettings(enabled: true, pulsingEnabled: true),
          );
        },
      ),
    );
  }

  Future<bool> _setupPositionTracking() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class OfflineMapWidget extends StatelessWidget {
  final double centerLat;
  final double centerLng;
  final List<LatLng> markers;
  final String tilePath; // Path to local tiles (e.g., MBTiles or folder)

  const OfflineMapWidget({
    Key? key,
    required this.centerLat,
    required this.centerLng,
    required this.markers,
    required this.tilePath,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return FlutterMap(
      options: MapOptions(
        center: LatLng(centerLat, centerLng),
        zoom: 13.0,
      ),
      children: [
        TileLayer(
          tileProvider: AssetTileProvider(),
          urlTemplate: tilePath + '/{z}/{x}/{y}.png',
          // Example: 'assets/tiles/{z}/{x}/{y}.png'
        ),
        MarkerLayer(
          markers: markers
              .map((latlng) => Marker(
                    point: latlng,
                    width: 40,
                    height: 40,
                    builder: (ctx) => const Icon(Icons.location_on, color: Colors.red, size: 32),
                  ))
              .toList(),
        ),
      ],
    );
  }
}

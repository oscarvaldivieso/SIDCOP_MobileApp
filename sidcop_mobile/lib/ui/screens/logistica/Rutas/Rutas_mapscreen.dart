import 'package:flutter/material.dart';
import 'package:sidcop_mobile/models/RutasViewModel.dart';
import 'package:sidcop_mobile/models/ClientesViewModel.dart';
import 'package:sidcop_mobile/models/direccion_cliente_model.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class RutaMapScreen extends StatelessWidget {
  final double lat;
  final double lng;
  final String? descripcion;
  const RutaMapScreen({super.key, required this.lat, required this.lng, this.descripcion});

  @override
  Widget build(BuildContext context) {
    return Scaffold(  
      appBar: AppBar(title: Text(descripcion ?? 'Ubicación Ruta')),
      body: GoogleMap(
        initialCameraPosition: CameraPosition(
          target: LatLng(lat, lng),
          zoom: 15,
        ),
        markers: {
          Marker(
            markerId: const MarkerId('ruta'),
            position: LatLng(lat, lng),
            infoWindow: InfoWindow(title: descripcion),
          ),
        },
      ),
    );
  }
}

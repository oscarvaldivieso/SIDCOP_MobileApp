import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class RutasOfflineMapScreen extends StatefulWidget {
  final int rutaId;
  final String? descripcion;

  const RutasOfflineMapScreen({
    Key? key,
    required this.rutaId,
    this.descripcion,
  }) : super(key: key);

  @override
  State<RutasOfflineMapScreen> createState() => _RutasOfflineMapScreenState();
}

class _RutasOfflineMapScreenState extends State<RutasOfflineMapScreen> {
  String? localMapPath;
  bool loading = true;
  bool? isOnline;

  @override
  void initState() {
    super.initState();
    _loadLocalMap();
    verificarConexion();
  }

  Future<void> verificarConexion() async {
    try {
      final response = await http.get(Uri.parse('https://www.google.com'));
      setState(() {
        isOnline = response.statusCode == 200;
      });
    } catch (e) {
      setState(() {
        isOnline = false;
      });
    }
  }

  Future<void> _loadLocalMap() async {
    final directory = await getApplicationDocumentsDirectory();
    final filePath = '${directory.path}/map_static_${widget.rutaId}.png';
    final file = File(filePath);
    if (await file.exists()) {
      setState(() {
        localMapPath = filePath;
        loading = false;
      });
    } else {
      setState(() {
        localMapPath = null;
        loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Ejemplo de datos, debes obtenerlos dinámicamente según la ruta:
    final double centerLat = 15.525585;
    final double centerLng = -88.013512;
    final List<LatLng> markers = [LatLng(15.525585, -88.013512)];
    final String tilePath = 'assets/tiles'; // Cambia esto según tu estructura

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.descripcion ?? 'Mapa Offline'),
      ),
      body: FlutterMap(
        options: MapOptions(
          center: LatLng(centerLat, centerLng),
          zoom: 13.0,
        ),
        children: [
          TileLayer(
            tileProvider: AssetTileProvider(),
            urlTemplate: tilePath + '/{z}/{x}/{y}.png',
          ),
          MarkerLayer(
            markers: markers
                .map((latlng) => Marker(
                      point: latlng,
                      width: 40,
                      height: 40,
                      child: const Icon(Icons.location_on, color: Colors.red, size: 32),
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }
}

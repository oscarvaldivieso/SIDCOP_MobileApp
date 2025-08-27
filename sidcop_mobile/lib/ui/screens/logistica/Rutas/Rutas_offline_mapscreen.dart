import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_map/flutter_map.dart';
import 'dart:typed_data';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  String? localTilesPath;
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
  // Intent: no usar imágenes estáticas en absoluto.
  // Buscar únicamente una carpeta de tiles bajo <documents>/_subfolder
  // (si existe, la usaremos; si no, informamos que no hay mapa offline)
  final prefs = await SharedPreferences.getInstance();
  final sub = prefs.getString('offline_maps_subfolder') ?? 'maps';
  final tilesBase = await _findTilesBasePath(directory, sub);
    if (tilesBase != null) {
      setState(() {
        localTilesPath = tilesBase;
        loading = false;
      });
      return;
    }

    // nothing found
    setState(() {
      localMapPath = null;
      localTilesPath = null;
      loading = false;
    });
  }

  // Try to locate a tiles folder under the app documents maps/ directory.
  // If widget.descripcion is present we try a slug match first.
  Future<String?> _findTilesBasePath(Directory documentsDir, String subfolder) async {
    final mapsDir = Directory('${documentsDir.path}/$subfolder');
    if (!await mapsDir.exists()) return null;

    String slug(String s) =>
        s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_').trim();

    if (widget.descripcion != null && widget.descripcion!.isNotEmpty) {
      final candidate = Directory(
        '${mapsDir.path}/${slug(widget.descripcion!)}',
      );
      if (await candidate.exists()) return candidate.path;
    }

    // fallback: find first subdirectory that contains some .png file in nested z/x/y structure
    await for (var entry in mapsDir.list()) {
      if (entry is Directory) {
        try {
          final found = await entry
              .list(recursive: true)
              .any((f) => f is File && f.path.toLowerCase().endsWith('.png'));
          if (found) return entry.path;
        } catch (e) {
          // ignore permission/listing errors on specific entries
        }
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    // Ejemplo de datos, debes obtenerlos dinámicamente según la ruta:
    final double centerLat = 15.525585;
    final double centerLng = -88.013512;
    final List<LatLng> markers = [LatLng(15.525585, -88.013512)];
    return Scaffold(
      appBar: AppBar(title: Text(widget.descripcion ?? 'Mapa Offline')),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : localTilesPath != null
          ? FlutterMap(
              options: MapOptions(
                center: LatLng(centerLat, centerLng),
                zoom: 13.0,
              ),
              children: [
                TileLayer(
                  urlTemplate: '{z}/{x}/{y}.png',
                  tileProvider: LocalFileTileProvider(localTilesPath!),
                  tileSize: 256,
                ),
                MarkerLayer(
                  markers: markers
                      .map(
                        (latlng) => Marker(
                          point: latlng,
                          width: 40,
                          height: 40,
                          child: const Icon(
                            Icons.location_on,
                            color: Colors.red,
                            size: 32,
                          ),
                        ),
                      )
                      .toList(),
                ),
              ],
            )
          : Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.map, size: 56, color: Colors.grey),
                  const SizedBox(height: 12),
                  const Text('No hay mapa offline disponible'),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: () => _loadLocalMap(),
                    child: const Text('Reintentar detectar'),
                  ),
                ],
              ),
            ),
    );
  }
}

// TileProvider that reads tiles from local file system using a base path.
class LocalFileTileProvider extends TileProvider {
  final String basePath;
  LocalFileTileProvider(this.basePath);

  // Use dynamic parameters to avoid strict signature mismatch across flutter_map versions
  ImageProvider getImage(dynamic coords, dynamic options) {
    // coords.x/y/z can be num, convert to int
    final z = (coords.z ?? coords.z!).toInt();
    final x = (coords.x ?? coords.x!).toInt();
    final y = (coords.y ?? coords.y!).toInt();
    final file = File('$basePath/$z/$x/$y.png');
    if (file.existsSync()) {
      return FileImage(file);
    }
    // If tile not found, return a transparent 1x1 image (so map can render gaps without crash).
    final kTransparentImage = <int>[
      0x89,
      0x50,
      0x4E,
      0x47,
      0x0D,
      0x0A,
      0x1A,
      0x0A,
      0x00,
      0x00,
      0x00,
      0x0D,
      0x49,
      0x48,
      0x44,
      0x52,
      0x00,
      0x00,
      0x00,
      0x01,
      0x00,
      0x00,
      0x00,
      0x01,
      0x08,
      0x06,
      0x00,
      0x00,
      0x00,
      0x1F,
      0x15,
      0xC4,
      0x89,
      0x00,
      0x00,
      0x00,
      0x0A,
      0x49,
      0x44,
      0x41,
      0x54,
      0x78,
      0x9C,
      0x63,
      0x00,
      0x01,
      0x00,
      0x00,
      0x05,
      0x00,
      0x01,
      0x0D,
      0x0A,
      0x2D,
      0xB4,
      0x00,
      0x00,
      0x00,
      0x00,
      0x49,
      0x45,
      0x4E,
      0x44,
      0xAE,
      0x42,
      0x60,
      0x82,
    ];
    return MemoryImage(Uint8List.fromList(kTransparentImage));
  }
}

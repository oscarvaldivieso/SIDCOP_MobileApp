import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';

/// Offline map viewer that serves tiles from a local .mbtiles file via a
/// loopback HTTP server and uses flutter_map to render them.
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
  Database? _mbtilesDb;
  HttpServer? _server;
  int? _serverPort;
  bool _starting = true;
  bool _hasMbtiles = false;
  // Controller for programmatic map movements
  final MapController _mapController = MapController();

  // Simple LRU cache for tiles (key = z/x/y)
  final Map<String, Uint8List> _tileCache = {};
  final List<String> _cacheOrder = [];
  final int _cacheMaxEntries = 200;

  // Device-based center (may be null until obtained). Fallback coords are
  // initialized to a sensible default but will be updated from the device
  // (last known position or current) when available.
  double? _centerLat;
  double? _centerLng;
  double _fallbackLat = 15.505456;
  double _fallbackLng = -88.025102;

  @override
  void initState() {
    super.initState();
    // Start obtaining device location and initialize server in parallel.
    _setInitialPositionFromDevice();
    _initMbtilesServer();
  }

  Future<void> _setInitialPositionFromDevice() async {
    try {
      // Try to seed fallback with last known position to center quicker
      try {
        final last = await Geolocator.getLastKnownPosition();
        if (last != null) {
          _fallbackLat = last.latitude;
          _fallbackLng = last.longitude;
        }
      } catch (_) {}
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever ||
          permission == LocationPermission.denied) {
        // no permission, keep fallback
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      setState(() {
        _centerLat = pos.latitude;
        _centerLng = pos.longitude;
        // update fallbacks so other parts of the UI use the device coords
        _fallbackLat = pos.latitude;
        _fallbackLng = pos.longitude;
      });
    } catch (e) {
      // ignore and fallback to defaults
    }
  }

  Future<void> _recenterToDevice() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever ||
          permission == LocationPermission.denied) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Permiso de ubicación denegado')),
        );
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      final lat = pos.latitude;
      final lng = pos.longitude;
      setState(() {
        _centerLat = lat;
        _centerLng = lng;
      });
      try {
        _mapController.move(LatLng(lat, lng), 15.0);
      } catch (_) {}
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo obtener la ubicación')),
      );
    }
  }

  Future<void> _initMbtilesServer() async {
    try {
      final mbtilesFile = await _findFirstMbtilesFile();
      if (mbtilesFile == null) {
        setState(() {
          _starting = false;
          _hasMbtiles = false;
        });
        return;
      }

      // Open the MBTiles database read-only
      _mbtilesDb = await openDatabase(mbtilesFile.path, readOnly: true);

      // Start a loopback HTTP server to serve tiles
      _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      _serverPort = _server!.port;
      print(
        'MBTiles HTTP server started on port $_serverPort, file=${mbtilesFile.path}',
      );

      _server!.listen((HttpRequest request) async {
        try {
          final path = request.uri.path; // e.g. /{z}/{x}/{y}.png
          print('MBTiles server request: $path');
          final parts = path.split('/').where((s) => s.isNotEmpty).toList();
          if (parts.length >= 3) {
            final z = int.tryParse(parts[0]);
            final x = int.tryParse(parts[1]);
            var yStr = parts[2];
            // strip possible extension
            if (yStr.contains('.')) yStr = yStr.split('.').first;
            final y = int.tryParse(yStr);

            if (z != null && x != null && y != null) {
              final bytes = await _getTileBytes(z, x, y);
              if (bytes != null) {
                final mime = _detectMime(bytes) ?? 'application/octet-stream';
                request.response.headers.set('Content-Type', mime);
                request.response.add(bytes);
                await request.response.close();
                print('Served tile $z/$x/$y (${bytes.length} bytes)');
                return;
              } else {
                print('Tile not found in MBTiles: $z/$x/$y');
              }
            }
          }

          // Not found
          request.response.statusCode = HttpStatus.notFound;
          await request.response.close();
        } catch (_) {
          try {
            request.response.statusCode = HttpStatus.internalServerError;
            await request.response.close();
          } catch (_) {}
        }
      });

      setState(() {
        _starting = false;
        _hasMbtiles = true;
      });
    } catch (e) {
      // If anything fails, fall back to no-mbtiles UI
      setState(() {
        _starting = false;
        _hasMbtiles = false;
      });
    }
  }

  Future<File?> _findFirstMbtilesFile() async {
    final docs = await getApplicationDocumentsDirectory();
    final mapsDir = Directory(p.join(docs.path, 'maps'));
    if (!await mapsDir.exists()) return null;
    final files = mapsDir.listSync();
    for (final f in files) {
      if (f is File && p.extension(f.path).toLowerCase() == '.mbtiles') {
        return f;
      }
    }
    return null;
  }

  Future<Uint8List?> _getTileBytes(int z, int x, int y) async {
    // build a real key string from numbers
    final keyStr = '\$z/\$x/\$y'
        .replaceAll('\\', '')
        .replaceAll('\$z', z.toString())
        .replaceAll('\$x', x.toString())
        .replaceAll('\$y', y.toString());
    // LRU cache check using concrete key
    final cached = _tileCache[keyStr];
    if (cached != null) {
      // promote
      _cacheOrder.remove(keyStr);
      _cacheOrder.add(keyStr);
      return cached;
    }

    if (_mbtilesDb == null) return null;

    // Try direct y, then TMS-flipped y
    Uint8List? data;
    try {
      final res = await _mbtilesDb!.query(
        'tiles',
        columns: ['tile_data'],
        where: 'zoom_level = ? AND tile_column = ? AND tile_row = ?',
        whereArgs: [z, x, y],
        limit: 1,
      );
      if (res.isNotEmpty) {
        data = res.first['tile_data'] as Uint8List?;
      }
    } catch (_) {}

    if (data == null) {
      try {
        final flippedY = ((1 << z) - 1) - y;
        final res2 = await _mbtilesDb!.query(
          'tiles',
          columns: ['tile_data'],
          where: 'zoom_level = ? AND tile_column = ? AND tile_row = ?',
          whereArgs: [z, x, flippedY],
          limit: 1,
        );
        if (res2.isNotEmpty) {
          data = res2.first['tile_data'] as Uint8List?;
        }
      } catch (_) {}
    }

    if (data != null) {
      _addToCache(keyStr, data);
    }
    return data;
  }

  void _addToCache(String key, Uint8List bytes) {
    _tileCache[key] = bytes;
    _cacheOrder.add(key);
    if (_cacheOrder.length > _cacheMaxEntries) {
      final oldest = _cacheOrder.removeAt(0);
      _tileCache.remove(oldest);
    }
  }

  String? _detectMime(Uint8List bytes) {
    if (bytes.length >= 8 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47) {
      return 'image/png';
    }
    if (bytes.length >= 3 &&
        bytes[0] == 0xFF &&
        bytes[1] == 0xD8 &&
        bytes[2] == 0xFF) {
      return 'image/jpeg';
    }
    return null;
  }

  @override
  void dispose() {
    try {
      _server?.close(force: true);
    } catch (_) {}
    try {
      _mbtilesDb?.close();
    } catch (_) {}
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double centerLat = _centerLat ?? _fallbackLat;
    final double centerLng = _centerLng ?? _fallbackLng;
    final markers = [LatLng(centerLat, centerLng)];

    Widget map;
    if (_starting) {
      map = const Center(child: CircularProgressIndicator());
    } else if (_hasMbtiles && _serverPort != null) {
      final urlTemplate = 'http://127.0.0.1:$_serverPort/{z}/{x}/{y}.png';
      print('Using tile url template: $urlTemplate');
      map = FlutterMap(
        mapController: _mapController,
        options: MapOptions(center: LatLng(centerLat, centerLng), zoom: 15.0),
        children: [
          TileLayer(
            urlTemplate: urlTemplate,
            tileProvider: NetworkTileProvider(),
          ),
          MarkerLayer(
            markers: markers
                .map(
                  (latlng) => Marker(
                    point: latlng,
                    width: 15,
                    height: 15,
                    child: Container(
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.blue,
                        border: Border.all(color: Colors.white, width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.blue,
                            blurRadius: 6,
                            spreadRadius: 0.5,
                          ),
                        ],
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      );
    } else {
      // Fallback: try to detect MBTiles again and offer a retry
      map = Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.info_outline, size: 48),
            const SizedBox(height: 8),
            const Text('No se detectó MBTiles activo.'),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () async {
                setState(() => _starting = true);
                // attempt to init again
                await _initMbtilesServer();
              },
              child: const Text('Reintentar detectar MBTiles'),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(widget.descripcion ?? 'Mapa Offline')),
      body: map,
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.my_location),
        onPressed: _recenterToDevice,
        tooltip: 'Ir a ubicación',
      ),
    );
  }
}

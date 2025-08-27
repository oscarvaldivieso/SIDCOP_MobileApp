import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_map/flutter_map.dart';
import 'dart:typed_data';
import 'package:latlong2/latlong.dart';
import 'dart:math' as math;

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
  LatLng? tilesCenter;
  double? tilesZoom;
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
    // Buscar únicamente una carpeta de tiles bajo <documents>/maps
    // (si existe, la usaremos; si no, informamos que no hay mapa offline)
    // 2) try to find a tiles folder under <documents>/maps
    final tilesBase = await _findTilesBasePath(directory);
    if (tilesBase != null) {
      // calcular centro y zoom a partir de la estructura de tiles
      final view = await _computeTilesView(tilesBase);
      setState(() {
        localTilesPath = tilesBase;
        tilesCenter = view?['center'] as LatLng?;
        tilesZoom = view?['zoom'] as double?;
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
  Future<String?> _findTilesBasePath(Directory documentsDir) async {
    final mapsDir = Directory('${documentsDir.path}/maps');
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

  // Inspecciona la carpeta de tiles para determinar un centro y zoom útiles.
  // Retorna {'center': LatLng, 'zoom': double} o null si no puede calcular.
  Future<Map<String, Object?>?> _computeTilesView(String basePath) async {
    try {
      final baseDir = Directory(basePath);
      if (!await baseDir.exists()) return null;

      // listar directorios z (nombres numéricos)
      final zs = <int>[];
      await for (final entry in baseDir.list()) {
        if (entry is Directory) {
          final name = entry.path.split(Platform.pathSeparator).last;
          final z = int.tryParse(name);
          if (z != null) zs.add(z);
        }
      }
      if (zs.isEmpty) return null;

      zs.sort();
      // preferir el zoom más alto disponible (mayor detalle)
      for (final z in zs.reversed) {
        final zDir = Directory('$basePath${Platform.pathSeparator}$z');
        if (!await zDir.exists()) continue;

        final xs = <int>{};
        // recorrer x carpetas
        await for (final xEntry in zDir.list()) {
          if (xEntry is Directory) {
            final xName = xEntry.path.split(Platform.pathSeparator).last;
            final x = int.tryParse(xName);
            if (x == null) continue;
            xs.add(x);
          }
        }
        if (xs.isEmpty) continue;

        int? minX, maxX, minY, maxY;
        final pow2z = math.pow(2, z).toDouble();

        for (final x in xs) {
          final xDir = Directory(
            '$basePath${Platform.pathSeparator}$z${Platform.pathSeparator}$x',
          );
          if (!await xDir.exists()) continue;
          await for (final yEntry in xDir.list()) {
            if (yEntry is File) {
              final fileName = yEntry.path.split(Platform.pathSeparator).last;
              final nameNoExt = fileName.split('.').first;
              final y = int.tryParse(nameNoExt);
              if (y == null) continue;
              minX = (minX == null) ? x : math.min(minX, x);
              maxX = (maxX == null) ? x : math.max(maxX, x);
              minY = (minY == null) ? y : math.min(minY, y);
              maxY = (maxY == null) ? y : math.max(maxY, y);
            }
          }
        }

        if (minX == null || minY == null || maxX == null || maxY == null) {
          // intentar siguiente z
          continue;
        }

        final centerX = (minX + maxX) / 2.0;
        final centerY = (minY + maxY) / 2.0;

        // convertir tile numbers a lat/lng (Web Mercator)
        final lon = (centerX / pow2z) * 360.0 - 180.0;
        final n = math.pi - 2.0 * math.pi * centerY / pow2z;
        final sinhN = (math.exp(n) - math.exp(-n)) / 2.0;
        final lat = math.atan(sinhN) * 180.0 / math.pi;

        return {'center': LatLng(lat, lon), 'zoom': z.toDouble()};
      }
    } catch (e) {
      // ignore
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
      appBar: AppBar(
        title: Text(widget.descripcion ?? 'Mapa Offline'),
        actions: [
          IconButton(
            tooltip: 'Depurar tiles',
            icon: const Icon(Icons.bug_report),
            onPressed: () async {
              if (localTilesPath == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('No hay carpeta de tiles detectada'),
                  ),
                );
                return;
              }
              final tiles = await _sampleTiles(localTilesPath!, 20);
              await showDialog(
                context: context,
                builder: (ctx) => _buildTilesDebugDialog(ctx, tiles),
              );
            },
          ),
        ],
      ),
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

  // Devuelve hasta [limit] paths de tiles encontrados en la estructura base/z/x/y.png
  Future<List<String>> _sampleTiles(String basePath, [int limit = 20]) async {
    final results = <String>[];
    try {
      final baseDir = Directory(basePath);
      if (!await baseDir.exists()) return results;

      await for (var zEntry in baseDir.list()) {
        if (results.length >= limit) break;
        if (zEntry is Directory) {
          await for (var xEntry in zEntry.list()) {
            if (results.length >= limit) break;
            if (xEntry is Directory) {
              await for (var yEntry in xEntry.list()) {
                if (results.length >= limit) break;
                if (yEntry is File) {
                  final low = yEntry.path.toLowerCase();
                  if (low.endsWith('.png') ||
                      low.endsWith('.jpg') ||
                      low.endsWith('.jpeg')) {
                    results.add(yEntry.path);
                  }
                }
              }
            }
          }
        }
      }
    } catch (e) {
      // ignorar errores y devolver lo que se haya encontrado
    }
    return results;
  }

  Widget _buildTilesDebugDialog(BuildContext context, List<String> tiles) {
    String? selected;
    return StatefulBuilder(
      builder: (context, setState) {
        return AlertDialog(
          title: Text('Tiles detectados (${tiles.length})'),
          content: SizedBox(
            width: 360,
            height: 360,
            child: Column(
              children: [
                Expanded(
                  child: tiles.isEmpty
                      ? const Center(child: Text('No se encontraron tiles'))
                      : ListView.builder(
                          itemCount: tiles.length,
                          itemBuilder: (ctx, i) {
                            final path = tiles[i];
                            return ListTile(
                              dense: true,
                              title: Text(p.basename(path)),
                              subtitle: Text(
                                path,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              onTap: () => setState(() => selected = path),
                            );
                          },
                        ),
                ),
                const SizedBox(height: 8),
                if (selected != null) ...[
                  const Text('Previsualización'),
                  const SizedBox(height: 6),
                  SizedBox(height: 120, child: Image.file(File(selected!))),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cerrar'),
            ),
          ],
        );
      },
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
    // Intent: soportar tiles generados por qtiles (estructura z/x/y.png)
    // y también soportar variantes TMS (y invertido) y .jpg.
    final candidates = <String>[];
    final sep = Platform.pathSeparator;
    candidates.add('$basePath$sep$z$sep$x$sep$y.png');
    candidates.add('$basePath$sep$z$sep$x$sep$y.jpg');
    // TMS fallback: y_tms = 2^z - 1 - y
    final int pow2z = 1 << z;
    final int yTms = ((pow2z - 1) - y).toInt();
    candidates.add('$basePath$sep$z$sep$x$sep$yTms.png');
    candidates.add('$basePath$sep$z$sep$x$sep$yTms.jpg');

    for (final path in candidates) {
      final f = File(path);
      if (f.existsSync()) return FileImage(f);
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

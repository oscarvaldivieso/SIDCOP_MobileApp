import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'dart:typed_data';
import 'dart:ui' as ui;
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
  String? localMbtilesPath;
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

    // Try to find an MBTiles file or registered map index
    final mb = await _findMbtilesPath(directory);
    if (mb != null) {
      setState(() {
        localMbtilesPath = mb;
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
    String slug(String s) {
      return s
          .toLowerCase()
          .replaceAll(' ', '_')
          .replaceAll('á', 'a')
          .replaceAll('í', 'i')
          .replaceAll('ó', 'o')
          .replaceAll('é', 'e')
          .replaceAll('ú', 'u')
          .replaceAll('ñ', 'n');
    }

    if (widget.descripcion != null && widget.descripcion!.isNotEmpty) {
      final candidate = Directory(
        '${mapsDir.path}/${slug(widget.descripcion!)}',
      );
      if (await candidate.exists()) return candidate.path;
    }

    // fallback: search more deeply — soportar zippers que extraen en una carpeta adicional
    await for (var entry in mapsDir.list()) {
      if (entry is Directory) {
        try {
          // 1) check if this directory itself contains tiles
          final foundHere = await entry
              .list(recursive: false)
              .any((f) => f is Directory);
          if (foundHere) {
            // check deeper for png files inside
            final found = await entry
                .list(recursive: true)
                .any((f) => f is File && f.path.toLowerCase().endsWith('.png'));
            if (found) return entry.path;
          }

          // 2) look one level deeper (some zips create maps/atlantida/atlantida/16/...)
          await for (var sub in entry.list()) {
            if (sub is Directory) {
              final foundSub = await sub
                  .list(recursive: true)
                  .any(
                    (f) => f is File && f.path.toLowerCase().endsWith('.png'),
                  );
              if (foundSub) return sub.path;
            }
          }
        } catch (e) {
          // ignore permission/listing errors on specific entries
        }
      }
    }
    return null;
  }

  // Look for a registered MBTiles path via maps_index.json or direct .mbtiles files
  Future<String?> _findMbtilesPath(Directory documentsDir) async {
    final mapsDir = Directory('${documentsDir.path}/maps');
    if (!await mapsDir.exists()) return null;

    // 1) check maps_index.json
    final indexFile = File(p.join(mapsDir.path, 'maps_index.json'));
    if (await indexFile.exists()) {
      try {
        final content = await indexFile.readAsString();
        if (content.trim().isNotEmpty) {
          final Map<String, dynamic> idx =
              json.decode(content) as Map<String, dynamic>;
          if (widget.descripcion != null) {
            final slug = widget.descripcion!
                .toLowerCase()
                .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
                .trim();
            final mapped = idx[slug];
            if (mapped is String) {
              final lower = mapped.toLowerCase();
              if (lower.endsWith('.mbtiles')) {
                final f = File(mapped);
                if (await f.exists()) return mapped;
              } else {
                // mapped might be a folder where the zip was extracted; search inside
                final d = Directory(mapped);
                if (await d.exists()) {
                  await for (final found in d.list(recursive: true)) {
                    if (found is File &&
                        found.path.toLowerCase().endsWith('.mbtiles'))
                      return found.path;
                  }
                }
              }
            }
          }
          // fallback: find any mbtiles value
          for (final v in idx.values) {
            if (v is String) {
              final lv = v.toLowerCase();
              if (lv.endsWith('.mbtiles')) {
                final f = File(v);
                if (await f.exists()) return v;
              } else {
                final d = Directory(v);
                if (await d.exists()) {
                  await for (final found in d.list(recursive: true)) {
                    if (found is File &&
                        found.path.toLowerCase().endsWith('.mbtiles'))
                      return found.path;
                  }
                }
              }
            }
          }
        }
      } catch (_) {}
    }

    // 2) search maps directory for .mbtiles files
    await for (final e in mapsDir.list(recursive: true)) {
      if (e is File && e.path.toLowerCase().endsWith('.mbtiles')) return e.path;
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
              // Mostrar indicador mientras se calcula el diagnóstico
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (_) =>
                    const Center(child: CircularProgressIndicator()),
              );
              final diag = await _diagnoseTiles(localTilesPath!);
              if (mounted) Navigator.of(context).pop();
              await showDialog(
                context: context,
                builder: (ctx) => _buildDiagnosisDialog(ctx, diag),
              );
            },
          ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : (localTilesPath != null || localMbtilesPath != null)
          ? (localMbtilesPath != null
                ? FlutterMap(
                    options: MapOptions(
                      center: LatLng(centerLat, centerLng),
                      zoom: 13.0,
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: '{z}/{x}/{y}.png',
                        tileProvider: MbtilesTileProvider(localMbtilesPath!),
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
                : FlutterMap(
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
                  ))
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

  // funciones de muestreo/depuración anteriores fueron removidas en favor del diagnóstico

  // Diagnóstico: cuenta tiles por z, calcula tamaño total (bytes) y devuelve muestras por z
  Future<Map<String, Object>> _diagnoseTiles(String basePath) async {
    final Map<int, int> countByZ = {};
    final Map<int, List<String>> samplesByZ = {};
    int totalTiles = 0;
    int totalBytes = 0;
    try {
      final baseDir = Directory(basePath);
      if (!await baseDir.exists())
        return {
          'countByZ': countByZ,
          'samplesByZ': samplesByZ,
          'totalTiles': totalTiles,
          'totalBytes': totalBytes,
        };

      await for (final zEntry in baseDir.list()) {
        if (zEntry is! Directory) continue;
        final zName = zEntry.path.split(Platform.pathSeparator).last;
        final z = int.tryParse(zName);
        if (z == null) continue;
        int zcount = 0;
        final zsamples = <String>[];
        await for (final xEntry in zEntry.list()) {
          if (xEntry is! Directory) continue;
          await for (final yEntry in xEntry.list()) {
            if (yEntry is! File) continue;
            final low = yEntry.path.toLowerCase();
            if (!(low.endsWith('.png') ||
                low.endsWith('.jpg') ||
                low.endsWith('.jpeg')))
              continue;
            zcount++;
            totalTiles++;
            try {
              totalBytes += await yEntry.length();
            } catch (_) {}
            if (zsamples.length < 5) zsamples.add(yEntry.path);
          }
        }
        if (zcount > 0) {
          countByZ[z] = zcount;
          samplesByZ[z] = zsamples;
        }
      }
    } catch (e) {
      // ignore
    }
    return {
      'countByZ': countByZ,
      'samplesByZ': samplesByZ,
      'totalTiles': totalTiles,
      'totalBytes': totalBytes,
    };
  }

  Widget _buildDiagnosisDialog(BuildContext context, Map<String, Object> diag) {
    final countByZ = diag['countByZ'] as Map<int, int>;
    final samplesByZ = diag['samplesByZ'] as Map<int, List<String>>;
    final totalTiles = diag['totalTiles'] as int;
    final totalBytes = diag['totalBytes'] as int;
    return AlertDialog(
      title: const Text('Diagnóstico de tiles'),
      content: SizedBox(
        width: 360,
        height: 420,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Total tiles: $totalTiles'),
            Text('Tamaño total: ${_formatBytesSimple(totalBytes)}'),
            const SizedBox(height: 8),
            const Text(
              'Tiles por zoom (muestra):',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Expanded(
              child: countByZ.isEmpty
                  ? const Center(child: Text('No se detectaron tiles'))
                  : ListView.builder(
                      itemCount: countByZ.keys.length,
                      itemBuilder: (ctx, idx) {
                        final keys = countByZ.keys.toList()..sort();
                        final z = keys[idx];
                        final cnt = countByZ[z] ?? 0;
                        final samples = samplesByZ[z] ?? <String>[];
                        return ListTile(
                          title: Text('z=$z — $cnt tiles'),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: samples
                                .map((s) => Text(p.basename(s)))
                                .toList(),
                          ),
                        );
                      },
                    ),
            ),
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
  }

  String _formatBytesSimple(int bytes) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB'];
    var i = 0;
    double value = bytes.toDouble();
    while (value >= 1024 && i < suffixes.length - 1) {
      value /= 1024;
      i++;
    }
    return '${value.toStringAsFixed(1)} ${suffixes[i]}';
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

// MBTiles ImageProvider: reads tile_data from tiles table (z, x, y) and returns MemoryImage
class MbtilesImageProvider extends ImageProvider<MbtilesImageProvider> {
  final String dbPath;
  final int z;
  final int x;
  final int y;

  MbtilesImageProvider(this.dbPath, this.z, this.x, this.y);

  @override
  Future<MbtilesImageProvider> obtainKey(ImageConfiguration configuration) {
    return SynchronousFuture<MbtilesImageProvider>(this);
  }

  static final Map<String, Database> _dbCache = {};

  Future<Uint8List?> _loadTileBytes() async {
    try {
      var db = _dbCache[dbPath];
      if (db == null || !db.isOpen) {
        db = await openReadOnlyDatabase(dbPath);
        _dbCache[dbPath] = db;
      }
      // Try direct (z,x,y)
      var res = await db.rawQuery(
        'SELECT tile_data FROM tiles WHERE zoom_level = ? AND tile_column = ? AND tile_row = ?',
        [z, x, y],
      );
      if (res.isEmpty) {
        // try TMS flipped row (some MBTiles are TMS)
        final int pow2z = 1 << z;
        final int yTms = ((pow2z - 1) - y).toInt();
        res = await db.rawQuery(
          'SELECT tile_data FROM tiles WHERE zoom_level = ? AND tile_column = ? AND tile_row = ?',
          [z, x, yTms],
        );
      }
      if (res.isNotEmpty && res.first['tile_data'] != null) {
        final data = res.first['tile_data'];
        if (data is Uint8List) return data;
        if (data is List<int>) return Uint8List.fromList(List<int>.from(data));
      }
    } catch (e) {
      // ignore
    }
    return null;
  }

  ImageStreamCompleter load(
    MbtilesImageProvider key,
    ImageDecoderCallback decode,
  ) {
    final future = _loadTileBytes().then<ui.Image>((bytes) async {
      if (bytes == null) throw StateError('Tile not found');
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      return frame.image;
    });
    return OneFrameImageStreamCompleter(
      future.then((img) => ImageInfo(image: img)),
    );
  }
}

// TileProvider that uses MBTiles database
class MbtilesTileProvider extends TileProvider {
  final String dbPath;
  MbtilesTileProvider(this.dbPath);

  ImageProvider getImage(dynamic coords, dynamic options) {
    final z = (coords.z ?? coords.z!).toInt();
    final x = (coords.x ?? coords.x!).toInt();
    final y = (coords.y ?? coords.y!).toInt();
    // MBTiles typically use TMS y; tile_row may need conversion depending on MBTiles.
    // We'll try direct y first; fallback to TMS conversion will be attempted by provider logic (not here).
    return MbtilesImageProvider(dbPath, z, x, y);
  }
}

// Helper to open DB in read-only mode compatible with sqflite
Future<Database> openReadOnlyDatabase(String path) async {
  // sqflite doesn't expose a direct readonly flag; openDatabase works for reading.
  return await openDatabase(path, readOnly: true);
}

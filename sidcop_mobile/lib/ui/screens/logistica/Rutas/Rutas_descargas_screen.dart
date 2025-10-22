import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'dart:convert';
import 'dart:async';
import 'package:sidcop_mobile/services/download_service.dart' as _ds;

// Pantalla para descargar mapas offline de departamentos
class RutasDescargasScreen extends StatefulWidget {
  const RutasDescargasScreen({Key? key}) : super(key: key);

  @override
  State<RutasDescargasScreen> createState() => _RutasDescargasScreenState();
}

class _RutasDescargasScreenState extends State<RutasDescargasScreen> {
  // Lista de departamentos disponibles para descarga
  final List<String> departamentos = const ['Honduras'];

  // Overlay para mostrar progreso de descarga
  OverlayEntry? _downloadOverlay;

  // URLs de descarga para el mapa offline de honduras
  final Map<String, String> urls = {
    'Honduras':
        'http://200.59.27.115/Honduras_map/mapa_honduras_2025-08-27_180657.mbtiles',
  };

  // Obtiene el directorio donde se almacenan los mapas
  Future<Directory> _Mapdir() async {
    final dir = await getApplicationDocumentsDirectory();
    final mapsDir = Directory(p.join(dir.path, 'maps'));
    if (!await mapsDir.exists()) await mapsDir.create(recursive: true);
    return mapsDir;
  }

  // Obtiene la ruta completa del archivo mbtiles para un departamento
  Future<String> _mbtilesPathFor(String departamento) async {
    final mapsDir = await _Mapdir();

    return p.join(mapsDir.path, 'honduras.mbtiles');
  }

  // Verifica si el mapa del departamento ya está descargado
  Future<bool> _isMbtilesDownloaded(String departamento) async {
    try {
      final mapsDir = await _Mapdir();

      final indexFile = File(p.join(mapsDir.path, 'maps_index.json'));
      if (await indexFile.exists()) {
        try {
          final content = await indexFile.readAsString();
          if (content.trim().isNotEmpty) {
            final Map<String, dynamic> index = json.decode(content);
            if (index.containsKey('honduras')) return true;
          }
        } catch (_) {}
      }

      final list = mapsDir.listSync();
      for (final ent in list) {
        if (ent is File && p.extension(ent.path).toLowerCase() == '.mbtiles') {
          return true;
        }
      }
    } catch (_) {}
    return false;
  }

  // Limpia recursos al cerrar la pantalla
  @override
  void dispose() {
    try {
      _downloadOverlay?.remove();
    } catch (_) {}
    super.dispose();
  }

  // Inicializa la pantalla y verifica descargas en progreso
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      const id = 'honduras';
      if (_ds.DownloadService.instance.isDownloading(id)) {
        _downloadOverlay = _showDownloadOverlay(
          context,
          _ds.DownloadService.instance.progressStream(id),
        );
      }
    });
  }

  // Muestra un overlay con el progreso de descarga
  OverlayEntry _showDownloadOverlay(
    BuildContext context,
    Stream<Map<String, int>> stream,
  ) {
    final entry = OverlayEntry(
      builder: (ctx) => _DownloadProgressOverlay(progressStream: stream),
    );

    try {
      Overlay.of(context).insert(entry);
    } catch (_) {
    }
    return entry;
  }

  // Maneja el proceso de descarga de un departamento
  Future<void> _handleDownload(String departamento) async {
    final url = urls[departamento];
    if (url == null) return;

    final id = departamento.toLowerCase();

    final mbPath = await _mbtilesPathFor(departamento);
    final f = File(mbPath);
    bool proceed = true;
    
    // Confirma si el usuario quiere reemplazar un mapa existente
    if (await f.exists()) {
      final answer = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Re-descargar'),
          content: const Text(
            'Ya existe un mapa descargado. ¿Deseas reemplazarlo?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('No'),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Sí'),
            ),
          ],
        ),
      );
      proceed = answer == true;
    }
    if (!proceed) return;

    // Inicia la descarga usando el servicio de descargas
    try {
      final futurePath = _ds.DownloadService.instance.startDownload(
        id: id,
        url: url,
        filename: 'honduras.mbtiles',
      );

      _downloadOverlay ??= _showDownloadOverlay(
        context,
        _ds.DownloadService.instance.progressStream(id),
      );

      final saved = await futurePath;
      try {
        _downloadOverlay?.remove();
      } catch (_) {}
      _downloadOverlay = null;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Descargado: ${p.basename(saved)}')),
      );
      setState(() {});
    } catch (e) {
      try {
        _downloadOverlay?.remove();
      } catch (_) {}
      _downloadOverlay = null;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(color: Color(0xFFD6B68A)),
        title: const Text('Descargas - Mapas Offline'),
        titleTextStyle: const TextStyle(
          color: Color(0xFFD6B68A),
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
        backgroundColor: const Color(0xFF141A2F),
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            color: const Color(0xFF141A2F),
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            child: Row(
              children: const [
                Icon(Icons.signal_wifi_off, color: Color(0xFFD6B68A)),
                SizedBox(width: 10),
                Text(
                  'Mapa Sin conexion',
                  style: TextStyle(
                    color: Color(0xFFD6B68A),
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
              itemCount: departamentos.length,
              separatorBuilder: (_, __) => const SizedBox(height: 6),
              itemBuilder: (context, index) {
                final d = departamentos[index];
                final hasUrl = urls.containsKey(d);
                return FutureBuilder<bool>(
                  future: _isMbtilesDownloaded(d),
                  builder: (context, snapZip) {
                    final downloaded = snapZip.data ?? false;
                    return Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      margin: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        title: Text(
                          d,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Text(
                          downloaded
                              ? 'Estado: descargado'
                              : 'Estado: no descargado',
                        ),
                        trailing: IconButton(
                          tooltip: downloaded
                              ? 'Volver a descargar'
                              : 'Descargar',
                          icon: const Icon(Icons.download),
                          color: const Color(0xFFD6B68A),
                          onPressed: hasUrl ? () => _handleDownload(d) : null,
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// Widget para mostrar el progreso de descarga
class _DownloadProgressOverlay extends StatelessWidget {
  final Stream<Map<String, int>> progressStream;
  const _DownloadProgressOverlay({required this.progressStream, Key? key})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 16,
      right: 16,
      bottom: 24,
      child: Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(8),
        color: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: StreamBuilder<Map<String, int>>(
            stream: progressStream,
            builder: (ctx, snap) {
              final r = snap.data?['r'] ?? 0;
              final t = snap.data?['t'] ?? 0;
              final percent = (t > 0) ? (r / t).clamp(0.0, 1.0) : null;
              final rMb = (r / 1024 / 1024);
              final tMb = (t / 1024 / 1024);
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Descargando: ${rMb.toStringAsFixed(2)} MB de ${t > 0 ? tMb.toStringAsFixed(2) : '--'} MB',
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(value: percent),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
// archive package removed: we no longer extract ZIPs on-device; we download raw .mbtiles
import 'package:path/path.dart' as p;
// dart:math removed (not used)
import 'dart:convert';
import 'dart:async';
import 'package:file_picker/file_picker.dart';

class RutasDescargasScreen extends StatefulWidget {
  const RutasDescargasScreen({Key? key}) : super(key: key);

  @override
  State<RutasDescargasScreen> createState() => _RutasDescargasScreenState();
}

class _RutasDescargasScreenState extends State<RutasDescargasScreen> {
  final List<String> departamentos = const ['Honduras'];

  // Original URL points to a ZIP; we will try to replace .zip -> .mbtiles when downloading
  final Map<String, String> urls = {
    'Honduras':
        'http://200.59.27.115/Honduras_map/mapa_honduras_2025-08-27_180657.mbtiles',
  };

  String _slug(String departamento) => departamento
      .toLowerCase()
      .replaceAll(' ', '_')
      .replaceAll('á', 'a')
      .replaceAll('í', 'i')
      .replaceAll('ó', 'o')
      .replaceAll('é', 'e')
      .replaceAll('ú', 'u')
      .replaceAll('ñ', 'n');

  Future<Directory> _ensureMapsDir() async {
    final dir = await getApplicationDocumentsDirectory();
    final mapsDir = Directory(p.join(dir.path, 'maps'));
    if (!await mapsDir.exists()) await mapsDir.create(recursive: true);
    return mapsDir;
  }

  Future<String> _mbtilesPathFor(String departamento) async {
    final mapsDir = await _ensureMapsDir();
    final slug = _slug(departamento);
    return p.join(mapsDir.path, '$slug.mbtiles');
  }

  Future<bool> _isMbtilesDownloaded(String departamento) async {
    final path = await _mbtilesPathFor(departamento);
    return await File(path).exists();
  }

  // Stream download .mbtiles to disk (tmp -> rename)
  Future<String> _downloadAndSaveMbtiles(
    String url,
    String departamento,
    void Function(int, int) onProgress,
  ) async {
    final mapsDir = await _ensureMapsDir();
    final slug = _slug(departamento);
    final finalPath = p.join(mapsDir.path, '$slug.mbtiles');
    final tmpPath = '$finalPath.tmp';

    final client = http.Client();
    final req = http.Request('GET', Uri.parse(url));
    final resp = await client.send(req);
    if (resp.statusCode != 200) {
      client.close();
      throw Exception('Error descargando: ${resp.statusCode}');
    }

    final contentLength = resp.contentLength ?? 0;
    final sink = File(tmpPath).openWrite();
    int received = 0;
    await for (final chunk in resp.stream) {
      sink.add(chunk);
      received += chunk.length;
      try {
        onProgress(received, contentLength);
      } catch (_) {}
    }
    await sink.close();
    client.close();

    // rename
    try {
      await File(tmpPath).rename(finalPath);
    } catch (_) {
      await File(tmpPath).copy(finalPath);
      try {
        await File(tmpPath).delete();
      } catch (_) {}
    }

    return finalPath;
  }

  Future<void> _registerMbtiles(String slug, String path) async {
    try {
      final mapsDir = await _ensureMapsDir();
      final indexFile = File(p.join(mapsDir.path, 'maps_index.json'));
      Map<String, dynamic> index = {};
      if (await indexFile.exists()) {
        try {
          final content = await indexFile.readAsString();
          if (content.trim().isNotEmpty)
            index = json.decode(content) as Map<String, dynamic>;
        } catch (_) {
          index = {};
        }
      }
      index[slug] = path;
      await indexFile.writeAsString(json.encode(index), flush: true);
    } catch (e) {
      print('Error registrando MBTiles: $e');
    }
  }

  Future<void> _handleDownload(String departamento) async {
    final url = urls[departamento];
    if (url == null) return;

    final progressCtrl = StreamController<Map<String, int>>();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Descargando...'),
        content: SizedBox(
          height: 80,
          child: StreamBuilder<Map<String, int>>(
            stream: progressCtrl.stream,
            builder: (ctx, snap) {
              final received = snap.data?['r'] ?? 0;
              final total = snap.data?['t'] ?? 0;
              final percent = (total > 0) ? (received / total) : null;
              final receivedMb = (received / 1024 / 1024);
              final totalMb = (total / 1024 / 1024);
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${receivedMb.toStringAsFixed(2)} MB de ${total > 0 ? totalMb.toStringAsFixed(2) : '--'} MB',
                  ),
                  const SizedBox(height: 12),
                  LinearProgressIndicator(value: percent),
                ],
              );
            },
          ),
        ),
      ),
    );

    try {
      final mbPath = await _mbtilesPathFor(departamento);
      final f = File(mbPath);
      bool proceed = true;
      if (await f.exists()) {
        final answer = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Re-descargar'),
            content: const Text(
              'Ya existe un MBTiles descargado. ¿Deseas reemplazarlo?',
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

      if (!proceed) {
        if (mounted) Navigator.of(context).pop();
        return;
      }

      try {
        if (await f.exists()) await f.delete();
      } catch (_) {}

      try {
        final guessedMbUrl = url.endsWith('.zip')
            ? url.replaceAllMapped(RegExp(r'\.zip\$'), (m) => '.mbtiles')
            : url;
        final savedPath = await _downloadAndSaveMbtiles(
          guessedMbUrl,
          departamento,
          (r, t) {
            try {
              progressCtrl.add({'r': r, 't': t});
            } catch (_) {}
          },
        );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Descargado: ${p.basename(savedPath)}')),
        );
        setState(() {});
      } finally {
        try {
          if (!progressCtrl.isClosed) await progressCtrl.close();
        } catch (_) {}
        if (mounted) Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) Navigator.of(context).pop();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _handleExtract(String departamento) async {
    // In the new flow 'Extraer' will attempt to register existing MBTiles or download it raw
    try {
      final mapsDir = await _ensureMapsDir();
      final slug = _slug(departamento);
      final mbPath = p.join(mapsDir.path, '$slug.mbtiles');

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => const AlertDialog(
          title: Text('Obteniendo MBTiles...'),
          content: SizedBox(
            height: 60,
            child: Center(child: CircularProgressIndicator()),
          ),
        ),
      );

      if (await File(mbPath).exists()) {
        await _registerMbtiles(slug, mbPath);
        if (mounted) Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('MBTiles registrado (local)')),
        );
        setState(() {});
        return;
      }

      final url = urls[departamento];
      if (url != null) {
        final guessedMbUrl = url.endsWith('.zip')
            ? url.replaceAllMapped(RegExp(r'\.zip\$'), (m) => '.mbtiles')
            : url;
        try {
          await _downloadAndSaveMbtiles(guessedMbUrl, departamento, (r, t) {});
          await _registerMbtiles(slug, mbPath);
          if (mounted) Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('MBTiles descargado y registrado')),
          );
          setState(() {});
          return;
        } catch (e) {
          print('Error descargando MBTiles: $e');
        }
      }

      if (mounted) Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No se encontró MBTiles local ni fue posible descargarlo',
          ),
        ),
      );
    } catch (e) {
      if (mounted) Navigator.of(context).pop();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _handleImport(String departamento) async {
    try {
      final res = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['zip', 'mbtiles'],
      );
      if (res == null || res.files.isEmpty) return;
      final picked = res.files.first;
      if (picked.path == null) return;
      final src = File(picked.path!);
      final mapsDir = await _ensureMapsDir();
      final slug = _slug(departamento);
      if ((picked.extension ?? '').toLowerCase() == 'mbtiles') {
        final dest = File(p.join(mapsDir.path, '$slug.mbtiles'));
        await src.copy(dest.path);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('MBTiles importado')));
      } else {
        final dest = File(p.join(mapsDir.path, '$slug.zip'));
        await src.copy(dest.path);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('ZIP importado')));
      }
      setState(() {});
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error importando: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Descargas - Mapas Offline'),
        backgroundColor: const Color(0xFF141A2F),
      ),
      body: ListView.separated(
        itemCount: departamentos.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final d = departamentos[index];
          final hasUrl = urls.containsKey(d);
          return FutureBuilder<bool>(
            future: _isMbtilesDownloaded(d),
            builder: (context, snapZip) {
              final downloaded = snapZip.data ?? false;
              return ListTile(
                title: Text(d),
                subtitle: Text(
                  downloaded ? 'Estado: descargado' : 'Estado: no descargado',
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Importar ZIP/MBTiles',
                      icon: const Icon(Icons.folder_open),
                      color: const Color(0xFF90A4AE),
                      onPressed: () => _handleImport(d),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      tooltip: downloaded ? 'Volver a descargar' : 'Descargar',
                      icon: const Icon(Icons.download),
                      color: const Color(0xFFD6B68A),
                      onPressed: hasUrl ? () => _handleDownload(d) : null,
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      tooltip: 'Extraer',
                      icon: const Icon(Icons.unarchive),
                      color: const Color(0xFFD6B68A),
                      onPressed: () => _handleExtract(d),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

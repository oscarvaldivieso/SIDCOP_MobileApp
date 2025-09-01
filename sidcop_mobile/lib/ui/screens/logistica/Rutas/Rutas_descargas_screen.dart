import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'dart:convert';
import 'dart:async';

class RutasDescargasScreen extends StatefulWidget {
  const RutasDescargasScreen({Key? key}) : super(key: key);

  @override
  State<RutasDescargasScreen> createState() => _RutasDescargasScreenState();
}

class _RutasDescargasScreenState extends State<RutasDescargasScreen> {
  final List<String> departamentos = const ['Honduras'];

  final Map<String, String> urls = {
    'Honduras':
        'http://200.59.27.115/Honduras_map/mapa_honduras_2025-08-27_180657.mbtiles',
  };

  Future<Directory> _Mapdir() async {
    final dir = await getApplicationDocumentsDirectory();
    final mapsDir = Directory(p.join(dir.path, 'maps'));
    if (!await mapsDir.exists()) await mapsDir.create(recursive: true);
    return mapsDir;
  }

  Future<String> _mbtilesPathFor(String departamento) async {
    final mapsDir = await _Mapdir();

    return p.join(mapsDir.path, 'honduras.mbtiles');
  }

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

  Future<String> _downloadAndSaveMbtiles(
    String url,
    String departamento,
    void Function(int, int) onProgress,
  ) async {
    final mapsDir = await _Mapdir();

    final finalPath = p.join(mapsDir.path, 'honduras.mbtiles');
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

      if (!proceed) {
        if (mounted) Navigator.of(context).pop();
        return;
      }

      try {
        final savedPath = await _downloadAndSaveMbtiles(url, departamento, (
          r,
          t,
        ) {
          try {
            progressCtrl.add({'r': r, 't': t});
          } catch (_) {}
        });
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Descargas - Mapas Offline'),
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

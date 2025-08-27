import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;
import 'dart:math' as math;

class RutasDescargasScreen extends StatefulWidget {
  const RutasDescargasScreen({Key? key}) : super(key: key);

  @override
  State<RutasDescargasScreen> createState() => _RutasDescargasScreenState();
}

class _RutasDescargasScreenState extends State<RutasDescargasScreen> {
  final List<String> departamentos = const [
    'Atlántida',
    'Choluteca',
    'Colón',
    'Comayagua',
    'Copán',
    'Cortés',
    'El Paraíso',
    'Francisco Morazán',
    'Gracias a Dios',
    'Intibucá',
    'La Paz',
    'Lempira',
    'Ocotepeque',
    'Olancho',
    'Santa Bárbara',
    'Valle',
    'Yoro',
  ];

  // Mapa de URLs por departamento (solo Atlántida configurada por ahora)
  final Map<String, String> urls = {
    'Atlántida': 'http://200.59.27.115/Honduras_map/atlantida.zip',
  };

  String _slug(String departamento) {
    return departamento
        .toLowerCase()
        .replaceAll(' ', '_')
        .replaceAll('á', 'a')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('é', 'e')
        .replaceAll('ú', 'u')
        .replaceAll('ñ', 'n');
  }

  // Descarga con reporte de progreso (bytes recibidos, total bytes).
  Future<String> _downloadAndSaveZip(
    String url,
    String departamento,
    void Function(int received, int total) onProgress,
  ) async {
    final dir = await getApplicationDocumentsDirectory();
    final mapsDir = Directory(p.join(dir.path, 'maps'));
    if (!await mapsDir.exists()) await mapsDir.create(recursive: true);

    final slug = _slug(departamento);
    final zipPath = p.join(mapsDir.path, '$slug.zip');

    final client = http.Client();
    final request = http.Request('GET', Uri.parse(url));
    final streamedResponse = await client.send(request);
    if (streamedResponse.statusCode != 200) {
      client.close();
      throw Exception('Error descargando zip: ${streamedResponse.statusCode}');
    }

    final contentLength = streamedResponse.contentLength ?? 0;
    final file = File(zipPath).openWrite();
    int received = 0;

    await for (final chunk in streamedResponse.stream) {
      file.add(chunk);
      received += chunk.length;
      try {
        onProgress(received, contentLength);
      } catch (_) {}
    }

    await file.close();
    client.close();
    return zipPath;
  }

  // Extrae el zip y reporta progreso (items procesados, total items).
  Future<void> _extractZipToFolder(
    String zipPath,
    void Function(int processed, int total) onProgress,
  ) async {
    final bytes = await File(zipPath).readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);
    final destDir = Directory(
      p.join(p.dirname(zipPath), p.basenameWithoutExtension(zipPath)),
    );
    if (!await destDir.exists()) await destDir.create(recursive: true);

    final total = archive.length;
    int processed = 0;

    for (final file in archive) {
      final outPath = p.join(destDir.path, file.name);
      if (file.isFile) {
        final outFile = File(outPath);
        await outFile.create(recursive: true);
        await outFile.writeAsBytes(file.content as List<int>);
      } else {
        await Directory(outPath).create(recursive: true);
      }
      processed++;
      try {
        onProgress(processed, total);
      } catch (_) {}
    }
    // Crear un archivo sentinel que indique que la descarga y extracción se completaron
    try {
      final sentinel = File(p.join(destDir.path, '.download_complete'));
      await sentinel.writeAsString(DateTime.now().toIso8601String());
    } catch (_) {
      // ignorar errores al escribir sentinel
    }
  }

  Future<void> _handleDownload(String departamento) async {
    final url = urls[departamento];
    if (url == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No hay URL configurada para $departamento')),
      );
      return;
    }
    // Variables para el diálogo de progreso
    int received = 0;
    int totalBytes = 0;
    int processed = 0;
    int totalItems = 0;
    String status = 'Iniciando...';

    late void Function(int, int, String) updateDialog;

    // Mostrar diálogo con StatefulBuilder para actualizar progreso
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            updateDialog = (r, t, s) {
              try {
                setState(() {
                  received = r;
                  totalBytes = t;
                  status = s;
                });
              } catch (_) {}
            };

            double progress = 0.0;
            if (totalBytes > 0) progress = received / totalBytes;

            double extractProgress = 0.0;
            if (totalItems > 0) extractProgress = processed / totalItems;

            return AlertDialog(
              title: Text(status),
              content: SizedBox(
                width: 320,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (status.toLowerCase().contains('descarg')) ...[
                      LinearProgressIndicator(value: progress),
                      const SizedBox(height: 8),
                      Text(
                        totalBytes > 0
                            ? '${(progress * 100).toStringAsFixed(0)}% - ${_formatBytes(received)}/${_formatBytes(totalBytes)}'
                            : '${_formatBytes(received)} - descargando...',
                      ),
                    ],
                    if (status.toLowerCase().contains('descompr') ||
                        status.toLowerCase().contains('extra')) ...[
                      LinearProgressIndicator(value: extractProgress),
                      const SizedBox(height: 8),
                      Text(
                        totalItems > 0
                            ? '${(extractProgress * 100).toStringAsFixed(0)}% - $processed/$totalItems archivos'
                            : 'Descomprimiendo...',
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    try {
      // Empezar descarga con callback que actualiza el diálogo
      final zipPath = await _downloadAndSaveZip(url, departamento, (r, t) {
        // r: bytes recibidos, t: total bytes
        if (mounted) updateDialog(r, t, 'Descargando...');
      });

      // Extraer con callback que actualiza el diálogo
      await _extractZipToFolder(zipPath, (proc, tot) {
        // proc: items procesados, tot: total items
        processed = proc;
        totalItems = tot;
        if (mounted) updateDialog(received, totalBytes, 'Descomprimiendo...');
      });

      // Cerrar diálogo
      if (mounted) Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Descargado y extraído: ${p.basenameWithoutExtension(zipPath)}',
          ),
        ),
      );
    } catch (e) {
      if (mounted) Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error descargando $departamento: $e')),
      );
    }
  }

  String _formatBytes(int bytes, [int decimals = 1]) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
    var i = (math.log(bytes) / math.log(1024)).floor();
    final value = bytes / math.pow(1024, i);
    return '${value.toStringAsFixed(decimals)} ${suffixes[i]}';
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
          return ListTile(
            title: Text(d),
            trailing: IconButton(
              icon: Icon(hasUrl ? Icons.download : Icons.download_for_offline),
              color: hasUrl ? const Color(0xFFD6B68A) : Colors.grey,
              onPressed: hasUrl ? () => _handleDownload(d) : null,
            ),
            onTap: () => ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text('Seleccionado: $d'))),
          );
        },
      ),
    );
  }
}

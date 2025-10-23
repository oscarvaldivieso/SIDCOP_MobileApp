import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:flutter_background/flutter_background.dart';

class DownloadService {
  DownloadService._private();
  static final DownloadService instance = DownloadService._private();

  final Map<String, StreamController<Map<String, int>>> _controllers = {};
  int _activeDownloads = 0;

  Stream<Map<String, int>> progressStream(String id) {
    return _controllers[id]?.stream ?? const Stream.empty();
  }

  Future<String> _mapsDir() async {
    final dir = await getApplicationDocumentsDirectory();
    final mapsDir = Directory(p.join(dir.path, 'maps'));
    if (!await mapsDir.exists()) await mapsDir.create(recursive: true);
    return mapsDir.path;
  }

  Future<void> _ensureBackground() async {
    final androidConfig = FlutterBackgroundAndroidConfig(
      notificationTitle: 'Descarga en progreso',
      notificationText: 'La descarga continuará en segundo plano.',
      notificationImportance: AndroidNotificationImportance.high,
      enableWifiLock: true,
    );
    final ok = await FlutterBackground.initialize(androidConfig: androidConfig);
    if (ok) {
      await FlutterBackground.enableBackgroundExecution();
    }
  }

  Future<void> _maybeDisableBackground() async {
    _activeDownloads = (_activeDownloads - 1).clamp(0, 9999);
    if (_activeDownloads == 0) {
      try {
        await FlutterBackground.disableBackgroundExecution();
      } catch (_) {}
    }
  }


  Future<String> startDownload({
    required String id,
    required String url,
    String? filename,
  }) async {
    if (_controllers.containsKey(id)) {
      throw StateError('Ya existe una descarga en curso');
    }
  final controller = StreamController<Map<String, int>>.broadcast();
    _controllers[id] = controller;
    _activeDownloads += 1;
    await _ensureBackground();

    final mapsPath = await _mapsDir();
    final finalName = filename ?? p.basename(Uri.parse(url).path);
    final finalPath = p.join(mapsPath, finalName);
    final tmpPath = '$finalPath.tmp';

    final completer = Completer<String>();

    // correr descargar aun así se salga del componente.
    () async {
      final client = http.Client();
      try {
        final req = http.Request('GET', Uri.parse(url));
        final resp = await client.send(req);
        if (resp.statusCode != 200) {
          throw Exception('HTTP ${resp.statusCode}');
        }
        final total = resp.contentLength ?? 0;
        final sink = File(tmpPath).openWrite();
        int received = 0;
        await for (final chunk in resp.stream) {
          sink.add(chunk);
          received += chunk.length;
          try {
            controller.add({'r': received, 't': total});
          } catch (_) {}
        }
        await sink.close();
        try {
          await File(tmpPath).rename(finalPath);
        } catch (_) {
          await File(tmpPath).copy(finalPath);
          try {
            await File(tmpPath).delete();
          } catch (_) {}
        }
        if (!completer.isCompleted) completer.complete(finalPath);
      } catch (e, st) {
        if (!completer.isCompleted) completer.completeError(e, st);
        try {
          controller.add({'r': -1, 't': -1});
        } catch (_) {}
      } finally {
        client.close();
        try {
          await controller.close();
        } catch (_) {}
        _controllers.remove(id);
        await _maybeDisableBackground();
      }
    }();

    return completer.future;
  }

  bool isDownloading(String id) => _controllers.containsKey(id);
}

import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sidcop_mobile/models/ClientesViewModel.Dart';
import 'package:sidcop_mobile/services/CacheService.dart';
import 'package:sidcop_mobile/services/OfflineDatabaseService.dart';

/// Servicio especializado para el caché de imágenes de clientes usando cached_network_image
class ClientImageCacheService {
  static final ClientImageCacheService _instance =
      ClientImageCacheService._internal();
  factory ClientImageCacheService() => _instance;
  ClientImageCacheService._internal();

  bool _isCaching = false;
  int _totalImages = 0;
  int _cachedImages = 0;
  Map<String, String> _imageUrlToIdMap = {};

  /// Cachea todas las imágenes de clientes para visualización offline
  Future<bool> cacheAllClientImages(List<Cliente> clients) async {
    if (_isCaching) {
      return false;
    }

    _isCaching = true;
    _totalImages = 0;
    _cachedImages = 0;
    _imageUrlToIdMap.clear();

    try {
      // Filtrar clientes con imágenes válidas
      final clientsWithImages = clients
          .where(
            (client) =>
                client.clie_ImagenDelNegocio != null &&
                client.clie_ImagenDelNegocio!.isNotEmpty &&
                client.clie_ImagenDelNegocio!.startsWith('http'),
          )
          .toList();

      _totalImages = clientsWithImages.length;

      if (_totalImages == 0) {
        return true;
      }

      // Procesar en lotes de 5 para no sobrecargar
      const batchSize = 5;
      for (int i = 0; i < clientsWithImages.length; i += batchSize) {
        final end = (i + batchSize < clientsWithImages.length)
            ? i + batchSize
            : clientsWithImages.length;
        final batch = clientsWithImages.sublist(i, end);

        await _cacheBatchImages(batch, i + 1);

        // Pausa entre lotes
        await Future.delayed(Duration(milliseconds: 200));
      }

      // Guardar mapeo de imágenes en caché
      await _saveImageMapping();

      return true;
    } catch (e) {
      return false;
    } finally {
      _isCaching = false;
    }
  }

  /// Cachea un lote de imágenes
  Future<void> _cacheBatchImages(List<Cliente> batch, int startIndex) async {
    final futures = batch.asMap().entries.map((entry) async {
      final client = entry.value;

      try {
        // Solo log para debug si es necesario
        // print('ClientImageCacheService: Cacheando imagen - ${client.clie_NombreNegocio}');
        // Usar CachedNetworkImageProvider para forzar el caché
        final imageProvider = CachedNetworkImageProvider(
          client.clie_ImagenDelNegocio!,
          cacheKey: 'client_${client.clie_Id}',
        );

        // Resolver la imagen para forzar la descarga y caché
        final imageStream = imageProvider.resolve(const ImageConfiguration());
        final completer = Completer<void>();

        late ImageStreamListener listener;
        listener = ImageStreamListener(
          (ImageInfo info, bool synchronousCall) {
            // Imagen cargada exitosamente
            _imageUrlToIdMap[client.clie_ImagenDelNegocio!] = client.clie_Id
                .toString();
            _cachedImages++;
            // Solo log para debug si es necesario
            // print('ClientImageCacheService: Imagen ${globalIndex} cacheada - ${client.clie_NombreNegocio}');
            imageStream.removeListener(listener);
            completer.complete();
          },
          onError: (exception, stackTrace) {
            // Solo log de errores
            // print('ClientImageCacheService: Error cacheando imagen ${globalIndex} - ${client.clie_NombreNegocio}: $exception');
            imageStream.removeListener(listener);
            completer
                .complete(); // Completar aunque haya error para no bloquear
          },
        );

        imageStream.addListener(listener);

        // Timeout de 15 segundos por imagen
        await completer.future.timeout(
          Duration(seconds: 15),
          onTimeout: () {
            // Solo log de timeouts
            // print('ClientImageCacheService: Timeout para imagen ${globalIndex} - ${client.clie_NombreNegocio}');
            imageStream.removeListener(listener);
          },
        );
      } catch (e) {
        // Solo log de errores críticos
        // print('ClientImageCacheService: Error procesando imagen ${globalIndex} - ${client.clie_NombreNegocio}: $e');
      }
    });

    await Future.wait(futures);
  }

  /// Guarda el mapeo de imágenes en caché y SQLite cifrado
  Future<void> _saveImageMapping() async {
    try {
      // Guardar en caché rápido
      await CacheService.cacheClientImagesData(_imageUrlToIdMap);

      // Guardar en SQLite cifrado para persistencia offline
      final csvData = _imageUrlToIdMap.entries
          .map((entry) => '${entry.key},${entry.value}')
          .toList();

      await OfflineDatabaseService.saveData('client_images_mapping', csvData);
    } catch (e) {
      // Silencioso
    }
  }

  /// Obtiene el widget de imagen con caché para un cliente
  Widget getCachedClientImage({
    required String? imageUrl,
    required String clientId,
    double? width,
    double? height,
    BoxFit fit = BoxFit.cover,
    Widget? placeholder,
    Widget? errorWidget,
  }) {
    if (imageUrl == null || imageUrl.isEmpty) {
      return errorWidget ?? Icon(Icons.business, size: 50);
    }

    return CachedNetworkImage(
      imageUrl: imageUrl,
      cacheKey: 'client_$clientId',
      width: width,
      height: height,
      fit: fit,
      placeholder: (context, url) =>
          placeholder ??
          Container(
            width: width,
            height: height,
            child: Center(
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
              ),
            ),
          ),
      errorWidget: (context, url, error) =>
          errorWidget ??
          Container(
            width: width,
            height: height,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.business_outlined, color: Colors.grey, size: 30),
                SizedBox(height: 4),
                Text(
                  'Error al cargar imagen',
                  style: TextStyle(fontSize: 10, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
      // Configuraciones para mejor caché offline
      fadeInDuration: Duration(milliseconds: 300),
      fadeOutDuration: Duration(milliseconds: 100),
      useOldImageOnUrlChange: true,
      memCacheWidth: width?.toInt(),
      memCacheHeight: height?.toInt(),
    );
  }

  /// Verifica si una imagen está en caché
  Future<bool> isImageCached(String imageUrl, String clientId) async {
    try {
      final cacheManager = DefaultCacheManager();
      final fileInfo = await cacheManager.getFileFromCache('client_$clientId');
      return fileInfo != null && fileInfo.file.existsSync();
    } catch (e) {
      return false;
    }
  }

  /// Limpia el caché de imágenes
  Future<void> clearImageCache() async {
    try {
      // Limpiar caché de CachedNetworkImage
      await DefaultCacheManager().emptyCache();

      // Limpiar mapeo en caché rápido
      await CacheService.clearClientImagesCache();

      // Limpiar SQLite cifrado
      await OfflineDatabaseService.clearData('client_images_mapping');

      _imageUrlToIdMap.clear();
      _cachedImages = 0;
      _totalImages = 0;
    } catch (e) {
      // Silencioso
    }
  }

  /// Obtiene información del caché
  Future<Map<String, dynamic>> getCacheInfo() async {
    try {
      final cacheSize = await _calculateCacheSize();

      return {
        'isCaching': _isCaching,
        'totalImages': _totalImages,
        'cachedImages': _cachedImages,
        'cacheSizeMB': cacheSize,
        'mappingCount': _imageUrlToIdMap.length,
      };
    } catch (e) {
      return {
        'isCaching': _isCaching,
        'totalImages': _totalImages,
        'cachedImages': _cachedImages,
        'cacheSizeMB': 0.0,
        'mappingCount': _imageUrlToIdMap.length,
        'error': e.toString(),
      };
    }
  }

  /// Calcula el tamaño del caché en MB
  Future<double> _calculateCacheSize() async {
    try {
      final cacheDir = await getTemporaryDirectory();

      if (!cacheDir.existsSync()) return 0.0;

      int totalSize = 0;
      await for (final entity in cacheDir.list(recursive: true)) {
        if (entity is File) {
          totalSize += await entity.length();
        }
      }

      return totalSize / (1024 * 1024); // Convertir a MB
    } catch (e) {
      return 0.0;
    }
  }

  /// Precarga una imagen específica
  Future<bool> precacheClientImage(String imageUrl, String clientId) async {
    try {
      final imageProvider = CachedNetworkImageProvider(
        imageUrl,
        cacheKey: 'client_$clientId',
      );

      final imageStream = imageProvider.resolve(const ImageConfiguration());
      final completer = Completer<bool>();

      late ImageStreamListener listener;
      listener = ImageStreamListener(
        (ImageInfo info, bool synchronousCall) {
          imageStream.removeListener(listener);
          completer.complete(true);
        },
        onError: (exception, stackTrace) {
          imageStream.removeListener(listener);
          completer.complete(false);
        },
      );

      imageStream.addListener(listener);

      return await completer.future.timeout(
        Duration(seconds: 10),
        onTimeout: () {
          imageStream.removeListener(listener);
          return false;
        },
      );
    } catch (e) {
      return false;
    }
  }

  // Getters para estado
  bool get isCaching => _isCaching;
  int get totalImages => _totalImages;
  int get cachedImages => _cachedImages;
  Map<String, String> get imageMapping => Map.unmodifiable(_imageUrlToIdMap);
}

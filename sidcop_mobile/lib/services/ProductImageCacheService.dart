import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sidcop_mobile/models/ProductosViewModel.dart';
import 'package:sidcop_mobile/services/CacheService.dart';
import 'package:sidcop_mobile/services/OfflineDatabaseService.dart';

/// Servicio especializado para el caché de imágenes de productos usando cached_network_image
class ProductImageCacheService {
  static final ProductImageCacheService _instance =
      ProductImageCacheService._internal();
  factory ProductImageCacheService() => _instance;
  ProductImageCacheService._internal();

  // Note: CacheService and OfflineDatabaseService methods are static
  // No need to create instances

  bool _isCaching = false;
  int _totalImages = 0;
  int _cachedImages = 0;
  Map<String, String> _imageUrlToIdMap = {};

  /// Cachea todas las imágenes de productos para visualización offline
  Future<bool> cacheAllProductImages(List<Productos> products) async {
    if (_isCaching) {
      developer.log(
        '🔄 ProductImageCacheService: Ya hay un proceso de caché en curso',
      );
      return false;
    }

    _isCaching = true;
    _totalImages = 0;
    _cachedImages = 0;
    _imageUrlToIdMap.clear();

    try {
      developer.log(
        '🖼️ ProductImageCacheService: Iniciando caché de imágenes de productos',
      );

      // Filtrar productos con imágenes válidas
      final productsWithImages = products
          .where(
            (product) =>
                product.prod_Imagen != null &&
                product.prod_Imagen!.isNotEmpty &&
                product.prod_Imagen!.startsWith('http'),
          )
          .toList();

      _totalImages = productsWithImages.length;
      developer.log(
        '📊 ProductImageCacheService: ${_totalImages} imágenes para cachear',
      );

      if (_totalImages == 0) {
        developer.log(
          '⚠️ ProductImageCacheService: No hay imágenes válidas para cachear',
        );
        return true;
      }

      // Procesar en lotes de 5 para no sobrecargar
      const batchSize = 5;
      for (int i = 0; i < productsWithImages.length; i += batchSize) {
        final end = (i + batchSize < productsWithImages.length)
            ? i + batchSize
            : productsWithImages.length;
        final batch = productsWithImages.sublist(i, end);

        await _cacheBatchImages(batch, i + 1);

        // Pausa entre lotes
        await Future.delayed(Duration(milliseconds: 200));
      }

      // Guardar mapeo de imágenes en caché
      await _saveImageMapping();

      developer.log(
        '🎉 ProductImageCacheService: Caché completado - ${_cachedImages}/${_totalImages} imágenes',
      );
      return true;
    } catch (e) {
      developer.log(
        '❌ ProductImageCacheService: Error en caché de imágenes: $e',
      );
      return false;
    } finally {
      _isCaching = false;
    }
  }

  /// Cachea un lote de imágenes
  Future<void> _cacheBatchImages(List<Productos> batch, int startIndex) async {
    final futures = batch.asMap().entries.map((entry) async {
      final index = entry.key;
      final product = entry.value;
      final globalIndex = startIndex + index;

      try {
        developer.log(
          '🔄 ProductImageCacheService: Cacheando imagen ${globalIndex}/${_totalImages} - ${product.prod_Descripcion}',
        );

        // Usar CachedNetworkImageProvider para forzar el caché
        final imageProvider = CachedNetworkImageProvider(
          product.prod_Imagen!,
          cacheKey: 'product_${product.prod_Id}',
        );

        // Resolver la imagen para forzar la descarga y caché
        final imageStream = imageProvider.resolve(const ImageConfiguration());
        final completer = Completer<void>();

        late ImageStreamListener listener;
        listener = ImageStreamListener(
          (ImageInfo info, bool synchronousCall) {
            // Imagen cargada exitosamente
            _imageUrlToIdMap[product.prod_Imagen!] = product.prod_Id.toString();
            _cachedImages++;
            developer.log(
              '✅ ProductImageCacheService: Imagen ${globalIndex} cacheada - ${product.prod_Descripcion}',
            );
            imageStream.removeListener(listener);
            completer.complete();
          },
          onError: (exception, stackTrace) {
            developer.log(
              '❌ ProductImageCacheService: Error cacheando imagen ${globalIndex} - ${product.prod_Descripcion}: $exception',
            );
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
            developer.log(
              '⏰ ProductImageCacheService: Timeout para imagen ${globalIndex} - ${product.prod_Descripcion}',
            );
            imageStream.removeListener(listener);
          },
        );
      } catch (e) {
        developer.log(
          '❌ ProductImageCacheService: Error procesando imagen ${globalIndex} - ${product.prod_Descripcion}: $e',
        );
      }
    });

    await Future.wait(futures);
    developer.log(
      '📦 ProductImageCacheService: Lote completado - ${_cachedImages}/${_totalImages} imágenes cacheadas',
    );
  }

  /// Guarda el mapeo de imágenes en caché y CSV cifrado
  Future<void> _saveImageMapping() async {
    try {
      // Guardar en caché rápido
      await CacheService.cacheProductImagesData(_imageUrlToIdMap);

      // Guardar en CSV cifrado para persistencia offline
      final csvData = _imageUrlToIdMap.entries
          .map((entry) => '${entry.key},${entry.value}')
          .toList();

      await OfflineDatabaseService.saveData('product_images_mapping', csvData);

      developer.log(
        '💾 ProductImageCacheService: Mapeo de imágenes guardado en caché y CSV cifrado',
      );
    } catch (e) {
      developer.log('❌ ProductImageCacheService: Error guardando mapeo: $e');
    }
  }

  /// Obtiene el widget de imagen con caché para un producto
  Widget getCachedProductImage({
    required String? imageUrl,
    required String productId,
    double? width,
    double? height,
    BoxFit fit = BoxFit.cover,
    Widget? placeholder,
    Widget? errorWidget,
  }) {
    if (imageUrl == null || imageUrl.isEmpty) {
      return errorWidget ?? Icon(Icons.image_not_supported, size: 50);
    }

    return CachedNetworkImage(
      imageUrl: imageUrl,
      cacheKey: 'product_$productId',
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
                Icon(Icons.error_outline, color: Colors.grey, size: 30),
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
  Future<bool> isImageCached(String imageUrl, String productId) async {
    try {
      final cacheManager = DefaultCacheManager();
      final fileInfo = await cacheManager.getFileFromCache(
        'product_$productId',
      );
      return fileInfo != null && fileInfo.file.existsSync();
    } catch (e) {
      developer.log('❌ ProductImageCacheService: Error verificando caché: $e');
      return false;
    }
  }

  /// Limpia el caché de imágenes
  Future<void> clearImageCache() async {
    try {
      developer.log('🧹 ProductImageCacheService: Limpiando caché de imágenes');

      // Limpiar caché de CachedNetworkImage
      await DefaultCacheManager().emptyCache();

      // Limpiar mapeo en caché rápido
      await CacheService.clearProductImagesCache();

      // Limpiar SQLite cifrado
      await OfflineDatabaseService.clearData('product_images_mapping');

      _imageUrlToIdMap.clear();
      _cachedImages = 0;
      _totalImages = 0;

      developer.log('✅ ProductImageCacheService: Caché de imágenes limpiado');
    } catch (e) {
      developer.log('❌ ProductImageCacheService: Error limpiando caché: $e');
    }
  }

  /// Obtiene información del caché
  Future<Map<String, dynamic>> getCacheInfo() async {
    try {
      final cacheManager = DefaultCacheManager();
      final cacheSize = await _calculateCacheSize();

      return {
        'isCaching': _isCaching,
        'totalImages': _totalImages,
        'cachedImages': _cachedImages,
        'cacheSizeMB': cacheSize,
        'mappingCount': _imageUrlToIdMap.length,
      };
    } catch (e) {
      developer.log(
        '❌ ProductImageCacheService: Error obteniendo info de caché: $e',
      );
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
      final cacheManager = DefaultCacheManager();
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
      developer.log(
        '❌ ProductImageCacheService: Error calculando tamaño de caché: $e',
      );
      return 0.0;
    }
  }

  /// Precarga una imagen específica
  Future<bool> precacheProductImage(String imageUrl, String productId) async {
    try {
      final imageProvider = CachedNetworkImageProvider(
        imageUrl,
        cacheKey: 'product_$productId',
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
      developer.log('❌ ProductImageCacheService: Error precargando imagen: $e');
      return false;
    }
  }

  // Getters para estado
  bool get isCaching => _isCaching;
  int get totalImages => _totalImages;
  int get cachedImages => _cachedImages;
  Map<String, String> get imageMapping => Map.unmodifiable(_imageUrlToIdMap);
}

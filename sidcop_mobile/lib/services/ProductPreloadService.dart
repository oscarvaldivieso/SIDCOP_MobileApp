import 'dart:async';
import 'dart:developer' as developer;
import 'dart:ui' as ui;
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:sidcop_mobile/models/ProductosViewModel.dart';
import 'package:sidcop_mobile/services/SyncService.dart';
import 'package:sidcop_mobile/services/CacheService.dart';

/// Servicio para precargar productos e imágenes sin necesidad de abrir la pantalla
class ProductPreloadService {
  static bool _isPreloading = false;
  static bool _isPreloaded = false;
  static List<Productos> _preloadedProducts = [];
  
  /// Precarga todos los productos y sus imágenes
  static Future<bool> preloadProductsAndImages() async {
    if (_isPreloading || _isPreloaded) {
      developer.log('Precarga ya en progreso o completada');
      return _isPreloaded;
    }

    _isPreloading = true;
    developer.log('Iniciando precarga de productos e imágenes...');

    try {
      // PASO 1: Precargar datos de productos
      await _preloadProductData();
      
      // PASO 2: Precargar imágenes de productos
      await _preloadProductImages();
      
      _isPreloaded = true;
      developer.log('Precarga completada exitosamente. ${_preloadedProducts.length} productos precargados');
      return true;
      
    } catch (e) {
      developer.log('Error durante la precarga: $e');
      return false;
    } finally {
      _isPreloading = false;
    }
  }

  /// Precarga los datos de productos desde el servidor o caché
  static Future<void> _preloadProductData() async {
    try {
      developer.log('Precargando datos de productos...');
      
      // Usar SyncService para obtener productos (maneja offline/online automáticamente)
      final productsData = await SyncService.getProducts();
      
      // Convertir a objetos Productos
      _preloadedProducts = productsData.map((productMap) => 
        Productos.fromJson(productMap)
      ).toList();
      
      developer.log('Datos de productos precargados: ${_preloadedProducts.length} productos');
      
    } catch (e) {
      developer.log('Error precargando datos de productos: $e');
      rethrow;
    }
  }

  /// Precarga las imágenes de productos usando CachedNetworkImage
  static Future<void> _preloadProductImages() async {
    if (_preloadedProducts.isEmpty) {
      developer.log('No hay productos para precargar imágenes');
      return;
    }

    developer.log('Precargando imágenes de productos...');
    
    int imagesPreloaded = 0;
    int imagesSkipped = 0;
    
    // Procesar imágenes en lotes para evitar sobrecarga
    const int batchSize = 10;
    
    for (int i = 0; i < _preloadedProducts.length; i += batchSize) {
      final batch = _preloadedProducts.skip(i).take(batchSize).toList();
      
      // Procesar lote actual
      final futures = batch.map((product) => _preloadSingleImage(product));
      final results = await Future.wait(futures);
      
      // Contar resultados
      for (bool success in results) {
        if (success) {
          imagesPreloaded++;
        } else {
          imagesSkipped++;
        }
      }
      
      developer.log('Lote ${(i ~/ batchSize) + 1} completado. Imágenes precargadas: $imagesPreloaded, Omitidas: $imagesSkipped');
      
      // Pequeña pausa entre lotes para no sobrecargar
      await Future.delayed(const Duration(milliseconds: 100));
    }
    
    developer.log('Precarga de imágenes completada. Total precargadas: $imagesPreloaded, Total omitidas: $imagesSkipped');
  }

  /// Precarga una imagen individual usando método robusto
  static Future<bool> _preloadSingleImage(Productos product) async {
    try {
      final imageUrl = product.prod_Imagen;
      
      if (imageUrl == null || imageUrl.isEmpty) {
        return false; // No hay imagen que precargar
      }
      
      // Validar que la URL sea válida
      if (!_isValidImageUrl(imageUrl)) {
        developer.log('URL de imagen inválida para producto ${product.prod_Id}: $imageUrl');
        return false;
      }
      
      developer.log('Precargando imagen: $imageUrl');
      
      // Método 1: Intentar con precacheImage si hay contexto
      final context = NavigationService.navigatorKey.currentContext;
      if (context != null) {
        try {
          final imageProvider = CachedNetworkImageProvider(imageUrl);
          await precacheImage(imageProvider, context);
          developer.log('✅ Imagen precargada con contexto: ${product.prod_Id}');
          return true;
        } catch (e) {
          developer.log('⚠️ Error con precacheImage, intentando fallback: $e');
        }
      }
      
      // Método 2: Fallback - forzar descarga directa
      try {
        final imageProvider = CachedNetworkImageProvider(imageUrl);
        final completer = Completer<bool>();
        
        // Resolver la imagen para forzar la descarga
        final imageStream = imageProvider.resolve(const ImageConfiguration());
        
        late ImageStreamListener listener;
        listener = ImageStreamListener(
          (ImageInfo image, bool synchronousCall) {
            developer.log('✅ Imagen descargada exitosamente: ${product.prod_Id}');
            imageStream.removeListener(listener);
            if (!completer.isCompleted) completer.complete(true);
          },
          onError: (exception, stackTrace) {
            developer.log('❌ Error descargando imagen ${product.prod_Id}: $exception');
            imageStream.removeListener(listener);
            if (!completer.isCompleted) completer.complete(false);
          },
        );
        
        imageStream.addListener(listener);
        
        // Timeout de 10 segundos
        return await completer.future.timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            imageStream.removeListener(listener);
            developer.log('⏰ Timeout precargando imagen: ${product.prod_Id}');
            return false;
          },
        );
        
      } catch (e) {
        developer.log('❌ Error en fallback para imagen ${product.prod_Id}: $e');
        return false;
      }
      
    } catch (e) {
      developer.log('❌ Error general precargando imagen para producto ${product.prod_Id}: $e');
      return false;
    }
  }
  
  /// Valida si una URL de imagen es válida
  static bool _isValidImageUrl(String url) {
    if (url.isEmpty) return false;
    
    try {
      final uri = Uri.parse(url);
      return uri.hasScheme && (uri.scheme == 'http' || uri.scheme == 'https');
    } catch (e) {
      return false;
    }
  }

  /// Obtiene los productos precargados (evita nueva consulta al servidor)
  static List<Productos> getPreloadedProducts() {
    if (!_isPreloaded) {
      developer.log('Los productos no han sido precargados aún');
      return [];
    }
    
    return List.from(_preloadedProducts);
  }

  /// Verifica si la precarga está completa
  static bool isPreloaded() => _isPreloaded;

  /// Verifica si la precarga está en progreso
  static bool isPreloading() => _isPreloading;

  /// Limpia la precarga (útil para forzar una nueva precarga)
  static void clearPreload() {
    _isPreloaded = false;
    _isPreloading = false;
    _preloadedProducts.clear();
    developer.log('Precarga limpiada');
  }

  /// Obtiene información del estado de la precarga
  static Map<String, dynamic> getPreloadInfo() {
    return {
      'isPreloaded': _isPreloaded,
      'isPreloading': _isPreloading,
      'productsCount': _preloadedProducts.length,
      'imagesWithUrl': _preloadedProducts.where((p) => p.prod_Imagen?.isNotEmpty == true).length,
    };
  }

  /// Precarga en segundo plano (no bloquea la UI)
  static void preloadInBackground() {
    Future.microtask(() async {
      try {
        await preloadProductsAndImages();
      } catch (e) {
        developer.log('Error en precarga en segundo plano: $e');
      }
    });
  }

  /// MÉTODO OPTIMIZADO: Precarga productos e imágenes con descarga directa vía network
  /// Este método descarga directamente las imágenes y las almacena en caché local
  static Future<bool> preloadProductsWithDirectDownload() async {
    if (_isPreloading || _isPreloaded) {
      developer.log('Precarga ya en progreso o completada');
      return _isPreloaded;
    }

    _isPreloading = true;
    developer.log('Iniciando precarga optimizada con descarga directa...');

    try {
      // PASO 1: Precargar datos de productos
      await _preloadProductData();
      
      // PASO 2: Descargar imágenes directamente vía network
      await _downloadImagesDirectly();
      
      _isPreloaded = true;
      developer.log('✅ Precarga optimizada completada. ${_preloadedProducts.length} productos precargados');
      return true;
      
    } catch (e) {
      developer.log('❌ Error durante la precarga optimizada: $e');
      return false;
    } finally {
      _isPreloading = false;
    }
  }

  /// Descarga imágenes directamente vía HTTP y las almacena en caché local
  static Future<void> _downloadImagesDirectly() async {
    if (_preloadedProducts.isEmpty) {
      developer.log('No hay productos para descargar imágenes');
      return;
    }

    developer.log('📥 Descargando imágenes directamente vía network...');
    
    // Obtener directorio de caché
    final cacheDir = await _getCacheDirectory();
    
    int imagesDownloaded = 0;
    int imagesSkipped = 0;
    int imagesCached = 0;
    
    // Procesar imágenes en lotes para optimizar rendimiento
    const int batchSize = 5; // Reducido para evitar sobrecarga de red
    
    for (int i = 0; i < _preloadedProducts.length; i += batchSize) {
      final batch = _preloadedProducts.skip(i).take(batchSize).toList();
      
      // Procesar lote actual
      final futures = batch.map((product) => _downloadSingleImageDirect(product, cacheDir));
      final results = await Future.wait(futures);
      
      // Contar resultados
      for (String result in results) {
        switch (result) {
          case 'downloaded':
            imagesDownloaded++;
            break;
          case 'cached':
            imagesCached++;
            break;
          case 'skipped':
            imagesSkipped++;
            break;
        }
      }
      
      developer.log('📦 Lote ${(i ~/ batchSize) + 1} completado. Descargadas: $imagesDownloaded, En caché: $imagesCached, Omitidas: $imagesSkipped');
      
      // Pausa entre lotes para no sobrecargar la red
      await Future.delayed(const Duration(milliseconds: 200));
    }
    
    developer.log('🎯 Descarga directa completada. Total descargadas: $imagesDownloaded, Ya en caché: $imagesCached, Omitidas: $imagesSkipped');
  }

  /// Descarga una imagen individual directamente vía HTTP
  static Future<String> _downloadSingleImageDirect(Productos product, Directory cacheDir) async {
    try {
      final imageUrl = product.prod_Imagen;
      
      if (imageUrl == null || imageUrl.isEmpty) {
        return 'skipped'; // No hay imagen que descargar
      }
      
      // Validar que la URL sea válida
      if (!_isValidImageUrl(imageUrl)) {
        developer.log('⚠️ URL de imagen inválida para producto ${product.prod_Id}: $imageUrl');
        return 'skipped';
      }
      
      // Generar nombre de archivo único basado en URL
      final fileName = _generateCacheFileName(imageUrl, product.prod_Id.toString());
      final cacheFile = File('${cacheDir.path}/$fileName');
      
      // Verificar si ya existe en caché local
      if (await cacheFile.exists()) {
        final fileSize = await cacheFile.length();
        if (fileSize > 0) {
          developer.log('💾 Imagen ya en caché: ${product.prod_Id} ($fileSize bytes)');
          return 'cached';
        }
      }
      
      developer.log('⬇️ Descargando imagen: ${product.prod_Id} desde $imageUrl');
      
      // Descargar imagen vía HTTP
      final response = await http.get(
        Uri.parse(imageUrl),
        headers: {
          'User-Agent': 'SIDCOP Mobile App',
          'Accept': 'image/*',
        },
      ).timeout(const Duration(seconds: 15));
      
      if (response.statusCode == 200) {
        // Guardar imagen en caché local
        await cacheFile.writeAsBytes(response.bodyBytes);
        
        final fileSize = response.bodyBytes.length;
        developer.log('✅ Imagen descargada y cacheada: ${product.prod_Id} ($fileSize bytes)');
        
        // También almacenar en CachedNetworkImage para compatibilidad
        await _storeToCachedNetworkImage(imageUrl, response.bodyBytes);
        
        return 'downloaded';
      } else {
        developer.log('❌ Error HTTP ${response.statusCode} descargando imagen: ${product.prod_Id}');
        return 'skipped';
      }
      
    } catch (e) {
      developer.log('❌ Error descargando imagen para producto ${product.prod_Id}: $e');
      return 'skipped';
    }
  }

  /// Obtiene el directorio de caché para imágenes
  static Future<Directory> _getCacheDirectory() async {
    final tempDir = await getTemporaryDirectory();
    final cacheDir = Directory('${tempDir.path}/sidcop_images_cache');
    
    if (!await cacheDir.exists()) {
      await cacheDir.create(recursive: true);
      developer.log('📁 Directorio de caché creado: ${cacheDir.path}');
    }
    
    return cacheDir;
  }

  /// Genera un nombre de archivo único para caché basado en URL y ID de producto
  static String _generateCacheFileName(String imageUrl, String productId) {
    final uri = Uri.parse(imageUrl);
    final extension = uri.path.split('.').last.toLowerCase();
    
    // Usar hash de la URL + ID del producto para evitar colisiones
    final urlHash = imageUrl.hashCode.abs().toString();
    
    return 'product_${productId}_${urlHash}.${extension.isNotEmpty ? extension : 'jpg'}';
  }

  /// Almacena la imagen descargada en el caché de CachedNetworkImage para compatibilidad
  static Future<void> _storeToCachedNetworkImage(String imageUrl, Uint8List imageBytes) async {
    try {
      // Crear un ImageProvider temporal para forzar el almacenamiento en caché
      final imageProvider = CachedNetworkImageProvider(imageUrl);
      
      // Esto fuerza a CachedNetworkImage a almacenar la imagen en su caché interno
      final imageStream = imageProvider.resolve(const ImageConfiguration());
      
      final completer = Completer<void>();
      late ImageStreamListener listener;
      
      listener = ImageStreamListener(
        (ImageInfo image, bool synchronousCall) {
          imageStream.removeListener(listener);
          if (!completer.isCompleted) completer.complete();
        },
        onError: (exception, stackTrace) {
          imageStream.removeListener(listener);
          if (!completer.isCompleted) completer.complete();
        },
      );
      
      imageStream.addListener(listener);
      
      // Timeout de 5 segundos para el almacenamiento en caché
      await completer.future.timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          imageStream.removeListener(listener);
        },
      );
      
    } catch (e) {
      developer.log('⚠️ Error almacenando en CachedNetworkImage: $e');
    }
  }

  /// Limpia el caché local de imágenes
  static Future<void> clearLocalImageCache() async {
    try {
      final cacheDir = await _getCacheDirectory();
      
      if (await cacheDir.exists()) {
        await cacheDir.delete(recursive: true);
        developer.log(' Caché local de imágenes limpiado');
      }
      
      // También limpiar precarga en memoria
      clearPreload();
      
    } catch (e) {
      developer.log(' Error limpiando caché local: $e');
    }
  }

  /// Obtiene información del caché local de imágenes
  static Future<Map<String, dynamic>> getLocalCacheInfo() async {
    try {
      final cacheDir = await _getCacheDirectory();
      
      if (!await cacheDir.exists()) {
        return {
          'exists': false,
          'filesCount': 0,
          'totalSize': 0,
          'path': cacheDir.path,
        };
      }
      
      final files = await cacheDir.list().toList();
      int totalSize = 0;
      
      for (var file in files) {
        if (file is File) {
          totalSize += await file.length();
        }
      }
      
      return {
        'exists': true,
        'filesCount': files.length,
        'totalSize': totalSize,
        'totalSizeMB': (totalSize / (1024 * 1024)).toStringAsFixed(2),
        'path': cacheDir.path,
      };
      
    } catch (e) {
      developer.log('❌ Error obteniendo info del caché: $e');
      return {
        'exists': false,
        'error': e.toString(),
      };
    }
  }
}

/// Servicio auxiliar para navegación (necesario para precacheImage)
class NavigationService {
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
}

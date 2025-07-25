import 'dart:async';
import 'dart:developer' as developer;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
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
}

/// Servicio auxiliar para navegación (necesario para precacheImage)
class NavigationService {
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
}

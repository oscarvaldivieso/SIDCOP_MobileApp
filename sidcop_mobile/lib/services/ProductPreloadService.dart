import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:sidcop_mobile/models/ProductosViewModel.dart';
import 'package:sidcop_mobile/services/SyncService.dart';
import 'package:sidcop_mobile/services/CacheService.dart';
import 'package:sidcop_mobile/services/NavigationService.dart';
import 'package:sidcop_mobile/services/ProductosService.dart';
import 'package:sidcop_mobile/services/ProductImageCacheService.dart';

/// Servicio para precargar productos e imágenes en segundo plano
class ProductPreloadService {
  static final ProductPreloadService _instance = ProductPreloadService._internal();
  factory ProductPreloadService() => _instance;
  ProductPreloadService._internal();

  final ProductImageCacheService _imageCacheService = ProductImageCacheService();

  bool _isPreloading = false;
  bool _isPreloaded = false;
  List<Productos>? _preloadedProducts;
  int _totalProducts = 0;
  int _loadedProducts = 0;
  int _loadedImages = 0;
  DateTime? _lastPreloadTime;
  String _lastError = '';

  /// Precarga productos e imágenes
  Future<List<Productos>> preloadProductsAndImages() async {
    if (_isPreloading) {
      developer.log('ProductPreloadService: Ya hay una precarga en curso');
      return _preloadedProducts ?? [];
    }
    
    _isPreloading = true;
    _isPreloaded = false;
    _lastError = '';
    
    try {
      developer.log('ProductPreloadService: Iniciando precarga de productos');
      
      // Opción 1: Usar ProductosService directamente (como lo hace la pantalla original)
      final productosService = ProductosService();
      final products = await productosService.getProductos();
      
      _preloadedProducts = products;
      _totalProducts = products.length;
      _loadedProducts = products.length;
      
      developer.log('ProductPreloadService: ${products.length} productos cargados');
      
      // Paso 2: Precargar imágenes usando ProductImageCacheService
      await _preloadImagesWithCache(products);
      
      _isPreloaded = true;
      _lastPreloadTime = DateTime.now();
      
      return products;
    } catch (e) {
      _lastError = e.toString();
      developer.log('ProductPreloadService: Error en precarga: $_lastError');
      return [];
    } finally {
      _isPreloading = false;
    }
  }

  /// Precarga productos e imágenes en segundo plano (no bloqueante)
  void preloadInBackground() {
    if (_isPreloading || _isPreloaded) return;
    
    Future.microtask(() async {
      await preloadProductsAndImages();
    });
  }

  /// Obtiene productos precargados sin hacer nueva consulta
  Future<List<Productos>> getPreloadedProducts() async {
    // Si ya están precargados, devolver inmediatamente
    if (_isPreloaded && _preloadedProducts != null) {
      developer.log('ProductPreloadService: Usando productos precargados (${_preloadedProducts!.length})');
      return _preloadedProducts!;
    }
    
    // Si hay una precarga en proceso, esperar a que termine
    if (_isPreloading) {
      developer.log('ProductPreloadService: Esperando a que termine la precarga en proceso');
      // Esperar máximo 5 segundos
      for (int i = 0; i < 50; i++) {
        await Future.delayed(Duration(milliseconds: 100));
        if (!_isPreloading || _preloadedProducts != null) {
          return _preloadedProducts ?? [];
        }
      }
    }
    
    // Si no hay precarga ni está en proceso, iniciar una nueva
    developer.log('ProductPreloadService: No hay productos precargados, iniciando precarga');
    return await preloadProductsAndImages();
  }

  /// Verifica si los productos están precargados
  bool isPreloaded() {
    return _isPreloaded && _preloadedProducts != null && _preloadedProducts!.isNotEmpty;
  }

  /// Limpia la precarga para forzar una nueva carga
  void clearPreload() {
    _isPreloaded = false;
    _preloadedProducts = null;
    _totalProducts = 0;
    _loadedProducts = 0;
    _loadedImages = 0;
    _lastPreloadTime = null;
    developer.log('ProductPreloadService: Precarga limpiada');
  }

  /// Obtiene información sobre el estado de la precarga
  Map<String, dynamic> getPreloadInfo() {
    return {
      'isPreloading': _isPreloading,
      'isPreloaded': _isPreloaded,
      'totalProducts': _totalProducts,
      'loadedProducts': _loadedProducts,
      'loadedImages': _loadedImages,
      'lastPreloadTime': _lastPreloadTime?.toIso8601String(),
      'lastError': _lastError,
    };
  }

  /// Precarga imágenes de productos usando ProductImageCacheService
  Future<void> _preloadImagesWithCache(List<Productos> products) async {
    try {
      developer.log('🖼️ ProductPreloadService: Iniciando precarga de imágenes con caché avanzado');
      
      // Usar ProductImageCacheService para caché optimizado
      final success = await _imageCacheService.cacheAllProductImages(products);
      
      if (success) {
        _loadedImages = _imageCacheService.cachedImages;
        developer.log('✅ ProductPreloadService: ${_loadedImages} imágenes precargadas exitosamente');
      } else {
        developer.log('⚠️ ProductPreloadService: Precarga de imágenes completada con algunos errores');
        _loadedImages = _imageCacheService.cachedImages;
      }
      
    } catch (e) {
      developer.log('❌ ProductPreloadService: Error en precarga de imágenes: $e');
      _loadedImages = 0;
    }
  }

  /// Obtiene widget de imagen con caché para un producto
  Widget getCachedProductImage({
    required String? imageUrl,
    required String productId,
    double? width,
    double? height,
    BoxFit fit = BoxFit.cover,
    Widget? placeholder,
    Widget? errorWidget,
  }) {
    return _imageCacheService.getCachedProductImage(
      imageUrl: imageUrl,
      productId: productId,
      width: width,
      height: height,
      fit: fit,
      placeholder: placeholder,
      errorWidget: errorWidget,
    );
  }

  /// Verifica si una imagen está en caché
  Future<bool> isImageCached(String imageUrl, String productId) async {
    return await _imageCacheService.isImageCached(imageUrl, productId);
  }

  /// Limpia el caché de imágenes
  Future<void> clearImageCache() async {
    await _imageCacheService.clearImageCache();
    _loadedImages = 0;
  }
}

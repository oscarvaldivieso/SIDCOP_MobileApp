import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:sidcop_mobile/models/ProductosViewModel.dart';
import 'package:sidcop_mobile/services/SyncService.dart';
import 'package:sidcop_mobile/services/CacheService.dart';
import 'package:sidcop_mobile/services/NavigationService.dart';
import 'package:sidcop_mobile/services/ProductosService.dart';

/// Servicio para precargar productos e imágenes en segundo plano
class ProductPreloadService {
  static final ProductPreloadService _instance = ProductPreloadService._internal();
  factory ProductPreloadService() => _instance;
  ProductPreloadService._internal();

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
      
      // Paso 2: Precargar imágenes en segundo plano
      _preloadImages(products);
      
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

  /// Precarga imágenes de productos en segundo plano
  void _preloadImages(List<Productos> products) async {
    _loadedImages = 0;
    
    // Procesar en lotes de 10 para no sobrecargar
    final batchSize = 10;
    
    for (int i = 0; i < products.length; i += batchSize) {
      final end = (i + batchSize < products.length) ? i + batchSize : products.length;
      final batch = products.sublist(i, end);
      
      await Future.wait(
        batch.map((product) async {
          if (product.prod_Imagen != null && product.prod_Imagen!.isNotEmpty) {
            try {
              // Intentar precargar la imagen usando NavigationService si está disponible
              final context = NavigationService.navigatorKey.currentContext;
              if (context != null) {
                await precacheImage(
                  CachedNetworkImageProvider(product.prod_Imagen!),
                  context,
                );
              } else {
                // Fallback si no hay contexto disponible
                await CachedNetworkImageProvider(product.prod_Imagen!).resolve(ImageConfiguration());
              }
              _loadedImages++;
            } catch (e) {
              developer.log('Error precargando imagen para ${product.prod_Descripcion}: $e');
            }
          }
        }).toList(),
      );
      
      // Pequeña pausa entre lotes para no bloquear la UI
      await Future.delayed(Duration(milliseconds: 100));
    }
    
    developer.log('ProductPreloadService: $_loadedImages imágenes precargadas de $_totalProducts productos');
  }
}

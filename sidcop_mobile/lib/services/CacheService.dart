import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Servicio para manejar el caché de datos en memoria y SharedPreferences
class CacheService {
  static const String _userCacheKey = 'user_cache';
  static const String _clientsCacheKey = 'clients_cache';
  static const String _productsCacheKey = 'products_cache';
  static const String _productImagesCacheKey = 'product_images_cache';
  static const String _clientImagesCacheKey = 'client_images_cache';
  static const String _inventoryImagesCacheKey = 'inventory_images_cache';

  // Caché en memoria para acceso rápido
  static final Map<String, dynamic> _memoryCache = {};

  /// Guarda datos del usuario en caché
  static Future<void> cacheUserData(Map<String, dynamic> userData) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Guardar en SharedPreferences
      await prefs.setString(_userCacheKey, jsonEncode(userData));

      // Guardar en memoria
      _memoryCache[_userCacheKey] = userData;

      print('Datos de usuario guardados en caché');
    } catch (e) {
      print('Error guardando datos de usuario en caché: $e');
    }
  }

  /// Obtiene datos del usuario desde caché
  static Future<Map<String, dynamic>?> getCachedUserData() async {
    try {
      // Intentar obtener desde memoria primero
      if (_memoryCache.containsKey(_userCacheKey)) {
        print('Datos de usuario obtenidos desde caché en memoria');
        return _memoryCache[_userCacheKey] as Map<String, dynamic>;
      }

      // Si no está en memoria, obtener desde SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final cachedData = prefs.getString(_userCacheKey);

      if (cachedData != null) {
        final userData = jsonDecode(cachedData) as Map<String, dynamic>;

        // Actualizar caché en memoria
        _memoryCache[_userCacheKey] = userData;

        print('Datos de usuario obtenidos desde caché persistente');
        return userData;
      }

      return null;
    } catch (e) {
      print('Error obteniendo datos de usuario desde caché: $e');
      return null;
    }
  }

  /// Guarda lista de clientes en caché
  static Future<void> cacheClientsData(
    List<Map<String, dynamic>> clients,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Guardar en SharedPreferences
      await prefs.setString(_clientsCacheKey, jsonEncode(clients));

      // Guardar en memoria
      _memoryCache[_clientsCacheKey] = clients;

      print('Datos de clientes guardados en caché: ${clients.length} registros');
    } catch (e) {
      print('Error guardando datos de clientes en caché: $e');
    }
  }

  /// Obtiene lista de clientes desde caché
  static Future<List<Map<String, dynamic>>?> getCachedClientsData() async {
    try {
      // Intentar obtener desde memoria primero
      if (_memoryCache.containsKey(_clientsCacheKey)) {
        print('Datos de clientes obtenidos desde caché en memoria');
        return (_memoryCache[_clientsCacheKey] as List)
            .cast<Map<String, dynamic>>();
      }

      // Si no está en memoria, obtener desde SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final cachedData = prefs.getString(_clientsCacheKey);

      if (cachedData != null) {
        final clients = (jsonDecode(cachedData) as List)
            .cast<Map<String, dynamic>>();

        // Actualizar caché en memoria
        _memoryCache[_clientsCacheKey] = clients;

        print('Datos de clientes obtenidos desde caché persistente: ${clients.length} registros');
        return clients;
      }

      return null;
    } catch (e) {
      print('Error obteniendo datos de clientes desde caché: $e');
      return null;
    }
  }

  /// Guarda lista de productos en caché
  static Future<void> cacheProductsData(
    List<Map<String, dynamic>> products,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Guardar en SharedPreferences
      await prefs.setString(_productsCacheKey, jsonEncode(products));

      // Guardar en memoria
      _memoryCache[_productsCacheKey] = products;

      print('Datos de productos guardados en caché: ${products.length} registros');
    } catch (e) {
      print('Error guardando datos de productos en caché: $e');
    }
  }

  /// Obtiene lista de productos desde caché
  static Future<List<Map<String, dynamic>>?> getCachedProductsData() async {
    try {
      // Intentar obtener desde memoria primero
      if (_memoryCache.containsKey(_productsCacheKey)) {
        print('Datos de productos obtenidos desde caché en memoria');
        return (_memoryCache[_productsCacheKey] as List)
            .cast<Map<String, dynamic>>();
      }

      // Si no está en memoria, obtener desde SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final cachedData = prefs.getString(_productsCacheKey);

      if (cachedData != null) {
        final products = (jsonDecode(cachedData) as List)
            .cast<Map<String, dynamic>>();

        // Actualizar caché en memoria
        _memoryCache[_productsCacheKey] = products;

        print('Datos de productos obtenidos desde caché persistente: ${products.length} registros');
        return products;
      }

      return null;
    } catch (e) {
      print('Error obteniendo datos de productos desde caché: $e');
      return null;
    }
  }



  /// Limpia todo el caché
  static Future<void> clearAllCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Limpiar SharedPreferences
      await prefs.remove(_userCacheKey);
      await prefs.remove(_clientsCacheKey);
      await prefs.remove(_productsCacheKey);
      await prefs.remove(_productImagesCacheKey);
      await prefs.remove(_clientImagesCacheKey);
      await prefs.remove(_inventoryImagesCacheKey);

      // Limpiar caché en memoria
      _memoryCache.clear();

      print('Todo el caché ha sido limpiado');
    } catch (e) {
      print('Error limpiando el caché: $e');
    }
  }

  /// Guarda mapeo de imágenes de productos en caché
  static Future<void> cacheProductImagesData(Map<String, String> imagesData) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Guardar en SharedPreferences
      await prefs.setString(_productImagesCacheKey, jsonEncode(imagesData));

      // Guardar en memoria
      _memoryCache[_productImagesCacheKey] = imagesData;

      print('Mapeo de imágenes de productos guardado en caché');
    } catch (e) {
      print('Error guardando mapeo de imágenes en caché: $e');
    }
  }

  /// Obtiene mapeo de imágenes de productos desde caché
  static Future<Map<String, String>?> getCachedProductImagesData() async {
    try {
      // Intentar obtener desde memoria primero
      if (_memoryCache.containsKey(_productImagesCacheKey)) {
        print('Mapeo de imágenes obtenido desde caché en memoria');
        return Map<String, String>.from(_memoryCache[_productImagesCacheKey] as Map);
      }

      // Si no está en memoria, obtener desde SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final cachedData = prefs.getString(_productImagesCacheKey);

      if (cachedData != null) {
        final imagesData = Map<String, String>.from(jsonDecode(cachedData) as Map);

        // Actualizar caché en memoria
        _memoryCache[_productImagesCacheKey] = imagesData;

        print('Mapeo de imágenes obtenido desde caché persistente');
        return imagesData;
      }

      return null;
    } catch (e) {
      print('Error obteniendo mapeo de imágenes desde caché: $e');
      return null;
    }
  }

  /// Limpia el caché de imágenes de productos
  static Future<void> clearProductImagesCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_productImagesCacheKey);
      _memoryCache.remove(_productImagesCacheKey);
      print('CacheService: Caché de imágenes de productos limpiado');
    } catch (e) {
      print('CacheService: Error limpiando caché de imágenes de productos: $e');
    }
  }

  /// Guarda mapeo de imágenes de clientes en caché
  static Future<void> cacheClientImagesData(Map<String, String> imagesData) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Convertir Map a JSON string
      final jsonString = jsonEncode(imagesData);

      // Guardar en SharedPreferences
      await prefs.setString(_clientImagesCacheKey, jsonString);

      // Guardar en memoria para acceso rápido
      _memoryCache[_clientImagesCacheKey] = imagesData;

      print('CacheService: Mapeo de imágenes de clientes guardado en caché (${imagesData.length} entradas)');
    } catch (e) {
      print('CacheService: Error guardando mapeo de imágenes de clientes: $e');
    }
  }

  /// Obtiene mapeo de imágenes de clientes desde caché
  static Future<Map<String, String>?> getCachedClientImagesData() async {
    try {
      // Intentar obtener desde memoria primero
      if (_memoryCache.containsKey(_clientImagesCacheKey)) {
        final cachedData = _memoryCache[_clientImagesCacheKey] as Map<String, String>?;
        if (cachedData != null) {
          print('CacheService: Mapeo de imágenes de clientes obtenido desde memoria (${cachedData.length} entradas)');
          return cachedData;
        }
      }

      // Si no está en memoria, obtener desde SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_clientImagesCacheKey);

      if (jsonString != null) {
        final Map<String, dynamic> jsonData = jsonDecode(jsonString);
        final Map<String, String> imagesData = jsonData.cast<String, String>();

        // Guardar en memoria para próxima vez
        _memoryCache[_clientImagesCacheKey] = imagesData;

        print('CacheService: Mapeo de imágenes de clientes obtenido desde SharedPreferences (${imagesData.length} entradas)');
        return imagesData;
      }

      print('CacheService: No hay mapeo de imágenes de clientes en caché');
      return null;
    } catch (e) {
      print('CacheService: Error obteniendo mapeo de imágenes de clientes: $e');
      return null;
    }
  }

  /// Limpia el caché de imágenes de clientes
  static Future<void> clearClientImagesCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_clientImagesCacheKey);
      _memoryCache.remove(_clientImagesCacheKey);
      print('CacheService: Caché de imágenes de clientes limpiado');
    } catch (e) {
      print('CacheService: Error limpiando caché de imágenes de clientes: $e');
    }
  }

  /// Guarda mapeo de imágenes de inventario en caché
  static Future<void> cacheInventoryImagesData(Map<String, String> imagesData) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Guardar en SharedPreferences
      await prefs.setString(_inventoryImagesCacheKey, jsonEncode(imagesData));

      // Guardar en memoria
      _memoryCache[_inventoryImagesCacheKey] = imagesData;

      print('Mapeo de imágenes de inventario guardado en caché');
    } catch (e) {
      print('Error guardando mapeo de imágenes de inventario en caché: $e');
    }
  }

  /// Obtiene mapeo de imágenes de inventario desde caché
  static Future<Map<String, String>?> getCachedInventoryImagesData() async {
    try {
      // Intentar obtener desde memoria primero
      if (_memoryCache.containsKey(_inventoryImagesCacheKey)) {
        print('Mapeo de imágenes de inventario obtenido desde caché en memoria');
        return Map<String, String>.from(_memoryCache[_inventoryImagesCacheKey] as Map);
      }

      // Si no está en memoria, obtener desde SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final cachedData = prefs.getString(_inventoryImagesCacheKey);

      if (cachedData != null) {
        final imagesData = Map<String, String>.from(jsonDecode(cachedData) as Map);

        // Actualizar caché en memoria
        _memoryCache[_inventoryImagesCacheKey] = imagesData;

        print('Mapeo de imágenes de inventario obtenido desde caché persistente');
        return imagesData;
      }

      return null;
    } catch (e) {
      print('Error obteniendo mapeo de imágenes de inventario desde caché: $e');
      return null;
    }
  }

  /// Limpia el caché de imágenes de inventario
  static Future<void> clearInventoryImagesCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_inventoryImagesCacheKey);
      _memoryCache.remove(_inventoryImagesCacheKey);
      print('CacheService: Caché de imágenes de inventario limpiado');
    } catch (e) {
      print('CacheService: Error limpiando caché de imágenes de inventario: $e');
    }
  }

  /// Obtiene información del estado del caché
  static Future<Map<String, dynamic>> getCacheInfo() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      Map<String, dynamic> info = {
        'memory_cache_size': _memoryCache.length,
        'cache_entries': {},
      };

      final keys = [_userCacheKey, _clientsCacheKey, _productsCacheKey, _productImagesCacheKey, _clientImagesCacheKey, _inventoryImagesCacheKey];

      for (String key in keys) {
        final cachedData = prefs.getString(key);
        if (cachedData != null) {
          info['cache_entries'][key] = {
            'exists': true,
            'in_memory': _memoryCache.containsKey(key),
          };
        }
      }

      return info;
    } catch (e) {
      print('Error obteniendo información del caché: $e');
      return {};
    }
  }
}

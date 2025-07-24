import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:developer' as developer;

/// Servicio para manejar el caché de datos en memoria y SharedPreferences
class CacheService {
  static const String _userCacheKey = 'user_cache';
  static const String _clientsCacheKey = 'clients_cache';
  static const String _productsCacheKey = 'products_cache';

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

      developer.log('Datos de usuario guardados en caché');
    } catch (e) {
      developer.log('Error guardando datos de usuario en caché: $e');
    }
  }

  /// Obtiene datos del usuario desde caché
  static Future<Map<String, dynamic>?> getCachedUserData() async {
    try {
      // Intentar obtener desde memoria primero
      if (_memoryCache.containsKey(_userCacheKey)) {
        developer.log('Datos de usuario obtenidos desde caché en memoria');
        return _memoryCache[_userCacheKey] as Map<String, dynamic>;
      }

      // Si no está en memoria, obtener desde SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final cachedData = prefs.getString(_userCacheKey);

      if (cachedData != null) {
        final userData = jsonDecode(cachedData) as Map<String, dynamic>;

        // Actualizar caché en memoria
        _memoryCache[_userCacheKey] = userData;

        developer.log('Datos de usuario obtenidos desde caché persistente');
        return userData;
      }

      return null;
    } catch (e) {
      developer.log('Error obteniendo datos de usuario desde caché: $e');
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

      developer.log(
        'Datos de clientes guardados en caché: ${clients.length} registros',
      );
    } catch (e) {
      developer.log('Error guardando datos de clientes en caché: $e');
    }
  }

  /// Obtiene lista de clientes desde caché
  static Future<List<Map<String, dynamic>>?> getCachedClientsData() async {
    try {
      // Intentar obtener desde memoria primero
      if (_memoryCache.containsKey(_clientsCacheKey)) {
        developer.log('Datos de clientes obtenidos desde caché en memoria');
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

        developer.log(
          'Datos de clientes obtenidos desde caché persistente: ${clients.length} registros',
        );
        return clients;
      }

      return null;
    } catch (e) {
      developer.log('Error obteniendo datos de clientes desde caché: $e');
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

      developer.log(
        'Datos de productos guardados en caché: ${products.length} registros',
      );
    } catch (e) {
      developer.log('Error guardando datos de productos en caché: $e');
    }
  }

  /// Obtiene lista de productos desde caché
  static Future<List<Map<String, dynamic>>?> getCachedProductsData() async {
    try {
      // Intentar obtener desde memoria primero
      if (_memoryCache.containsKey(_productsCacheKey)) {
        developer.log('Datos de productos obtenidos desde caché en memoria');
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

        developer.log(
          'Datos de productos obtenidos desde caché persistente: ${products.length} registros',
        );
        return products;
      }

      return null;
    } catch (e) {
      developer.log('Error obteniendo datos de productos desde caché: $e');
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

      // Limpiar caché en memoria
      _memoryCache.clear();

      developer.log('Todo el caché ha sido limpiado');
    } catch (e) {
      developer.log('Error limpiando el caché: $e');
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

      final keys = [_userCacheKey, _clientsCacheKey, _productsCacheKey];

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
      developer.log('Error obteniendo información del caché: $e');
      return {};
    }
  }
}

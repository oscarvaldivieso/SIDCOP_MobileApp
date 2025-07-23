import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:developer' as developer;

/// Servicio para manejar el caché de datos en memoria y SharedPreferences
class CacheService {
  static const String _userCacheKey = 'user_cache';
  static const String _clientsCacheKey = 'clients_cache';
  static const String _productsCacheKey = 'products_cache';
  static const String _cacheTimestampSuffix = '_timestamp';
  
  // Caché en memoria para acceso rápido
  static Map<String, dynamic> _memoryCache = {};
  
  /// Duración del caché en horas
  static const int _cacheValidHours = 6;
  
  /// Guarda datos del usuario en caché
  static Future<void> cacheUserData(Map<String, dynamic> userData) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      
      // Guardar en SharedPreferences
      await prefs.setString(_userCacheKey, jsonEncode(userData));
      await prefs.setInt('$_userCacheKey$_cacheTimestampSuffix', timestamp);
      
      // Guardar en memoria
      _memoryCache[_userCacheKey] = userData;
      _memoryCache['$_userCacheKey$_cacheTimestampSuffix'] = timestamp;
      
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
        final timestamp = _memoryCache['$_userCacheKey$_cacheTimestampSuffix'] as int?;
        if (timestamp != null && _isCacheValid(timestamp)) {
          developer.log('Datos de usuario obtenidos desde caché en memoria');
          return _memoryCache[_userCacheKey] as Map<String, dynamic>;
        }
      }
      
      // Si no está en memoria o expiró, obtener desde SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final cachedData = prefs.getString(_userCacheKey);
      final timestamp = prefs.getInt('$_userCacheKey$_cacheTimestampSuffix');
      
      if (cachedData != null && timestamp != null && _isCacheValid(timestamp)) {
        final userData = jsonDecode(cachedData) as Map<String, dynamic>;
        
        // Actualizar caché en memoria
        _memoryCache[_userCacheKey] = userData;
        _memoryCache['$_userCacheKey$_cacheTimestampSuffix'] = timestamp;
        
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
  static Future<void> cacheClientsData(List<Map<String, dynamic>> clients) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      
      // Guardar en SharedPreferences
      await prefs.setString(_clientsCacheKey, jsonEncode(clients));
      await prefs.setInt('$_clientsCacheKey$_cacheTimestampSuffix', timestamp);
      
      // Guardar en memoria
      _memoryCache[_clientsCacheKey] = clients;
      _memoryCache['$_clientsCacheKey$_cacheTimestampSuffix'] = timestamp;
      
      developer.log('Datos de clientes guardados en caché: ${clients.length} registros');
    } catch (e) {
      developer.log('Error guardando datos de clientes en caché: $e');
    }
  }
  
  /// Obtiene lista de clientes desde caché
  static Future<List<Map<String, dynamic>>?> getCachedClientsData() async {
    try {
      // Intentar obtener desde memoria primero
      if (_memoryCache.containsKey(_clientsCacheKey)) {
        final timestamp = _memoryCache['$_clientsCacheKey$_cacheTimestampSuffix'] as int?;
        if (timestamp != null && _isCacheValid(timestamp)) {
          developer.log('Datos de clientes obtenidos desde caché en memoria');
          return (_memoryCache[_clientsCacheKey] as List).cast<Map<String, dynamic>>();
        }
      }
      
      // Si no está en memoria o expiró, obtener desde SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final cachedData = prefs.getString(_clientsCacheKey);
      final timestamp = prefs.getInt('$_clientsCacheKey$_cacheTimestampSuffix');
      
      if (cachedData != null && timestamp != null && _isCacheValid(timestamp)) {
        final clients = (jsonDecode(cachedData) as List).cast<Map<String, dynamic>>();
        
        // Actualizar caché en memoria
        _memoryCache[_clientsCacheKey] = clients;
        _memoryCache['$_clientsCacheKey$_cacheTimestampSuffix'] = timestamp;
        
        developer.log('Datos de clientes obtenidos desde caché persistente: ${clients.length} registros');
        return clients;
      }
      
      return null;
    } catch (e) {
      developer.log('Error obteniendo datos de clientes desde caché: $e');
      return null;
    }
  }
  
  /// Guarda lista de productos en caché
  static Future<void> cacheProductsData(List<Map<String, dynamic>> products) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      
      // Guardar en SharedPreferences
      await prefs.setString(_productsCacheKey, jsonEncode(products));
      await prefs.setInt('$_productsCacheKey$_cacheTimestampSuffix', timestamp);
      
      // Guardar en memoria
      _memoryCache[_productsCacheKey] = products;
      _memoryCache['$_productsCacheKey$_cacheTimestampSuffix'] = timestamp;
      
      developer.log('Datos de productos guardados en caché: ${products.length} registros');
    } catch (e) {
      developer.log('Error guardando datos de productos en caché: $e');
    }
  }
  
  /// Obtiene lista de productos desde caché
  static Future<List<Map<String, dynamic>>?> getCachedProductsData() async {
    try {
      // Intentar obtener desde memoria primero
      if (_memoryCache.containsKey(_productsCacheKey)) {
        final timestamp = _memoryCache['$_productsCacheKey$_cacheTimestampSuffix'] as int?;
        if (timestamp != null && _isCacheValid(timestamp)) {
          developer.log('Datos de productos obtenidos desde caché en memoria');
          return (_memoryCache[_productsCacheKey] as List).cast<Map<String, dynamic>>();
        }
      }
      
      // Si no está en memoria o expiró, obtener desde SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final cachedData = prefs.getString(_productsCacheKey);
      final timestamp = prefs.getInt('$_productsCacheKey$_cacheTimestampSuffix');
      
      if (cachedData != null && timestamp != null && _isCacheValid(timestamp)) {
        final products = (jsonDecode(cachedData) as List).cast<Map<String, dynamic>>();
        
        // Actualizar caché en memoria
        _memoryCache[_productsCacheKey] = products;
        _memoryCache['$_productsCacheKey$_cacheTimestampSuffix'] = timestamp;
        
        developer.log('Datos de productos obtenidos desde caché persistente: ${products.length} registros');
        return products;
      }
      
      return null;
    } catch (e) {
      developer.log('Error obteniendo datos de productos desde caché: $e');
      return null;
    }
  }
  
  /// Verifica si el caché es válido basado en el timestamp
  static bool _isCacheValid(int timestamp) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final cacheAge = now - timestamp;
    final maxAge = _cacheValidHours * 60 * 60 * 1000; // Convertir horas a milisegundos
    return cacheAge < maxAge;
  }
  
  /// Limpia todo el caché
  static Future<void> clearAllCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Limpiar SharedPreferences
      await prefs.remove(_userCacheKey);
      await prefs.remove('$_userCacheKey$_cacheTimestampSuffix');
      await prefs.remove(_clientsCacheKey);
      await prefs.remove('$_clientsCacheKey$_cacheTimestampSuffix');
      await prefs.remove(_productsCacheKey);
      await prefs.remove('$_productsCacheKey$_cacheTimestampSuffix');
      
      // Limpiar caché en memoria
      _memoryCache.clear();
      
      developer.log('Todo el caché ha sido limpiado');
    } catch (e) {
      developer.log('Error limpiando el caché: $e');
    }
  }
  
  /// Limpia caché expirado
  static Future<void> clearExpiredCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = [_userCacheKey, _clientsCacheKey, _productsCacheKey];
      
      for (String key in keys) {
        final timestamp = prefs.getInt('$key$_cacheTimestampSuffix');
        if (timestamp != null && !_isCacheValid(timestamp)) {
          await prefs.remove(key);
          await prefs.remove('$key$_cacheTimestampSuffix');
          _memoryCache.remove(key);
          _memoryCache.remove('$key$_cacheTimestampSuffix');
          developer.log('Caché expirado eliminado: $key');
        }
      }
    } catch (e) {
      developer.log('Error limpiando caché expirado: $e');
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
        final timestamp = prefs.getInt('$key$_cacheTimestampSuffix');
        if (timestamp != null) {
          info['cache_entries'][key] = {
            'timestamp': timestamp,
            'age_hours': (DateTime.now().millisecondsSinceEpoch - timestamp) / (1000 * 60 * 60),
            'is_valid': _isCacheValid(timestamp),
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

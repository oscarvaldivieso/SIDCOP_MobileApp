import 'dart:developer' as developer;
import 'CacheService.dart';

/// Servicio para manejar la configuración de la aplicación
class ConfiguracionService {
  
  /// Limpia toda la memoria caché de la aplicación
  static Future<bool> limpiarCache() async {
    try {
      developer.log('Iniciando limpieza de caché desde ConfiguracionService');
      
      // Llamar al método de limpieza del CacheService
      await CacheService.clearAllCache();
      
      developer.log('Caché limpiado exitosamente');
      return true;
    } catch (e) {
      developer.log('Error al limpiar caché: $e');
      return false;
    }
  }
  
  /// Obtiene información del estado actual del caché
  static Future<Map<String, dynamic>> obtenerInfoCache() async {
    try {
      return await CacheService.getCacheInfo();
    } catch (e) {
      developer.log('Error obteniendo información del caché: $e');
      return {};
    }
  }
  

}
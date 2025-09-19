import 'dart:convert';
import 'dart:developer' as developer;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:crypto/crypto.dart';
import 'package:sidcop_mobile/services/GlobalService.Dart';
import 'package:sidcop_mobile/services/inventory_service.dart';
import 'package:sidcop_mobile/services/InventoryImageCacheService.dart';

class OfflineAuthService {
  // Claves para datos de sesión activa (se eliminan al cerrar sesión)
  static const String _keyOfflineCredentials = 'offline_credentials';
  static const String _keyOfflineUserData = 'offline_user_data';
  static const String _keyLastOnlineLogin = 'last_online_login';
  
  // Claves para datos permanentes (NUNCA se eliminan)
  static const String _keyPermanentCredentials = 'permanent_offline_credentials';
  static const String _keyPermanentUserData = 'permanent_offline_user_data';
  static const String _keyPermanentLastLogin = 'permanent_last_online_login';

  /// Guarda las credenciales y datos del usuario después de un login online exitoso
  /// Ahora también sincroniza automáticamente los datos del inventario para uso offline
  /// IMPORTANTE: Guarda tanto datos de sesión como datos PERMANENTES
  static Future<void> saveOfflineCredentials({
    required String username,
    required String password,
    required Map<String, dynamic> userData,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Hashear la contraseña para seguridad
      final hashedPassword = _hashPassword(password);
      final timestamp = DateTime.now().toIso8601String();
      
      // Guardar credenciales hasheadas para sesión activa
      final credentials = {
        'username': username,
        'password_hash': hashedPassword,
        'created_at': timestamp,
      };
      
      await prefs.setString(_keyOfflineCredentials, jsonEncode(credentials));
      await prefs.setString(_keyOfflineUserData, jsonEncode(userData));
      await prefs.setString(_keyLastOnlineLogin, timestamp);
      
      // NUEVO: Guardar datos PERMANENTES que NUNCA se eliminan
      await prefs.setString(_keyPermanentCredentials, jsonEncode(credentials));
      await prefs.setString(_keyPermanentUserData, jsonEncode(userData));
      await prefs.setString(_keyPermanentLastLogin, timestamp);
      
      // NUEVO: Sincronizar automáticamente datos del inventario para uso offline
      await _syncInventoryDataForOfflineUse(userData);
      
      developer.log('OfflineAuthService: ✅ Credenciales offline y permanentes guardadas exitosamente');
    } catch (e) {
      developer.log('OfflineAuthService: ❌ Error al guardar credenciales offline: $e');
    }
  }

  /// Sincroniza automáticamente los datos del inventario cuando se guarden las credenciales offline
  /// Ahora incluye caché de imágenes como el sistema de productos
  static Future<void> _syncInventoryDataForOfflineUse(Map<String, dynamic> userData) async {
    try {
      // Obtener el vendorId del usuario
      int? vendorId;
      
      if (userData.containsKey('usua_Id')) {
        vendorId = userData['usua_Id'] is int
            ? userData['usua_Id']
            : int.tryParse(userData['usua_Id'].toString());
      } else if (userData.containsKey('usua_IdPersona')) {
        vendorId = userData['usua_IdPersona'] is int
            ? userData['usua_IdPersona']
            : int.tryParse(userData['usua_IdPersona'].toString());
      }
      
      if (vendorId != null && vendorId > 0) {
        developer.log('OfflineAuthService: Sincronizando datos de inventario para vendorId: $vendorId');
        
        // Paso 1: Sincronizar datos de inventario
        final inventoryService = _getInventoryService();
        final success = await inventoryService.syncInventoryData(vendorId);
        
        if (success) {
          developer.log('OfflineAuthService: Datos de inventario sincronizados exitosamente');
          
          // Paso 2: Cachear imágenes de inventario en segundo plano (como productos)
          _cacheInventoryImagesInBackground(vendorId);
        } else {
          developer.log('OfflineAuthService: Error al sincronizar datos de inventario');
        }
      } else {
        developer.log('OfflineAuthService: No se pudo obtener vendorId para sincronizar inventario');
      }
    } catch (e) {
      developer.log('OfflineAuthService: Error al sincronizar inventario automáticamente: $e');
    }
  }

  /// Cachea las imágenes de inventario en segundo plano sin bloquear el login
  static void _cacheInventoryImagesInBackground(int vendorId) {
    Future.microtask(() async {
      try {
        developer.log('OfflineAuthService: Iniciando caché de imágenes de inventario en segundo plano');
        
        // Obtener datos de inventario para cachear imágenes
        final inventoryService = _getInventoryService();
        final inventoryData = await inventoryService.getInventoryByVendor(vendorId);
        
        if (inventoryData.isNotEmpty) {
          // Usar InventoryImageCacheService para cachear todas las imágenes
          final imageCacheService = InventoryImageCacheService();
          final success = await imageCacheService.cacheAllInventoryImages(inventoryData);
          
          if (success) {
            developer.log('OfflineAuthService: ✅ Imágenes de inventario cacheadas exitosamente en segundo plano');
          } else {
            developer.log('OfflineAuthService: ⚠️ Caché de imágenes de inventario completado con algunos errores');
          }
        } else {
          developer.log('OfflineAuthService: No hay datos de inventario para cachear imágenes');
        }
      } catch (e) {
        developer.log('OfflineAuthService: ❌ Error al cachear imágenes de inventario en segundo plano: $e');
      }
    });
  }

  /// Obtiene una instancia del servicio de inventario
  static InventoryService _getInventoryService() {
    return InventoryService();
  }

  /// Guarda credenciales básicas sin necesidad de los datos completos del usuario
  static Future<void> saveBasicOfflineCredentials({
    required String username,
    required String password,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final hashedPassword = _hashPassword(password);
      
      final credentials = {
        'username': username,
        'password_hash': hashedPassword,
        'created_at': DateTime.now().toIso8601String(),
        'basic_auth': true, // Marcar como credencial básica
      };
      
      await prefs.setString(_keyOfflineCredentials, jsonEncode(credentials));
      developer.log('OfflineAuthService: Credenciales básicas offline guardadas');
    } catch (e) {
      developer.log('OfflineAuthService: Error al guardar credenciales básicas: $e');
      rethrow;
    }
  }

  /// Actualiza la marca de tiempo de la última sesión
  static Future<void> updateLastSessionTimestamp() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('last_session_timestamp', DateTime.now().toIso8601String());
    } catch (e) {
      developer.log('OfflineAuthService: Error al actualizar timestamp de sesión: $e');
    }
  }

  /// Verifica si hay credenciales offline guardadas (sesión activa o permanentes)
  static Future<bool> hasOfflineCredentials() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Verificar credenciales de sesión activa
      final credentialsJson = prefs.getString(_keyOfflineCredentials);
      final userDataJson = prefs.getString(_keyOfflineUserData);
      
      if (credentialsJson != null && userDataJson != null) {
        return true;
      }
      
      // Si no hay sesión activa, verificar credenciales permanentes
      final permanentCredentials = prefs.getString(_keyPermanentCredentials);
      final permanentUserData = prefs.getString(_keyPermanentUserData);
      
      return permanentCredentials != null && permanentUserData != null;
    } catch (e) {
      developer.log('OfflineAuthService: Error al verificar credenciales offline: $e');
      return false;
    }
  }

  /// Restaura automáticamente la sesión offline sin necesidad de credenciales
  static Future<Map<String, dynamic>?> autoRestoreOfflineSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final credentialsJson = prefs.getString(_keyOfflineCredentials);
      final userDataJson = prefs.getString(_keyOfflineUserData);
      
      if (credentialsJson == null || userDataJson == null) {
        return {'error': true, 'message': 'No hay sesión offline guardada'};
      }
      
      final credentials = jsonDecode(credentialsJson);
      final userData = jsonDecode(userDataJson);
      
      // Verificar si la sesión ha expirado (30 días sin conexión)
      final lastOnline = DateTime.parse(credentials['last_online_login'] ?? DateTime(1970).toIso8601String());
      final daysSinceLastOnline = DateTime.now().difference(lastOnline).inDays;
      
      if (daysSinceLastOnline > 30) {
        await prefs.remove(_keyOfflineCredentials);
        await prefs.remove(_keyOfflineUserData);
        return {'error': true, 'message': 'La sesión offline ha expirado'};
      }
      
      // Actualizar el timestamp de la última sesión
      await updateLastSessionTimestamp();
      
      // Marcar como login offline
      final result = Map<String, dynamic>.from(userData);
      result['offline_login'] = true;
      result['last_online_login'] = credentials['last_online_login'];
      
      return result;
    } catch (e) {
      developer.log('OfflineAuthService: Error al restaurar sesión offline: $e');
      return {'error': true, 'message': 'Error al restaurar sesión offline'};
    }
  }

  /// Intenta autenticar al usuario de forma offline
  /// MODIFICADO: Ahora usa datos permanentes que nunca se eliminan
  static Future<Map<String, dynamic>?> authenticateOffline({
    required String username,
    required String password,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Primero intentar con credenciales de sesión activa
      String? credentialsJson = prefs.getString(_keyOfflineCredentials);
      String? userDataJson = prefs.getString(_keyOfflineUserData);
      
      // Si no hay credenciales de sesión, usar las PERMANENTES
      if (credentialsJson == null || userDataJson == null) {
        developer.log('OfflineAuthService: No hay credenciales de sesión, usando datos permanentes');
        credentialsJson = prefs.getString(_keyPermanentCredentials);
        userDataJson = prefs.getString(_keyPermanentUserData);
        
        if (credentialsJson == null || userDataJson == null) {
          developer.log('OfflineAuthService: No hay credenciales permanentes guardadas');
          return {
            'error': true,
            'message': 'No hay credenciales guardadas para acceso offline',
          };
        }
      }
      
      final credentials = jsonDecode(credentialsJson);
      final userData = jsonDecode(userDataJson);
      
      // Verificar credenciales
      final storedUsername = credentials['username'];
      final storedPasswordHash = credentials['password_hash'];
      final inputPasswordHash = _hashPassword(password);
      
      if (storedUsername != username || storedPasswordHash != inputPasswordHash) {
        developer.log('OfflineAuthService: Credenciales offline incorrectas');
        return {
          'error': true,
          'message': 'Usuario y/o contraseña incorrectos',
        };
      }
      
      // Restaurar globalVendId desde los datos guardados
      if (userData.containsKey('usua_Id')) {
        globalVendId = userData['usua_Id'] is int
            ? userData['usua_Id']
            : int.tryParse(userData['usua_Id'].toString());
      } else if (userData.containsKey('usua_IdPersona')) {
        globalVendId = userData['usua_IdPersona'] is int
            ? userData['usua_IdPersona']
            : int.tryParse(userData['usua_IdPersona'].toString());
      }
      
      developer.log('OfflineAuthService: ✅ Login offline exitoso para usuario: $username');
      developer.log('OfflineAuthService: globalVendId restaurado: $globalVendId');
      
      // Marcar que fue un login offline
      final result = Map<String, dynamic>.from(userData);
      result['offline_login'] = true;
      result['last_online_login'] = credentials['created_at'];
      
      return result;
      
    } catch (e) {
      developer.log('OfflineAuthService: ❌ Error en autenticación offline: $e');
      return {
        'error': true,
        'message': 'Error en autenticación offline: $e',
      };
    }
  }


  /// Verifica si hay una sesión offline válida que permita auto-login directo
  static Future<bool> hasValidOfflineSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Verificar si "Remember me" está activado
      final rememberMe = prefs.getBool('remember_me') ?? false;
      if (!rememberMe) return false;
      
      // Verificar si hay credenciales offline
      final hasCredentials = await hasOfflineCredentials();
      if (!hasCredentials) return false;
      
      // Verificar si las credenciales no han expirado
      final areExpired = await areCredentialsExpired();
      if (areExpired) return false;
      
      // Verificar que las credenciales de "Remember me" coincidan con las offline
      final savedEmail = prefs.getString('saved_email') ?? '';
      final credentialsJson = prefs.getString(_keyOfflineCredentials);
      
      if (credentialsJson != null && savedEmail.isNotEmpty) {
        final credentials = jsonDecode(credentialsJson);
        final storedUsername = credentials['username'];
        
        return storedUsername == savedEmail;
      }
      
      return false;
    } catch (e) {
      developer.log('OfflineAuthService: Error al verificar sesión offline válida: $e');
      return false;
    }
  }

  /// Guarda la preferencia de mantener sesión activa para uso offline
  static Future<void> saveOfflineSessionPreference({
    required String username,
    required String password,
    required bool rememberMe,
    Map<String, dynamic>? userData,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Guardar credenciales básicas para "Remember me"
      await prefs.setString('saved_email', username);
      await prefs.setString('saved_password', password);
      await prefs.setBool('remember_me', rememberMe);
      
      if (rememberMe) {
        // Si está marcado "Mantener sesión", guardar credenciales offline
        if (userData != null) {
          // Si tenemos datos completos del usuario, guardar credenciales completas
          await saveOfflineCredentials(
            username: username,
            password: password,
            userData: userData,
          );
        } else {
          // Si no tenemos datos completos, guardar credenciales básicas
          await saveBasicOfflineCredentials(
            username: username,
            password: password,
          );
        }
        
        developer.log('OfflineAuthService: Sesión offline configurada para mantener activa');
      } else {
        // Si no está marcado, limpiar solo las credenciales offline pero mantener las básicas
        await clearOfflineCredentials();
        developer.log('OfflineAuthService: Sesión offline desactivada');
      }
    } catch (e) {
      developer.log('OfflineAuthService: Error al guardar preferencia de sesión offline: $e');
    }
  }

  /// Actualiza las credenciales offline después de un login exitoso
  static Future<void> updateOfflineCredentialsAfterLogin({
    required String username,
    required String password,
    required Map<String, dynamic> userData,
    required bool rememberMe,
  }) async {
    try {
      if (rememberMe) {
        // Actualizar credenciales offline completas
        await saveOfflineCredentials(
          username: username,
          password: password,
          userData: userData,
        );
        developer.log('OfflineAuthService: Credenciales offline actualizadas después del login');
      }
    } catch (e) {
      developer.log('OfflineAuthService: Error al actualizar credenciales offline: $e');
    }
  }


  /// Obtiene información sobre las credenciales offline guardadas
  static Future<Map<String, dynamic>?> getOfflineCredentialsInfo() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final credentialsJson = prefs.getString(_keyOfflineCredentials);
      
      if (credentialsJson == null) return null;
      
      final credentials = jsonDecode(credentialsJson);
      return {
        'username': credentials['username'],
        'created_at': credentials['created_at'],
        'has_offline_access': true,
      };
    } catch (e) {
      developer.log('OfflineAuthService: Error al obtener info de credenciales: $e');
      return null;
    }
  }

  /// Limpia todas las credenciales offline guardadas
  static Future<void> clearOfflineCredentials() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      await prefs.remove(_keyOfflineCredentials);
      await prefs.remove(_keyOfflineUserData);
      await prefs.remove(_keyLastOnlineLogin);
      
      developer.log('OfflineAuthService: Credenciales offline eliminadas');
    } catch (e) {
      developer.log('OfflineAuthService: Error al limpiar credenciales offline: $e');
    }
  }

  /// Limpia SOLO la sesión activa cuando el usuario cierra sesión explícitamente
  /// IMPORTANTE: Los datos permanentes NUNCA se eliminan
  static Future<void> clearOfflineSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Limpiar SOLO las credenciales de sesión activa (NO las permanentes)
      await prefs.remove(_keyOfflineCredentials);
      await prefs.remove(_keyOfflineUserData);
      await prefs.remove(_keyLastOnlineLogin);
      
      // Limpiar también las credenciales de "Remember me"
      await prefs.remove('saved_email');
      await prefs.remove('saved_password');
      await prefs.setBool('remember_me', false);
      
      // Limpiar timestamp de sesión
      await prefs.remove('last_session_timestamp');
      
      // IMPORTANTE: NO eliminamos los datos permanentes
      // _keyPermanentCredentials, _keyPermanentUserData, _keyPermanentLastLogin
      // permanecen intactos para permitir login offline futuro
      
      developer.log('OfflineAuthService: ✅ Sesión activa eliminada (datos permanentes conservados)');
    } catch (e) {
      developer.log('OfflineAuthService: ❌ Error al limpiar sesión offline: $e');
    }
  }

  /// Verifica si las credenciales offline han expirado (opcional)
  static Future<bool> areCredentialsExpired({int maxDaysOffline = 30}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastOnlineLogin = prefs.getString(_keyLastOnlineLogin);
      
      if (lastOnlineLogin == null) return true;
      
      final lastLoginDate = DateTime.parse(lastOnlineLogin);
      final daysSinceLastLogin = DateTime.now().difference(lastLoginDate).inDays;
      
      return daysSinceLastLogin > maxDaysOffline;
    } catch (e) {
      developer.log('OfflineAuthService: Error al verificar expiración: $e');
      return true;
    }
  }

  /// Actualiza el timestamp del último login online
  static Future<void> updateLastOnlineLogin() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyLastOnlineLogin, DateTime.now().toIso8601String());
    } catch (e) {
      developer.log('OfflineAuthService: Error al actualizar último login online: $e');
    }
  }

  /// Hashea la contraseña usando SHA-256
  static String _hashPassword(String password) {
    final bytes = utf8.encode(password);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Verifica si hay datos permanentes guardados (nunca se eliminan)
  static Future<bool> hasPermanentOfflineData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final permanentCredentials = prefs.getString(_keyPermanentCredentials);
      final permanentUserData = prefs.getString(_keyPermanentUserData);
      return permanentCredentials != null && permanentUserData != null;
    } catch (e) {
      developer.log('OfflineAuthService: Error al verificar datos permanentes: $e');
      return false;
    }
  }

  /// Obtiene información de los datos permanentes guardados
  static Future<Map<String, dynamic>?> getPermanentOfflineInfo() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final credentialsJson = prefs.getString(_keyPermanentCredentials);
      
      if (credentialsJson == null) return null;
      
      final credentials = jsonDecode(credentialsJson);
      return {
        'username': credentials['username'],
        'created_at': credentials['created_at'],
        'has_permanent_access': true,
      };
    } catch (e) {
      developer.log('OfflineAuthService: Error al obtener info permanente: $e');
      return null;
    }
  }

  /// MÉTODO DE EMERGENCIA: Elimina TODO incluyendo datos permanentes
  /// ⚠️ USAR SOLO EN CASOS EXTREMOS - Requiere nuevo login online
  static Future<void> clearAllOfflineData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Eliminar datos de sesión activa
      await prefs.remove(_keyOfflineCredentials);
      await prefs.remove(_keyOfflineUserData);
      await prefs.remove(_keyLastOnlineLogin);
      
      // Eliminar datos permanentes
      await prefs.remove(_keyPermanentCredentials);
      await prefs.remove(_keyPermanentUserData);
      await prefs.remove(_keyPermanentLastLogin);
      
      // Eliminar credenciales de "Remember me"
      await prefs.remove('saved_email');
      await prefs.remove('saved_password');
      await prefs.setBool('remember_me', false);
      
      // Limpiar timestamp de sesión
      await prefs.remove('last_session_timestamp');
      
      developer.log('OfflineAuthService: ⚠️ TODOS los datos offline eliminados (incluyendo permanentes)');
    } catch (e) {
      developer.log('OfflineAuthService: ❌ Error al eliminar todos los datos: $e');
    }
  }

  /// Verifica la conectividad de red (método auxiliar)
  static Future<bool> hasInternetConnection() async {
    try {
      // Implementación básica - en producción podrías usar connectivity_plus
      // Por ahora retornamos true para permitir que el login normal maneje la conectividad
      return true;
    } catch (e) {
      return false;
    }
  }
}

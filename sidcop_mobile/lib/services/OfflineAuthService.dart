import 'dart:convert';
import 'dart:developer' as developer;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:crypto/crypto.dart';
import 'package:sidcop_mobile/services/GlobalService.Dart';

class OfflineAuthService {
  static const String _keyOfflineCredentials = 'offline_credentials';
  static const String _keyOfflineUserData = 'offline_user_data';
  static const String _keyLastOnlineLogin = 'last_online_login';

  /// Guarda las credenciales y datos del usuario después de un login online exitoso
  static Future<void> saveOfflineCredentials({
    required String username,
    required String password,
    required Map<String, dynamic> userData,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Hashear la contraseña para seguridad
      final hashedPassword = _hashPassword(password);
      
      // Guardar credenciales hasheadas
      final credentials = {
        'username': username,
        'password_hash': hashedPassword,
        'created_at': DateTime.now().toIso8601String(),
      };
      
      await prefs.setString(_keyOfflineCredentials, jsonEncode(credentials));
      
      // Guardar datos del usuario para restaurar sesión
      await prefs.setString(_keyOfflineUserData, jsonEncode(userData));
      
      // Guardar timestamp del último login online
      await prefs.setString(_keyLastOnlineLogin, DateTime.now().toIso8601String());
      
      developer.log('OfflineAuthService: Credenciales offline guardadas exitosamente');
    } catch (e) {
      developer.log('OfflineAuthService: Error al guardar credenciales offline: $e');
    }
  }

  /// Intenta autenticar al usuario de forma offline
  static Future<Map<String, dynamic>?> authenticateOffline({
    required String username,
    required String password,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Verificar si existen credenciales offline
      final credentialsJson = prefs.getString(_keyOfflineCredentials);
      final userDataJson = prefs.getString(_keyOfflineUserData);
      
      if (credentialsJson == null || userDataJson == null) {
        developer.log('OfflineAuthService: No hay credenciales offline guardadas');
        return {
          'error': true,
          'message': 'No hay credenciales guardadas para acceso offline',
        };
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
      if (userData.containsKey('personaId')) {
        globalVendId = userData['personaId'] is int
            ? userData['personaId']
            : int.tryParse(userData['personaId'].toString());
      } else if (userData.containsKey('usua_IdPersona')) {
        globalVendId = userData['usua_IdPersona'] is int
            ? userData['usua_IdPersona']
            : int.tryParse(userData['usua_IdPersona'].toString());
      }
      
      developer.log('OfflineAuthService: Login offline exitoso para usuario: $username');
      developer.log('OfflineAuthService: globalVendId restaurado: $globalVendId');
      
      // Marcar que fue un login offline
      final result = Map<String, dynamic>.from(userData);
      result['offline_login'] = true;
      result['last_online_login'] = credentials['created_at'];
      
      return result;
      
    } catch (e) {
      developer.log('OfflineAuthService: Error en autenticación offline: $e');
      return {
        'error': true,
        'message': 'Error en autenticación offline: $e',
      };
    }
  }

  /// Verifica si hay credenciales offline disponibles
  static Future<bool> hasOfflineCredentials() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final credentialsJson = prefs.getString(_keyOfflineCredentials);
      final userDataJson = prefs.getString(_keyOfflineUserData);
      
      return credentialsJson != null && userDataJson != null;
    } catch (e) {
      developer.log('OfflineAuthService: Error al verificar credenciales offline: $e');
      return false;
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

  /// Restaura automáticamente la sesión offline usando credenciales guardadas
  static Future<Map<String, dynamic>?> autoRestoreOfflineSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedEmail = prefs.getString('saved_email') ?? '';
      final savedPassword = prefs.getString('saved_password') ?? '';
      
      if (savedEmail.isEmpty || savedPassword.isEmpty) {
        return {
          'error': true,
          'message': 'No hay credenciales de sesión guardadas',
        };
      }
      
      return await authenticateOffline(
        username: savedEmail,
        password: savedPassword,
      );
    } catch (e) {
      developer.log('OfflineAuthService: Error al restaurar sesión automáticamente: $e');
      return {
        'error': true,
        'message': 'Error al restaurar sesión offline: $e',
      };
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

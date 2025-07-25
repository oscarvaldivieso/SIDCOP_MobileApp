import 'dart:convert';
import 'dart:developer' as developer;
import 'package:http/http.dart' as http;
import 'package:sidcop_mobile/services/GlobalService.Dart';
import 'package:sidcop_mobile/services/EncryptionService.dart';
import 'package:sidcop_mobile/services/CredentialsStorageService.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UsuarioService {
  final String _apiServer = apiServer;
  final String _apiKey = apikey;
  
  // Clave de seguridad para el endpoint MostrarContrasena
  static const String claveSeguridad = 'ALERTA_SIDCOP1.soloadmins';
  
  // Constantes para el manejo de credenciales offline cifradas
  static const String _offlinePasswordKey = 'offline_password'; // Mantenido para compatibilidad

  /// Obtiene y almacena la contraseña del usuario para uso offline
  Future<bool> obtenerYGuardarContrasenaOffline(int usuaId) async {
    final url = Uri.parse('$_apiServer/Usuarios/MostrarContrasena');
    
    developer.log('Obtener Contraseña Request URL: $url');
    developer.log('Enviando usuaId: $usuaId y claveSeguridad: $claveSeguridad');
    
    final body = {
      'usuaId': usuaId,
      'claveSeguridad': claveSeguridad,
    };
    
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json', 'X-Api-Key': _apiKey},
        body: jsonEncode(body),
      );
      
      developer.log('Obtener Contraseña Response Status: ${response.statusCode}');
      developer.log('Respuesta completa: ${response.body}');
      
      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);
        
        // Verificar si la operación fue exitosa
        if (responseData['success'] == true && responseData['data'] != null) {
          // Intentar obtener la contraseña según la estructura de la respuesta
          String password;
          
          if (responseData['data'] is String) {
            // Si data es directamente la contraseña
            password = responseData['data'];
          } else if (responseData['data'] is Map) {
            // Si data es un objeto que contiene la contraseña
            if (responseData['data']['data'] != null) {
              password = responseData['data']['data'].toString();
            } else if (responseData['data']['password'] != null) {
              password = responseData['data']['password'].toString();
            } else if (responseData['data']['clave'] != null) {
              password = responseData['data']['clave'].toString();
            } else {
              // Si no podemos encontrar la contraseña, registramos el contenido
              developer.log('Estructura de respuesta desconocida: ${responseData['data']}');
              return false;
            }
          } else {
            developer.log('Formato de respuesta inesperado: ${responseData['data']}');
            return false;
          }
          
          // Encriptar y guardar la contraseña para uso offline
          await _guardarContrasenaOffline(password);
          developer.log('Contraseña guardada exitosamente para uso offline');
          return true;
        } else {
          developer.log('Error obteniendo contraseña: ${responseData['message'] ?? 'Respuesta inválida'}');
          return false;
        }
      } else {
        developer.log('Error en la petición: ${response.statusCode}');
        developer.log('Respuesta de error: ${response.body}');
        return false;
      }
    } catch (e) {
      developer.log('Obtener Contraseña Error: $e');
      return false;
    }
  }
  
  /// Guarda la contraseña encriptada para uso offline usando el nuevo sistema cifrado
  Future<void> _guardarContrasenaOffline(String password) async {
    try {
      // Usar el nuevo servicio de almacenamiento cifrado
      // Por ahora solo guardamos la contraseña, el username se obtendrá del contexto
      await CredentialsStorageService.saveCredentials(
        username: 'temp_user', // Se actualizará cuando se integre con el login
        password: password,
      );
      
      // Mantener compatibilidad con el sistema anterior por ahora
      final prefs = await SharedPreferences.getInstance();
      final encryptedPassword = EncryptionService.encriptar(password);
      await prefs.setString(_offlinePasswordKey, encryptedPassword);
      
      developer.log('Contraseña guardada en sistema cifrado y SharedPreferences');
    } catch (e) {
      developer.log('Error guardando contraseña offline: $e');
      throw Exception('Error al guardar contraseña offline: $e');
    }
  }
  
  /// Verifica si hay una contraseña guardada para uso offline
  Future<bool> hayContrasenaOffline() async {
    try {
      // Verificar primero en el nuevo sistema cifrado
      final hasEncryptedCredentials = await CredentialsStorageService.hasStoredCredentials();
      if (hasEncryptedCredentials) {
        return true;
      }
      
      // Fallback al sistema anterior
      final prefs = await SharedPreferences.getInstance();
      return prefs.containsKey(_offlinePasswordKey);
    } catch (e) {
      developer.log('Error verificando contraseña offline: $e');
      return false;
    }
  }
  
  /// Verifica si la contraseña ingresada coincide con la almacenada offline
  Future<bool> verificarContrasenaOffline(String inputPassword) async {
    try {
      // Intentar verificar con el nuevo sistema cifrado primero
      final credentials = await CredentialsStorageService.loadCredentials();
      if (credentials != null && credentials['password'] != null) {
        final storedPassword = credentials['password']!;
        if (storedPassword == inputPassword) {
          return true;
        }
      }
      
      // Fallback al sistema anterior
      final prefs = await SharedPreferences.getInstance();
      final encryptedPassword = prefs.getString(_offlinePasswordKey);
      
      if (encryptedPassword == null) return false;
      
      // Desencriptar la contraseña almacenada
      final storedPassword = EncryptionService.desencriptar(encryptedPassword);
      
      // Comparar con la contraseña ingresada
      return storedPassword == inputPassword;
    } catch (e) {
      developer.log('Error verificando contraseña offline: $e');
      return false;
    }
  }
  
  /// Elimina la contraseña almacenada para uso offline (durante logout)
  Future<void> limpiarContrasenaOffline() async {
    try {
      // Limpiar del nuevo sistema cifrado
      await CredentialsStorageService.clearCredentials();
      
      // Limpiar del sistema anterior por compatibilidad
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_offlinePasswordKey);
      
      developer.log('Credenciales offline eliminadas correctamente de ambos sistemas');
    } catch (e) {
      developer.log('Error eliminando credenciales offline: $e');
    }
  }

  /// Guarda las credenciales completas del usuario de forma cifrada
  Future<void> guardarCredencialesCompletas({
    required String username,
    required String password,
    String? token,
    String? refreshToken,
  }) async {
    try {
      await CredentialsStorageService.saveCredentials(
        username: username,
        password: password,
        token: token,
        refreshToken: refreshToken,
      );
      developer.log('Credenciales completas guardadas de forma cifrada');
    } catch (e) {
      developer.log('Error guardando credenciales completas: $e');
      throw Exception('Error al guardar credenciales completas: $e');
    }
  }

  /// Obtiene las credenciales cifradas almacenadas
  Future<Map<String, String>?> obtenerCredencialesCifradas() async {
    try {
      return await CredentialsStorageService.loadCredentials();
    } catch (e) {
      developer.log('Error obteniendo credenciales cifradas: $e');
      return null;
    }
  }

  /// Actualiza solo los tokens sin cambiar las credenciales
  Future<void> actualizarTokens({
    String? token,
    String? refreshToken,
  }) async {
    try {
      await CredentialsStorageService.updateTokens(
        token: token,
        refreshToken: refreshToken,
      );
      developer.log('Tokens actualizados correctamente');
    } catch (e) {
      developer.log('Error actualizando tokens: $e');
      throw Exception('Error al actualizar tokens: $e');
    }
  }

  /// Verifica credenciales completas para login offline
  Future<bool> verificarCredencialesOffline(String username, String password) async {
    try {
      final credentials = await CredentialsStorageService.loadCredentials();
      if (credentials == null) {
        return false;
      }
      
      final storedUsername = credentials['username'];
      final storedPassword = credentials['password'];
      
      return storedUsername == username && storedPassword == password;
    } catch (e) {
      developer.log('Error verificando credenciales offline: $e');
      return false;
    }
  }

  /// Obtiene información del estado de las credenciales cifradas
  Future<Map<String, dynamic>> obtenerInfoCredenciales() async {
    try {
      return await CredentialsStorageService.getCredentialsInfo();
    } catch (e) {
      developer.log('Error obteniendo información de credenciales: $e');
      return {
        'exists': false,
        'error': e.toString(),
      };
    }
  }

  Future<Map<String, dynamic>?> iniciarSesion(
    String usuario,
    String clave,
  ) async {
    final url = Uri.parse('$_apiServer/Usuarios/IniciarSesion');

    developer.log('Iniciar Sesion Request URL: $url');

    // Crear el body con la estructura requerida por el API
    final body = {
      'usua_Id': 0,
      'usua_Usuario': usuario,
      'Correo': 'string',
      'usua_Clave': clave,
      'usua_Telefono': 'string',
      'role_Id': 0,
      'role_Descripcion': 'string',
      'usua_IdPersona': 0,
      'usua_EsVendedor': true,
      'usua_EsAdmin': true,
      'dni': 'string',
      'usua_Imagen': 'string',
      'usua_Creacion': 0,
      'usua_FechaCreacion': DateTime.now().toIso8601String(),
      'usua_Modificacion': 0,
      'usua_FechaModificacion': DateTime.now().toIso8601String(),
      'usua_Estado': true,
      'permisosJson': 'string',
    };

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json', 'X-Api-Key': _apiKey},
        body: jsonEncode(body),
      );

      developer.log('Iniciar Sesion Response Status: ${response.statusCode}');
      developer.log('Iniciar Sesion Response Body: ${response.body}');
      print(response.body);

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);
        final loginData = responseData['data'] ?? responseData;
        
        // Si el login es exitoso, guardar las credenciales de forma cifrada
        if (loginData != null && !loginData.containsKey('error')) {
          try {
            // Extraer token si existe en la respuesta
            String? token;
            if (loginData.containsKey('token')) {
              token = loginData['token']?.toString();
            } else if (loginData.containsKey('access_token')) {
              token = loginData['access_token']?.toString();
            }
            
            // Guardar credenciales completas de forma cifrada
            await guardarCredencialesCompletas(
              username: usuario,
              password: clave,
              token: token,
            );
            
            developer.log('Credenciales guardadas automáticamente después del login exitoso');
          } catch (e) {
            developer.log('Error guardando credenciales después del login: $e');
            // No fallar el login por error en el guardado de credenciales
          }
        }
        
        return loginData;
      } else {
        developer.log('Error en la autenticación: ${response.statusCode}');
        return {
          'error': true,
          'message': 'Error de autenticación: ${response.statusCode}',
          'details': response.body,
        };
      }
    } catch (e) {
      developer.log('Iniciar Sesion Error: $e');
      return {'error': true, 'message': 'Error de conexión: $e'};
    }
  }
}

import 'dart:convert';
import 'dart:io';
import 'dart:developer' as developer;
import 'package:path_provider/path_provider.dart';
import 'package:sidcop_mobile/services/EncryptionService.dart';

/// Servicio para almacenar credenciales de forma cifrada
class CredentialsStorageService {
  // Nombre del archivo de credenciales cifradas
  static const String _credentialsFileName = 'auth_credentials.csv.enc';
  
  /// Guarda las credenciales de usuario de forma cifrada
  static Future<bool> saveCredentials({
    required String username,
    required String usuaId,
    required String password,
    String? token,
    String? refreshToken,
  }) async {
    try {
      // Crear mapa de credenciales
      final Map<String, String> credentials = {
        'username': username,
        'usuaId': usuaId,
        'password': password,
        'token': token ?? '',
        'refreshToken': refreshToken ?? '',
        'timestamp': DateTime.now().millisecondsSinceEpoch.toString(),
      };
      
      // Convertir a JSON
      final jsonString = jsonEncode(credentials);
      
      // Guardar en archivo (cifrado)
      final encryptedContent = EncryptionService.encriptar(jsonString);
      final file = await _getCredentialsFile();
      developer.log(' DEBUG CREDS - Intentando guardar credenciales en: ${file.path}');
      developer.log(' DEBUG CREDS - Directorio existe: ${await Directory(file.parent.path).exists()}');
      developer.log(' DEBUG CREDS - Tamaño del contenido cifrado: ${encryptedContent.length}');
      await file.writeAsString(encryptedContent);
      
      // Verificar que el archivo se creó correctamente
      final fileExists = await file.exists();
      developer.log(' DEBUG CREDS - Archivo creado exitosamente: $fileExists');
      if (fileExists) {
        final fileSize = await file.length();
        developer.log(' DEBUG CREDS - Tamaño del archivo: $fileSize bytes');
      }
      developer.log('Credenciales guardadas exitosamente en: ${file.path}');
      developer.log('Contenido guardado: $jsonString');
      return true;
    } catch (e) {
      developer.log('Error guardando credenciales cifradas: $e');
      developer.log('Error al guardar credenciales cifradas: $e');
      return false;
    }
  }
  
  /// Carga las credenciales cifradas
  static Future<Map<String, String>?> loadCredentials() async {
    try {
      final file = await _getCredentialsFile();
      
      // Verificar si el archivo existe
      if (!await file.exists()) {
        developer.log('Archivo de credenciales no encontrado en: ${file.path}');
        return null;
      }
      developer.log('Archivo de credenciales encontrado en: ${file.path}');
      
      // Leer contenido (descifrado)
      final encryptedContent = await file.readAsString();
      final jsonString = EncryptionService.desencriptar(encryptedContent);
      developer.log('Contenido leído: $jsonString');
      
      // Convertir de JSON a Map
      final Map<String, dynamic> credentials = jsonDecode(jsonString);
      
      // Convertir todos los valores a String o null
      final Map<String, String> result = {};
      credentials.forEach((key, value) {
        result[key] = value?.toString() ?? '';
      });
      
      return result;
    } catch (e) {
      developer.log('Error cargando credenciales cifradas: $e');
      return null;
    }
  }
  
  /// Verifica si hay credenciales almacenadas
  static Future<bool> hasStoredCredentials() async {
    try {
      final file = await _getCredentialsFile();
      developer.log('🔐 DEBUG CREDS - Verificando existencia de archivo: ${file.path}');
      
      final directoryExists = await Directory(file.parent.path).exists();
      developer.log('🔐 DEBUG CREDS - Directorio existe: $directoryExists');
      
      final fileExists = await file.exists();
      developer.log('🔐 DEBUG CREDS - El archivo existe: $fileExists');
      
      if (fileExists) {
        final fileSize = await file.length();
        developer.log('🔐 DEBUG CREDS - Tamaño del archivo: $fileSize bytes');
      }
      
      return fileExists;
    } catch (e) {
      developer.log(' DEBUG CREDS - Error verificando existencia de credenciales: $e');
      return false;
    }
  }
  
  /// Actualiza solo los tokens sin cambiar las credenciales
  static Future<void> updateTokens({
    String? token,
    String? refreshToken,
  }) async {
    try {
      // Cargar credenciales actuales
      final credentials = await loadCredentials();
      if (credentials == null) {
        throw Exception('No hay credenciales almacenadas para actualizar');
      }
      
      // Actualizar tokens
      await saveCredentials(
        username: credentials['username'] ?? '',
        usuaId: credentials['usuaId'] ?? '',
        password: credentials['password'] ?? '',
        token: token ?? credentials['token'],
        refreshToken: refreshToken ?? credentials['refreshToken'],
      );
      
      developer.log('Tokens actualizados correctamente');
    } catch (e) {
      developer.log('Error actualizando tokens: $e');
      throw Exception('Error al actualizar tokens: $e');
    }
  }
  
  /// Elimina las credenciales cifradas almacenadas
  static Future<bool> clearCredentials() async {
    try {
      final file = await _getCredentialsFile();
      
      if (await file.exists()) {
        await file.delete();
        developer.log('Credenciales cifradas eliminadas exitosamente');
      } else {
        developer.log('No hay credenciales para eliminar');
      }
      
      return true;
    } catch (e) {
      developer.log('Error eliminando credenciales cifradas: $e');
      return false;
    }
  }
  
  /// Obtiene información sobre el estado de las credenciales
  static Future<Map<String, dynamic>> getCredentialsInfo() async {
    try {
      final file = await _getCredentialsFile();
      final exists = await file.exists();
      
      if (!exists) {
        return {
          'exists': false,
          'path': file.path,
          'size': 0,
          'lastModified': null,
        };
      }
      
      final stats = await file.stat();
      
      return {
        'exists': true,
        'path': file.path,
        'size': stats.size,
        'lastModified': stats.modified.toString(),
      };
    } catch (e) {
      developer.log('Error obteniendo información de credenciales: $e');
      return {
        'exists': false,
        'error': e.toString(),
      };
    }
  }
  
  /// Obtiene el archivo de credenciales
  static Future<File> _getCredentialsFile() async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/$_credentialsFileName');
  }
}
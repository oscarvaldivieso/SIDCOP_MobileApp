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





  /// Verifica si hay credenciales guardadas para uso offline
  Future<bool> hayCredencialesOffline() async {
    try {
      return await CredentialsStorageService.hasStoredCredentials();
    } catch (e) {
      developer.log('Error verificando credenciales offline: $e');
      return false;
    }
  }



  /// Elimina las credenciales almacenadas (durante logout)
  Future<void> limpiarCredenciales() async {
    try {
      await CredentialsStorageService.clearCredentials();
      developer.log('Credenciales eliminadas correctamente');
    } catch (e) {
      developer.log('Error eliminando credenciales: $e');
    }
  }

  /// Guarda las credenciales completas del usuario de forma cifrada
  Future<bool> guardarCredencialesCompletas({
    required String username,
    required String password,
    required int usuaId,
    String? token,
    String? refreshToken,
  }) async {
    try {
      final result = await CredentialsStorageService.saveCredentials(
        username: username,
        usuaId: usuaId.toString(),
        password: password,
        token: token ?? '',
        refreshToken: refreshToken ?? '',
      );
      developer.log('Credenciales completas guardadas de forma cifrada');
      return result;
    } catch (e) {
      developer.log('Error guardando credenciales completas: $e');
      developer.log('Error al guardar credenciales completas: $e');
      return false;
    }
  }

  /// Verifica credenciales para login offline
  Future<bool> verificarCredencialesOffline(
    String username,
    String password,
  ) async {
    try {
      final credentials = await CredentialsStorageService.loadCredentials();
      if (credentials == null) return false;
      
      return credentials['username'] == username && 
             credentials['password'] == password;
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
      return {'exists': false, 'error': e.toString()};
    }
  }

  /// Inicia sesión y guarda credenciales si es exitoso
  Future<Map<String, dynamic>?> iniciarSesion(
    String usuario,
    String clave,
  ) async {
    final url = Uri.parse('$_apiServer/Usuarios/IniciarSesion');

    final body = {
      'usua_Id': 0,
      'usua_Usuario': usuario,
      'usua_Clave': clave,
      'Correo': 'string',
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

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);
        final loginData = responseData['data'] ?? responseData;

        // Si el login es exitoso, guardar credenciales
        if (loginData != null && !loginData.containsKey('error')) {
          try {
            await CredentialsStorageService.saveCredentials(
              username: usuario,
              password: clave,
              usuaId: loginData['usua_Id']?.toString() ?? '0',
            );
            developer.log('Credenciales guardadas después del login exitoso');
          } catch (e) {
            developer.log('Error guardando credenciales: $e');
          }
        }

        return loginData;
      } else {
        return {
          'error': true,
          'message': 'Error de autenticación: ${response.statusCode}',
        };
      }
    } catch (e) {
      return {'error': true, 'message': 'Error de conexión: $e'};
    }
  }
}

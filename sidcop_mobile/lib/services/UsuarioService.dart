import 'dart:convert';
import 'dart:developer' as developer;
import 'package:http/http.dart' as http;
import 'package:sidcop_mobile/services/GlobalService.dart';
import 'package:sidcop_mobile/services/EncryptionService.dart';
import 'package:sidcop_mobile/services/ProductPreloadService.dart';
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

  /// Precarga manual de productos e imágenes
  /// Útil para llamar desde la UI cuando sea necesario
  Future<bool> precargarProductos() async {
    try {
      developer.log('Iniciando precarga manual de productos...');
      final result = await ProductPreloadService.preloadProductsAndImages();
      
      if (result) {
        developer.log('Precarga manual completada exitosamente');
      } else {
        developer.log('Precarga manual falló');
      }
      
      return result;
    } catch (e) {
      developer.log('Error en precarga manual: $e');
      return false;
    }
  }

  /// Obtiene el estado actual de la precarga de productos
  Map<String, dynamic> obtenerEstadoPrecarga() {
    return ProductPreloadService.getPreloadInfo();
  }

  /// Verifica si los productos están precargados
  bool productosEstanPrecargados() {
    return ProductPreloadService.isPreloaded();
  }

  /// Limpia la precarga para forzar una nueva precarga
  void limpiarPrecarga() {
    ProductPreloadService.clearPreload();
    developer.log('Precarga de productos limpiada');
  }

  /// Limpia las credenciales almacenadas para modo offline
  Future<bool> limpiarContrasenaOffline() async {
    try {
      final result = await CredentialsStorageService.clearCredentials();
      if (result) {
        developer.log('Credenciales offline limpiadas exitosamente');
      } else {
        developer.log('Error limpiando credenciales offline');
      }
      return result;
    } catch (e) {
      developer.log('Error en limpiarContrasenaOffline: $e');
      return false;
    }
  }

  /// Inicia sesión y guarda credenciales si es exitoso
  /// Si no hay conexión, intenta login offline
  Future<Map<String, dynamic>?> iniciarSesion(
    String usuario,
    String clave,
  ) async {
    try {
      // Intentar login online
      final url = Uri.parse('$_apiServer/Usuarios/IniciarSesion');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json', 'X-Api-Key': _apiKey},
        body: jsonEncode({
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
        }),
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
            
            // PASO 4: Iniciar precarga de productos e imágenes en segundo plano
            developer.log('Iniciando precarga de productos e imágenes...');
            ProductPreloadService.preloadInBackground();
            
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
      // Si hay error de conexión, intentar login offline
      developer.log('Error de conexión, intentando login offline...');

      // Verificar si hay credenciales guardadas
      if (!await hayCredencialesOffline()) {
        return {
          'error': true,
          'message':
              'Sin conexión. No hay credenciales guardadas para modo offline.',
        };
      }

      // Verificar las credenciales offline
      final credencialesValidas = await verificarCredencialesOffline(
        usuario,
        clave,
      );
      if (!credencialesValidas) {
        return {
          'error': true,
          'message': 'Sin conexión. Credenciales incorrectas.',
        };
      }

      // Si las credenciales son válidas, obtener datos guardados
      final credentials = await CredentialsStorageService.loadCredentials();
      if (credentials == null) {
        return {
          'error': true,
          'message': 'Error recuperando datos de usuario offline.',
        };
      }

      // Retornar datos del usuario en formato compatible
      return {
        'usua_Id': int.tryParse(credentials['usuaId'] ?? '0') ?? 0,
        'usua_Usuario': credentials['username'],
        'offline': true, // Indicador de modo offline
      };
    }
  }
}

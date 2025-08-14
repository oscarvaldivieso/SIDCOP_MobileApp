import 'dart:convert';
import 'dart:developer' as developer;
import 'package:http/http.dart' as http;
import 'package:sidcop_mobile/services/GlobalService.Dart';
import 'package:sidcop_mobile/services/ProductPreloadService.dart';

class UsuarioService {
  final String _apiServer = apiServer;
  final String _apiKey = apikey;

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
        // Aquí puedes validar si trae "data" o un objeto directo
        final result = responseData['data'] ?? responseData;

        // Guardar ID de persona global y registrarlo en logs
        globalVendId = result['usua_IdPersona'];
        developer.log('Usuario ID: $globalVendId');

        // PASO 3B: Iniciar precarga de productos en segundo plano después del login exitoso
        _iniciarPrecargaProductos();

        return result;
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

  /// Inicia la precarga de productos en segundo plano
  void _iniciarPrecargaProductos() {
    developer.log(
      'UsuarioService: Iniciando precarga de productos en segundo plano',
    );
    try {
      final preloadService = ProductPreloadService();
      preloadService.preloadInBackground();
    } catch (e) {
      developer.log(
        'UsuarioService: Error al iniciar precarga de productos: $e',
      );
    }
  }

  /// Método público para precargar productos manualmente
  Future<List<dynamic>> precargarProductos() async {
    developer.log('UsuarioService: Precargando productos manualmente');
    try {
      final preloadService = ProductPreloadService();
      return await preloadService.preloadProductsAndImages();
    } catch (e) {
      developer.log('UsuarioService: Error al precargar productos: $e');
      return [];
    }
  }

  /// Obtiene el estado actual de la precarga de productos
  Map<String, dynamic> obtenerEstadoPrecarga() {
    try {
      final preloadService = ProductPreloadService();
      return preloadService.getPreloadInfo();
    } catch (e) {
      developer.log('UsuarioService: Error al obtener estado de precarga: $e');
      return {'error': true, 'message': e.toString()};
    }
  }

  /// Verifica si los productos están precargados
  bool productosEstanPrecargados() {
    try {
      final preloadService = ProductPreloadService();
      return preloadService.isPreloaded();
    } catch (e) {
      return false;
    }
  }

  /// Limpia la precarga de productos para forzar una nueva carga
  void limpiarPrecarga() {
    try {
      final preloadService = ProductPreloadService();
      preloadService.clearPreload();
    } catch (e) {
      developer.log('UsuarioService: Error al limpiar precarga: $e');
    }
  }
}

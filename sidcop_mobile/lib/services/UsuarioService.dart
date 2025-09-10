import 'dart:convert';
import 'dart:developer' as developer;
import 'package:http/http.dart' as http;
import 'package:sidcop_mobile/services/GlobalService.Dart';
import 'package:sidcop_mobile/services/ProductPreloadService.dart';
import 'package:sidcop_mobile/services/SyncService.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sidcop_mobile/Offline_Services/Sincronizacion_Service.dart';

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
        
        // Obtener los datos del SP
        final data = responseData['data'];
        
        // Verificar si los datos existen
        if (data == null) {
          return {
            'error': true,
            'message': 'Respuesta inválida del servidor',
            'details': responseData,
          };
        }
        
        // Verificar el code_Status del SP
        final codeStatus = data['code_Status'];
        
        if (codeStatus == null || codeStatus != 1) {
          // Login falló - el SP devolvió error
          final errorMessage = data['message_Status'] ?? 'Error de autenticación';
          return {
            'error': true,
            'message': errorMessage,
            'details': data,
          };
        }
        
        // code_Status == 1, login exitoso
        // Verificar que tenga los campos esenciales del usuario
        if (!data.containsKey('usua_IdPersona') || data['usua_IdPersona'] == null) {
          return {
            'error': true,
            'message': 'Error al obtener datos del usuario',
            'details': data,
          };
        }

        // Guardar ID de persona global y registrarlo en logs
        globalVendId = data['personaId'] is int
            ? data['personaId']
            : int.tryParse(data['personaId'].toString());

        print('este es el globalVendId: $globalVendId');

        developer.log('Usuario ID: $globalVendId');
        
        // Validar que se haya guardado correctamente el ID
        if (globalVendId == null || globalVendId == 0) {
          return {
            'error': true,
            'message': 'Error al procesar ID del usuario',
            'details': data,
          };
        }
        
        // PASO 3B: Iniciar precarga de productos en segundo plano después del login exitoso
        iniciarPrecargaProductos();
        
        // Ejecutar sincronización completa en background (no bloquear login)
        SincronizacionService.sincronizarTodoOfflineConClientesAuto(
          vendedorId: globalVendId ?? 0,
        ).catchError((e) {
          print('Error en sincronización background completa: $e');
        });
        return data;
      } else {
        // Status code diferente a 200
        developer.log('Error en la autenticación: ${response.statusCode}');
        
        // Intentar extraer mensaje de error del body si existe
        try {
          final errorData = jsonDecode(response.body);
          final errorMessage = errorData['message'] ?? 'Error de autenticación';
          return {
            'error': true,
            'message': errorMessage,
            'details': response.body,
          };
        } catch (e) {
          return {
            'error': true,
            'message': 'Error de autenticación: ${response.statusCode}',
            'details': response.body,
          };
        }
      }
    } catch (e) {
      developer.log('Iniciar Sesion Error: $e');
      return {'error': true, 'message': 'Error de conexión: $e'};
    }
  }

  /// Inicia la precarga de productos en segundo plano
  void iniciarPrecargaProductos() {
    developer.log(
      'UsuarioService: Iniciando precarga de productos en segundo plano',
    );
    try {
      final preloadService = ProductPreloadService();
      preloadService.preloadInBackground();
      
      // También iniciar precarga de imágenes de clientes
      SyncService.cacheClientImages();
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
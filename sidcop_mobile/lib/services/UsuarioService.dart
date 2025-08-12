import 'dart:convert';
import 'dart:developer' as developer;
import 'package:http/http.dart' as http;
import 'package:sidcop_mobile/services/Globalservice.dart';

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
        globalUsuaIdPersona = responseData['data']['usua_IdPersona'];
        developer.log('Usuario ID: $globalUsuaIdPersona');
        return responseData['data'] ?? responseData;
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

import 'dart:convert';
import 'dart:developer' as developer;
import 'package:http/http.dart' as http;
// Import corrected to match actual filename casing
import 'package:sidcop_mobile/services/GlobalService.Dart';

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

        dynamic inner = responseData['data'];
        int? extracted;
        if (inner is Map && inner['usua_IdPersona'] != null) {
          extracted = _toInt(inner['usua_IdPersona']);
        } else if (responseData['usua_IdPersona'] != null) {
          extracted = _toInt(responseData['usua_IdPersona']);
        }
        globalUsuaIdPersona = extracted;
        developer.log('globalUsuaIdPersona asignado: $globalUsuaIdPersona');

        // Devolvemos el map "data" si existe, si no el root
        if (inner is Map<String, dynamic>) {
          return inner;
        }
        // Si inner existe pero no es tipado, intentar convertir
        if (inner is Map) {
          return inner.map((key, value) => MapEntry(key.toString(), value));
        }
        return responseData;
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

int? _toInt(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is String) {
    return int.tryParse(v);
  }
  if (v is num) return v.toInt();
  return null;
}

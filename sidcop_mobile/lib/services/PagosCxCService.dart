import 'dart:convert';
import 'dart:developer' as developer;
import 'package:http/http.dart' as http;
import 'package:sidcop_mobile/services/GlobalService.Dart';
import 'package:sidcop_mobile/models/ventas/PagosCXCViewModel.dart';
import 'package:sidcop_mobile/models/FormasDePagoViewModel.dart';

class PagoCuentasXCobrarService {
  // --- Configuración del API ---
  final String _apiServer = apiServer;
  final String _apiKey = apikey;

  // Obtener formas de pago disponibles
  Future<List<FormaPago>> getFormasPago() async {
    try {
      final url = Uri.parse('$_apiServer/FormaDePago/Listar');
      
      final headers = {
        'Content-Type': 'application/json',
        'X-Api-Key': _apiKey,
      };

      developer.log('Obteniendo formas de pago - URL: $url');

      final response = await http.get(url, headers: headers);

      developer.log('Response status: ${response.statusCode}');
      developer.log('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        
        // Verificar si la respuesta tiene la estructura con "data"
        if (decoded is Map<String, dynamic> && decoded.containsKey('data')) {
          final data = decoded['data'];
          if (data is List) {
            return data.map((item) => FormaPago.fromJson(item)).toList();
          } else {
            throw Exception('La clave "data" no es una lista.');
          }
        } 
        // Si no tiene "data", asumir que es directamente una lista
        else if (decoded is List) {
          return decoded.map((item) => FormaPago.fromJson(item)).toList();
        } else {
          throw Exception(
            'Respuesta inesperada del servidor: formato no reconocido.',
          );
        }
      } else {
        developer.log('Error al obtener formas de pago: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      developer.log('Error en getFormasPago: $e');
      return [];
    }
  }

  // Insertar un nuevo pago de cuentas por cobrar
  Future<Map<String, dynamic>> insertarPago(PagosCuentasXCobrar pago) async {
    try {
      final url = Uri.parse('$_apiServer/PagosCuentasPorCobrar/Insertar');
      
      final headers = {
        'Content-Type': 'application/json',
        'X-Api-Key': _apiKey,
      };

      final body = jsonEncode(pago.toJson());

      developer.log('Insertando pago - URL: $url');
      developer.log('Body: $body');

      final response = await http.post(
        url,
        headers: headers,
        body: body,
      );

      developer.log('Response status: ${response.statusCode}');
      developer.log('Response body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final decoded = jsonDecode(response.body);
        
        // Verificar si la respuesta tiene la estructura con "data"
        if (decoded is Map<String, dynamic>) {
          if (decoded.containsKey('data')) {
            return {
              'success': true,
              'data': decoded['data'],
              'message': 'Pago insertado correctamente'
            };
          } else {
            // Si no tiene "data", usar toda la respuesta
            return {
              'success': true,
              'data': decoded,
              'message': 'Pago insertado correctamente'
            };
          }
        } else {
          return {
            'success': true,
            'data': decoded,
            'message': 'Pago insertado correctamente'
          };
        }
      } else {
        return {
          'success': false,
          'data': null,
          'message': 'Error al insertar el pago: ${response.statusCode}'
        };
      }
    } catch (e) {
      developer.log('Error en insertarPago: $e');
      return {
        'success': false,
        'data': null,
        'message': 'Error de conexión: $e'
      };
    }
  }

  // Método auxiliar para validar los datos antes de enviar
  bool validarDatosPago(PagosCuentasXCobrar pago) {
    if (pago.cpCoId <= 0) return false;
    if (pago.pagoMonto <= 0) return false;
    if (pago.pagoFormaPago.isEmpty) return false;
    if (pago.pagoNumeroReferencia.isEmpty) return false;
    if (pago.usuaCreacion <= 0) return false;
    if (pago.foPaId <= 0) return false;
    
    return true;
  }
}
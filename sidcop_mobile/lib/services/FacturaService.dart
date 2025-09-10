import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:sidcop_mobile/services/GlobalService.Dart';

// Clase personalizada para manejar errores de inventario insuficiente
class InventarioInsuficienteException implements Exception {
  final String message;

  InventarioInsuficienteException(this.message);

  @override
  String toString() => message;
}

class FacturaService {
  final String _apiServer = apiServer;
  final String _apiKey = apikey;

  Future<List<dynamic>> getFacturas() async {
    final url = Uri.parse('$_apiServer/Facturas/Listar');

    try {
      final response = await http.get(
        url,
        headers: {'X-Api-Key': _apiKey, 'Accept': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return data['data'] as List;
        }
        throw Exception(data['message'] ?? 'Error al cargar facturas');
      } else {
        throw Exception('Error al cargar facturas: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error al conectar con el servidor: $e');
    }
  }

  Future<List<dynamic>> getFacturasDevolucionesLimite() async {
    final url = Uri.parse('$_apiServer/Facturas/ListarConLimiteDevolucion');

    try {
      final response = await http.get(
        url,
        headers: {'X-Api-Key': _apiKey, 'Accept': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return data['data'] as List;
        }
        throw Exception(data['message'] ?? 'Error al cargar facturas');
      } else {
        throw Exception('Error al cargar facturas: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error al conectar con el servidor: $e');
    }
  }

  Future<Map<String, dynamic>> insertarFactura(
    Map<String, dynamic> facturaData,
  ) async {
    final url = Uri.parse('$_apiServer/Facturas/Insertar');

    try {
      print('\n=== FACTURA SERVICE - INICIO DE PETICIÓN ===');
      print('URL ENDPOINT: $url');

      // Preparar headers
      final headers = {
        'X-Api-Key': _apiKey,
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };
      print('HEADERS: ${jsonEncode(headers)}');

      // Preparar body
      final bodyJson = json.encode(facturaData);
      print('BODY SIZE: ${bodyJson.length} caracteres');
      print('BODY CONTENT:');
      print(bodyJson);

      print('\n=== ENVIANDO PETICIÓN HTTP POST ===');
      print('ANTES DE HACER LA PETICIÓN HTTP...');
      final stopwatch = Stopwatch()..start();
      
      print('EJECUTANDO http.post...');
      final response = await http.post(url, headers: headers, body: bodyJson);
      print('HTTP POST COMPLETADO');

      stopwatch.stop();
      print('TIEMPO DE RESPUESTA: ${stopwatch.elapsedMilliseconds}ms');
      print('\n=== RESPUESTA RECIBIDA ===');
      print('STATUS CODE: ${response.statusCode}');
      print('RESPONSE HEADERS: ${response.headers}');
      print('RESPONSE BODY LENGTH: ${response.body.length} caracteres');
      print('RESPONSE BODY:');
      print(response.body);

      // Intentar parsear la respuesta JSON
      Map<String, dynamic> data;
      try {
        data = json.decode(response.body);
        print('\n=== RESPUESTA JSON PARSEADA ===');
        print('DATA KEYS: ${data.keys.toList()}');
        print('SUCCESS: ${data['success']}');
        print('MESSAGE: ${data['message']}');
        if (data['data'] != null) {
          print('DATA CONTENT: ${jsonEncode(data['data'])}');
        }
        if (data['errors'] != null) {
          print('ERRORS: ${jsonEncode(data['errors'])}');
        }
      } catch (e) {
        print('ERROR AL PARSEAR JSON: $e');
        print('RESPUESTA NO ES JSON VÁLIDO');
        throw Exception(
          'Respuesta del servidor no es JSON válido: ${response.body}',
        );
      }

      if (response.statusCode == 200 && data['success'] == true) {
        print('\n=== INSERCIÓN EXITOSA ===');
        print('SUCCESS MESSAGE: ${data['message']}');
        if (data['data'] != null) {
          print('DATOS ADICIONALES: ${jsonEncode(data['data'])}');
        }
        return data;
      } else {
        print('\n=== ERROR EN LA INSERCIÓN ===');
        print('STATUS CODE: ${response.statusCode}');
        print('SUCCESS FLAG: ${data['success']}');
        print('ERROR MESSAGE: ${data['message'] ?? 'Sin mensaje de error'}');

        // Verificar si es un error de inventario insuficiente
        String errorMessage = data['message'] ?? '';
        if (data['data'] != null && data['data']['message_Status'] != null) {
          String statusMessage = data['data']['message_Status'];
          print('STATUS MESSAGE: $statusMessage');
          if (statusMessage.contains('Inventario insuficiente para:')) {
            print('DETECTADO ERROR DE INVENTARIO INSUFICIENTE');
            throw InventarioInsuficienteException(statusMessage);
          }
        }

        if (data['errors'] != null) {
          print('DETALLES DE ERRORES: ${jsonEncode(data['errors'])}');
        }

        String finalErrorMessage = errorMessage.isNotEmpty
            ? errorMessage
            : 'Error al insertar factura: ${response.statusCode}';
        print('MENSAJE DE ERROR FINAL: $finalErrorMessage');
        throw Exception(finalErrorMessage);
      }
    } catch (e, stackTrace) {
      print('\n=== EXCEPCIÓN CAPTURADA ===');
      print('TIPO DE EXCEPCIÓN: ${e.runtimeType}');
      print('MENSAJE DE EXCEPCIÓN: $e');
      print('STACK TRACE: $stackTrace');
      
      // Verificar si es un timeout
      if (e.toString().contains('TimeoutException') || e.toString().contains('timeout')) {
        print('ERROR DE TIMEOUT DETECTADO');
      }
      
      // Verificar si es un error de conexión
      if (e.toString().contains('SocketException') || e.toString().contains('connection')) {
        print('ERROR DE CONEXIÓN DETECTADO');
      }

      if (e is InventarioInsuficienteException) {
        print('RE-LANZANDO EXCEPCIÓN DE INVENTARIO INSUFICIENTE');
        rethrow;
      }

      if (e is Exception) {
        print('RE-LANZANDO EXCEPCIÓN EXISTENTE');
        rethrow;
      }

      print('CREANDO NUEVA EXCEPCIÓN DE CONEXIÓN');
      throw Exception('Error al conectar con el servidor: $e');
    }
  }
}

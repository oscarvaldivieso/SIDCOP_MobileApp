import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:sidcop_mobile/services/GlobalService.dart';
import 'package:sidcop_mobile/models/ventas/VentaInsertarViewModel.dart';

class VentaService {
  final String _apiServer = apiServer;
  final String _apiKey = apikey;

  /// Inserta una nueva factura/venta en el sistema
  /// Recibe un [VentaInsertarViewModel] con todos los datos de la venta
  /// Retorna un Map con la respuesta del servidor o información de error
  Future<Map<String, dynamic>?> insertarFactura(
    VentaInsertarViewModel venta,
  ) async {
    final url = Uri.parse('$_apiServer/Facturas/Insertar');


    try {
      // Convertir el modelo a JSON
      final body = venta.toJson();
      final bodyJson = jsonEncode(body);


      final stopwatch = Stopwatch()..start();
      final response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json', 'X-Api-Key': _apiKey},
            body: bodyJson,
          )
          .timeout(const Duration(seconds: 30));

      stopwatch.stop();

      // Procesar la respuesta
      Map<String, dynamic> responseData;
      try {
        responseData = jsonDecode(response.body);
      } catch (e) {
        throw Exception('Respuesta del servidor no es un JSON válido');
      }

      if (response.statusCode == 200 || response.statusCode == 201) {
        return {
          'success': true,
          'data': responseData['data'] ?? responseData,
          'message': 'Factura insertada exitosamente',
          'statusCode': response.statusCode,
        };
      } else {
        final errorMsg = responseData['message'] ?? 'Error desconocido';
        return {
          'success': false,
          'error': true,
          'message': errorMsg,
          'details': response.body,
          'statusCode': response.statusCode,
        };
      }
    } on http.ClientException catch (e) {
      return {
        'success': false,
        'error': true,
        'message': 'Error de conexión: ${e.message}',
        'exception': e.toString(),
      };
    } on TimeoutException catch (e) {
      return {
        'success': false,
        'error': true,
        'message': 'Tiempo de espera agotado. Por favor, intente nuevamente.',
        'exception': e.toString(),
      };
    } catch (e, stackTrace) {
      return {
        'success': false,
        'error': true,
        'message': 'Error inesperado: $e',
        'exception': e.toString(),
        'stackTrace': stackTrace.toString(),
      };
    }
  }

  /// Método auxiliar para validar los datos de la venta antes de enviar
  bool validarVenta(VentaInsertarViewModel venta) {

    // Validaciones básicas
    if (venta.diClId <= 0) {
      return false;
    }

    if (venta.vendId <= 0) {
      return false;
    }

    if (venta.detallesFacturaInput.isEmpty) {
      return false;
    }

    // Validar que todos los productos tengan cantidad mayor a 0
    for (var detalle in venta.detallesFacturaInput) {
      if (detalle.faDeCantidad <= 0) {
        return false;
      }
    }

    return true;
  }

  /// Método para insertar factura con validación previa
  Future<Map<String, dynamic>?> insertarFacturaConValidacion(
    VentaInsertarViewModel venta,
  ) async {
    // Validar datos antes de enviar
    if (!validarVenta(venta)) {
      return {
        'success': false,
        'error': true,
        'message': 'Datos de venta no válidos',
        'validation': false,
      };
    }

    // Si la validación pasa, proceder con la inserción
    return await insertarFactura(venta);
  }

  /// Obtiene la información completa de una factura por su ID
  /// Recibe el [facturaId] de la factura a consultar
  /// Retorna un Map con la información completa de la factura o información de error
  Future<Map<String, dynamic>?> obtenerFacturaCompleta(int facturaId) async {
    final url = Uri.parse('$_apiServer/Facturas/ObtenerCompleta/$facturaId');

    try {
      final stopwatch = Stopwatch()..start();
      final response = await http
          .get(
            url,
            headers: {'Content-Type': 'application/json', 'X-Api-Key': _apiKey},
          )
          .timeout(const Duration(seconds: 30));

      stopwatch.stop();

      // Verificar si la respuesta está vacía
      if (response.body.isEmpty) {
        return {
          'success': false,
          'error': true,
          'message': 'El servidor devolvió una respuesta vacía',
          'statusCode': response.statusCode,
        };
      }

      // Verificar el Content-Type
      final contentType = response.headers['content-type'] ?? '';

      // Si no es JSON, probablemente sea un error HTML
      if (!contentType.toLowerCase().contains('application/json')) {
        if (contentType.toLowerCase().contains('text/html')) {
          return {
            'success': false,
            'error': true,
            'message':
                'El servidor devolvió una página de error HTML en lugar de JSON',
            'statusCode': response.statusCode,
            'contentType': contentType,
            'rawResponse': response.body.length > 1000
                ? '${response.body.substring(0, 1000)}...'
                : response.body,
          };
        }
      }

      // Procesar la respuesta
      Map<String, dynamic> responseData;
      try {
        // Limpiar posibles caracteres BOM o espacios en blanco
        String cleanBody = response.body.trim();
        if (cleanBody.startsWith('\uFEFF')) {
          cleanBody = cleanBody.substring(1);
        }

        responseData = jsonDecode(cleanBody);
      } catch (e) {
        if (response.body.isNotEmpty) {
          final preview = response.body.substring(
            0,
            response.body.length > 10 ? 10 : response.body.length,
          );
        }

        return {
          'success': false,
          'error': true,
          'message': 'Respuesta del servidor no es un JSON válido: $e',
          'statusCode': response.statusCode,
          'rawResponse': response.body,
          'contentType': contentType,
        };
      }

      // Verificar el código de estado HTTP
      if (response.statusCode == 200) {

        // Verificar la estructura de la respuesta según el formato esperado
        if (responseData.containsKey('success') &&
            responseData['success'] == true) {
          // Formato con success/data
          return {
            'success': true,
            'data': responseData['data'],
            'message':
                responseData['message'] ?? 'Factura obtenida exitosamente',
            'statusCode': response.statusCode,
            'code': responseData['code'],
          };
        } else if (responseData.containsKey('data')) {
          // Formato directo con data
          return {
            'success': true,
            'data': responseData['data'],
            'message':
                responseData['message'] ?? 'Factura obtenida exitosamente',
            'statusCode': response.statusCode,
            'code': responseData['code'],
          };
        } else {
          // Formato directo sin wrapper
          return {
            'success': true,
            'data': responseData,
            'message': 'Factura obtenida exitosamente',
            'statusCode': response.statusCode,
          };
        }
      } else {
        final errorMsg = responseData['message'] ?? 'Error desconocido';
        return {
          'success': false,
          'error': true,
          'message': errorMsg,
          'details': response.body,
          'statusCode': response.statusCode,
        };
      }
    } on http.ClientException catch (e) {
      return {
        'success': false,
        'error': true,
        'message': 'Error de conexión: ${e.message}',
        'exception': e.toString(),
      };
    } on TimeoutException catch (e) {
      return {
        'success': false,
        'error': true,
        'message': 'Tiempo de espera agotado. Por favor, intente nuevamente.',
        'exception': e.toString(),
      };
    } catch (e, stackTrace) {
      return {
        'success': false,
        'error': true,
        'message': 'Error inesperado: $e',
        'exception': e.toString(),
        'stackTrace': stackTrace.toString(),
      };
    }
  }

  Future<Map<String, dynamic>?> listarVentasPorVendedor(int vendedorId) async {
    final url = Uri.parse('$_apiServer/Facturas/ListarPorVendedor/$vendedorId');

    try {
      final stopwatch = Stopwatch()..start();
      final response = await http
          .get(
            url,
            headers: {'Content-Type': 'application/json', 'X-Api-Key': _apiKey},
          )
          .timeout(const Duration(seconds: 30));

      stopwatch.stop();

      // Procesar la respuesta
      Map<String, dynamic> responseData;
      try {
        responseData = jsonDecode(response.body);
      } catch (e) {
        return {
          'success': false,
          'error': true,
          'message': 'Error al procesar la respuesta del servidor',
          'details': response.body,
        };
      }

      if (response.statusCode == 200) {

        return {
          'success': true,
          'error': false,
          'message':
              responseData['message'] ?? 'Ventas obtenidas correctamente',
          'data': responseData['data'] ?? [],
          'code': responseData['code'] ?? 200,
        };
      } else {
        final errorMsg = responseData['message'] ?? 'Error desconocido';
        return {
          'success': false,
          'error': true,
          'message': errorMsg,
          'details': response.body,
          'statusCode': response.statusCode,
        };
      }
    } on http.ClientException catch (e) {
      return {
        'success': false,
        'error': true,
        'message': 'Error de conexión: ${e.message}',
        'exception': e.toString(),
      };
    } on TimeoutException catch (e) {
      return {
        'success': false,
        'error': true,
        'message': 'Tiempo de espera agotado. Por favor, intente nuevamente.',
        'exception': e.toString(),
      };
    } catch (e, stackTrace) {
      return {
        'success': false,
        'error': true,
        'message': 'Error inesperado: $e',
        'exception': e.toString(),
        'stackTrace': stackTrace.toString(),
      };
    }
  }
}

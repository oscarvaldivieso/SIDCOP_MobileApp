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

    print(' [VentaService] Iniciando inserción de factura');
    print(' [VentaService] URL: $url');
    print(' [VentaService] API Key: ${_apiKey.substring(0, 5)}...');

    try {
      // Convertir el modelo a JSON
      print(' [VentaService] Convirtiendo modelo a JSON...');
      final body = venta.toJson();
      final bodyJson = jsonEncode(body);

      print(' [VentaService] Enviando solicitud POST...');
      print(' [VentaService] Cuerpo de la solicitud:');
      print(bodyJson);

      final stopwatch = Stopwatch()..start();
      final response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json', 'X-Api-Key': _apiKey},
            body: bodyJson,
          )
          .timeout(const Duration(seconds: 30));

      stopwatch.stop();
      print(
        ' [VentaService] Respuesta recibida en ${stopwatch.elapsedMilliseconds}ms',
      );
      print(' [VentaService] Código de estado: ${response.statusCode}');
      print(' [VentaService] Cuerpo de la respuesta:');
      print(response.body);

      // Procesar la respuesta
      Map<String, dynamic> responseData;
      try {
        responseData = jsonDecode(response.body);
      } catch (e) {
        print(' [VentaService] Error al decodificar la respuesta JSON: $e');
        throw Exception('Respuesta del servidor no es un JSON válido');
      }

      if (response.statusCode == 200 || response.statusCode == 201) {
        print(' [VentaService] Factura insertada exitosamente');
        return {
          'success': true,
          'data': responseData['data'] ?? responseData,
          'message': 'Factura insertada exitosamente',
          'statusCode': response.statusCode,
        };
      } else {
        final errorMsg = responseData['message'] ?? 'Error desconocido';
        print(
          ' [VentaService] Error al insertar factura (${response.statusCode}): $errorMsg',
        );
        return {
          'success': false,
          'error': true,
          'message': errorMsg,
          'details': response.body,
          'statusCode': response.statusCode,
        };
      }
    } on http.ClientException catch (e) {
      print(' [VentaService] Error de conexión: ${e.message}');
      return {
        'success': false,
        'error': true,
        'message': 'Error de conexión: ${e.message}',
        'exception': e.toString(),
      };
    } on TimeoutException catch (e) {
      print(' [VentaService] Tiempo de espera agotado: $e');
      return {
        'success': false,
        'error': true,
        'message': 'Tiempo de espera agotado. Por favor, intente nuevamente.',
        'exception': e.toString(),
      };
    } catch (e, stackTrace) {
      print(' [VentaService] Error inesperado: $e');
      print(' [VentaService] Stack trace: $stackTrace');
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
    print(' [VentaService] Validando datos de la venta...');

    // Validaciones básicas
    if (venta.diClId <= 0) {
      print(
        ' [VentaService] Validación fallida: Cliente ID no válido (${venta.diClId})',
      );
      return false;
    }

    if (venta.vendId <= 0) {
      print(
        ' [VentaService] Validación fallida: Vendedor ID no válido (${venta.vendId})',
      );
      return false;
    }

    if (venta.detallesFacturaInput.isEmpty) {
      print(
        ' [VentaService] Validación fallida: No hay productos en la factura',
      );
      return false;
    }

    // Validar que todos los productos tengan cantidad mayor a 0
    for (var detalle in venta.detallesFacturaInput) {
      if (detalle.faDeCantidad <= 0) {
        print(
          ' [VentaService] Validación fallida: Producto ${detalle.prodId} tiene cantidad inválida (${detalle.faDeCantidad})',
        );
        return false;
      }
    }

    print(' [VentaService] Validación de datos exitosa');
    print('   - Cliente ID: ${venta.diClId}');
    print('   - Vendedor ID: ${venta.vendId}');
    print('   - Productos: ${venta.detallesFacturaInput.length}');

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

    print(' [VentaService] Obteniendo factura completa');
    print(' [VentaService] URL: $url');
    print(' [VentaService] Factura ID: $facturaId');

    try {
      print(' [VentaService] Enviando solicitud GET...');

      final stopwatch = Stopwatch()..start();
      final response = await http
          .get(
            url,
            headers: {'Content-Type': 'application/json', 'X-Api-Key': _apiKey},
          )
          .timeout(const Duration(seconds: 30));

      stopwatch.stop();
      print(
        ' [VentaService] Respuesta recibida en ${stopwatch.elapsedMilliseconds}ms',
      );
      print(' [VentaService] Código de estado: ${response.statusCode}');
      print(' [VentaService] Headers: ${response.headers}');
      print(' [VentaService] Cuerpo de la respuesta (primeros 500 chars):');
      print(
        response.body.length > 500
            ? '${response.body.substring(0, 500)}...'
            : response.body,
      );

      // Verificar si la respuesta está vacía
      if (response.body.isEmpty) {
        print(' [VentaService] Error: Respuesta vacía del servidor');
        return {
          'success': false,
          'error': true,
          'message': 'El servidor devolvió una respuesta vacía',
          'statusCode': response.statusCode,
        };
      }

      // Verificar el Content-Type
      final contentType = response.headers['content-type'] ?? '';
      print(' [VentaService] Content-Type: $contentType');

      // Si no es JSON, probablemente sea un error HTML
      if (!contentType.toLowerCase().contains('application/json')) {
        print(
          ' [VentaService] Advertencia: Content-Type no es JSON: $contentType',
        );
        if (contentType.toLowerCase().contains('text/html')) {
          print(
            ' [VentaService] El servidor devolvió HTML, probablemente una página de error',
          );
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
        print(' [VentaService] JSON decodificado exitosamente');
        print(' [VentaService] Estructura de respuesta: ${responseData.keys}');
      } catch (e) {
        print(' [VentaService] Error al decodificar la respuesta JSON: $e');
        print(' [VentaService] Respuesta completa que causó el error:');
        print('--- INICIO RESPUESTA ---');
        print(response.body);
        print('--- FIN RESPUESTA ---');
        print(' [VentaService] Longitud de respuesta: ${response.body.length}');
        if (response.body.isNotEmpty) {
          final preview = response.body.substring(
            0,
            response.body.length > 10 ? 10 : response.body.length,
          );
          print(' [VentaService] Primeros caracteres: "$preview"');
          print(' [VentaService] Códigos ASCII: ${preview.codeUnits}');
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
        print(' [VentaService] Factura obtenida exitosamente');

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
        print(
          ' [VentaService] Error al obtener factura (${response.statusCode}): $errorMsg',
        );
        return {
          'success': false,
          'error': true,
          'message': errorMsg,
          'details': response.body,
          'statusCode': response.statusCode,
        };
      }
    } on http.ClientException catch (e) {
      print(' [VentaService] Error de conexión: ${e.message}');
      return {
        'success': false,
        'error': true,
        'message': 'Error de conexión: ${e.message}',
        'exception': e.toString(),
      };
    } on TimeoutException catch (e) {
      print(' [VentaService] Tiempo de espera agotado: $e');
      return {
        'success': false,
        'error': true,
        'message': 'Tiempo de espera agotado. Por favor, intente nuevamente.',
        'exception': e.toString(),
      };
    } catch (e, stackTrace) {
      print(' [VentaService] Error inesperado: $e');
      print(' [VentaService] Stack trace: $stackTrace');
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

    print(' [VentaService] Listando ventas por vendedor');
    print(' [VentaService] URL: $url');
    print(' [VentaService] Vendedor ID: $vendedorId');
    print(' [VentaService] API Key: ${_apiKey.substring(0, 5)}...');

    try {
      print(' [VentaService] Enviando solicitud GET...');

      final stopwatch = Stopwatch()..start();
      final response = await http
          .get(
            url,
            headers: {'Content-Type': 'application/json', 'X-Api-Key': _apiKey},
          )
          .timeout(const Duration(seconds: 30));

      stopwatch.stop();
      print(
        ' [VentaService] Respuesta recibida en ${stopwatch.elapsedMilliseconds}ms',
      );
      print(' [VentaService] Código de estado: ${response.statusCode}');
      print(' [VentaService] Cuerpo de la respuesta:');
      print(response.body);

      // Procesar la respuesta
      Map<String, dynamic> responseData;
      try {
        responseData = jsonDecode(response.body);
      } catch (e) {
        print(' [VentaService] Error al decodificar JSON: $e');
        return {
          'success': false,
          'error': true,
          'message': 'Error al procesar la respuesta del servidor',
          'details': response.body,
        };
      }

      if (response.statusCode == 200) {
        print(' [VentaService] Ventas obtenidas exitosamente');
        print(
          ' [VentaService] Número de ventas: ${responseData['data']?.length ?? 0}',
        );

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
        print(
          ' [VentaService] Error al obtener ventas (${response.statusCode}): $errorMsg',
        );
        return {
          'success': false,
          'error': true,
          'message': errorMsg,
          'details': response.body,
          'statusCode': response.statusCode,
        };
      }
    } on http.ClientException catch (e) {
      print(' [VentaService] Error de conexión: ${e.message}');
      return {
        'success': false,
        'error': true,
        'message': 'Error de conexión: ${e.message}',
        'exception': e.toString(),
      };
    } on TimeoutException catch (e) {
      print(' [VentaService] Tiempo de espera agotado: $e');
      return {
        'success': false,
        'error': true,
        'message': 'Tiempo de espera agotado. Por favor, intente nuevamente.',
        'exception': e.toString(),
      };
    } catch (e, stackTrace) {
      print(' [VentaService] Error inesperado: $e');
      print(' [VentaService] Stack trace: $stackTrace');
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

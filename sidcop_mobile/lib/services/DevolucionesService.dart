import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:sidcop_mobile/services/GlobalService.dart';
import 'package:sidcop_mobile/models/DevolucionesViewModel.dart';
import 'package:sidcop_mobile/models/devolucion_detalle_model.dart';
import 'package:sidcop_mobile/services/VentaService.dart';
import 'package:sidcop_mobile/models/ventas/VentaInsertarViewModel.dart';
import 'package:sidcop_mobile/services/ClientesService.Dart';

class DevolucionesService {
  final String _endpoint = 'Devoluciones';
  final String _apiServer;
  final String _apiKey;
  final VentaService _ventaService = VentaService();
  final ClientesService _clientesService = ClientesService();

  DevolucionesService() : _apiServer = apiServer, _apiKey = apikey;

  void _log(String message, {bool isError = false}) {
    // Usar print para que sea visible en la consola del navegador
    final prefix = isError ? '❌ [ERROR]' : 'ℹ️ [INFO]';
    print('$prefix $message');

    // También intentar con developer.log por si acaso
    try {
      developer.log(message, name: 'DevolucionesService');
    } catch (e) {
      // Ignorar si falla
    }
  }

  Future<http.Response> _post(
    String endpoint,
    Map<String, dynamic> data,
  ) async {
    final url = '$_apiServer/$endpoint';

    // Log detallado de la petición
    _log('\n=== INICIO DE PETICIÓN ===');
    _log('URL: $url');
    _log('MÉTODO: POST');
    _log('HEADERS:');
    _log('- Content-Type: application/json');
    _log('- X-Api-Key: ${_apiKey.substring(0, 5)}...');
    _log('BODY ENVIADO:');
    final prettyData = JsonEncoder.withIndent('  ').convert(data);
    _log(prettyData);

    try {
      final stopwatch = Stopwatch()..start();
      http.Response response;

      try {
        _log('\nRealizando petición HTTP...');
        response = await http.post(
          Uri.parse(url),
          headers: {
            'Content-Type': 'application/json',
            'X-Api-Key': _apiKey,
            'Accept': '*/*',
          },
          body: jsonEncode(data),
        );
      } catch (error, stackTrace) {
        _log('Error en la petición HTTP:', isError: true);
        _log('Error: $error', isError: true);
        _log('Stack trace: $stackTrace', isError: true);
        rethrow;
      }

      stopwatch.stop();

      // Log detallado de la respuesta
      _log('\n=== RESPUESTA ===');
      _log('URL: $url');
      _log('Código de estado: ${response.statusCode}');
      _log('Tiempo de respuesta: ${stopwatch.elapsedMilliseconds}ms');
      _log('CABECERAS DE RESPUESTA:');
      response.headers.forEach((key, value) {
        _log('$key: $value');
      });
      _log('CUERPO DE RESPUESTA:');
      try {
        final jsonResponse = jsonDecode(response.body);
        _log(JsonEncoder.withIndent('  ').convert(jsonResponse));
      } catch (e) {
        _log(response.body);
      }
      _log('=== FIN DE RESPUESTA ===\n');

      return response;
    } catch (e, stackTrace) {
      _log('=== ERROR EN LA PETICIÓN ===', isError: true);
      _log('URL: $url', isError: true);
      _log('Error: $e', isError: true);
      _log('Stack trace: $stackTrace', isError: true);
      _log('=== FIN DE ERROR ===\n', isError: true);
      rethrow;
    }
  }

  Future<http.Response> get(String endpoint) async {
    final url = '$_apiServer/$endpoint';
    print('GET Request to: $url');
    print(
      'Headers: ${{
        'Content-Type': 'application/json',
        'X-Api-Key': '${_apiKey.substring(0, 5)}...', // Show first 5 chars for security
      }}',
    );

    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json', 'X-Api-Key': _apiKey},
      );

      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      return response;
    } catch (e) {
      print('Error in GET request: $e');
      rethrow;
    }
  }

  Future<List<DevolucionesViewModel>> listarDevoluciones() async {
    print('=== listarDevoluciones() called ===');
    try {
      final response = await get('Devoluciones/Listar');

      if (response.statusCode == 200) {
        print('Response status is 200, parsing JSON...');
        final List<dynamic> data = json.decode(response.body);
        print('Parsed ${data.length} items from response');

        if (data.isEmpty) {
          print('No data returned from API');
        } else {
          print('First item in response: ${data.first}');
        }

        final result = data
            .map((json) => DevolucionesViewModel.fromJson(json))
            .toList();

        print(
          'Successfully mapped ${result.length} DevolucionesViewModel objects',
        );
        return result;
      } else {
        final errorMsg =
            'Error al listar devoluciones: ${response.statusCode} - ${response.body}';
        print(errorMsg);
        throw Exception(errorMsg);
      }
    } catch (e) {
      final errorMsg = 'Error en listarDevoluciones: $e';
      print(errorMsg);
      throw Exception(errorMsg);
    }
  }

  Future<List<DevolucionDetalleModel>> getDevolucionDetalles(int devoId) async {
    print('=== getDevolucionDetalles() called for devoId: $devoId ===');
    try {
      final response = await get('DevolucionesDetalles/Buscar/$devoId');

      if (response.statusCode == 200) {
        print('Response status is 200, parsing JSON...');
        final List<dynamic> data = json.decode(response.body);
        print('Parsed ${data.length} items from response');

        final result = data
            .map((json) => DevolucionDetalleModel.fromJson(json))
            .toList();

        print(
          'Successfully mapped ${result.length} DevolucionDetalleModel objects',
        );
        return result;
      } else {
        final errorMsg =
            'Error al obtener detalles de devolución: ${response.statusCode} - ${response.body}';
        print(errorMsg);
        throw Exception(errorMsg);
      }
    } catch (e) {
      final errorMsg = 'Error en getDevolucionDetalles: $e';
      print(errorMsg);
      throw Exception(errorMsg);
    }
  }

  Future<Map<String, dynamic>> insertarDevolucion({
    required int clieId,
    required int factId,
    required String devoMotivo,
    required int usuaCreacion,
    required List<Map<String, dynamic>> detalles,
    DateTime? devoFecha,
    int? usuaModificacion,
    bool devoEstado = true,
  }) async {
    _log('\n=== INICIO DE insertarDevolucion ===');
    _log('clieId: $clieId');
    _log('factId: $factId');
    _log('devoMotivo: $devoMotivo');
    _log('usuaCreacion: $usuaCreacion');
    _log('devoFecha: ${devoFecha ?? 'null (usando fecha actual)'}');
    _log('usuaModificacion: $usuaModificacion');
    _log('devoEstado: $devoEstado');
    _log('DETALLES:');
    for (var i = 0; i < detalles.length; i++) {
      _log('  Producto ${i + 1}:');
      detalles[i].forEach((key, value) {
        _log('    $key: $value');
      });
    }
    try {
      // Validar que los detalles no estén vacíos
      if (detalles.isEmpty) {
        throw Exception('La devolución debe incluir al menos un producto');
      }

      // Construir el XML de detalles con la estructura esperada por la API
      final detalleXml = StringBuffer('<DevolucionDetalle>');

      for (var detalle in detalles) {
        detalleXml.write(
          '''<Producto><Prod_Id>${detalle['prod_Id']}</Prod_Id><DevD_Cantidad>${detalle['cantidadDevolver']}</DevD_Cantidad></Producto>''',
        );
      }
      detalleXml.write('</DevolucionDetalle>');

      final now = DateTime.now().toIso8601String();

      final body = {
        'devo_Id': 0,
        'clie_Id': clieId,
        'fact_Id': factId,
        'devo_Fecha': (devoFecha ?? DateTime.now()).toIso8601String(),
        'devo_Motivo': devoMotivo,
        'usua_Creacion': usuaCreacion,
        'devo_FechaCreacion': now,
        'usua_Modificacion': usuaModificacion ?? 0,
        'devo_FechaModificacion': now,
        'devo_Estado': devoEstado,
        'nombre_Completo': ' ',
        'clie_NombreNegocio': ' ',
        'usuarioCreacion': ' ',
        'usuarioModificacion': ' ',
        'devoDetalle_XML': detalleXml.toString(),
        'item': [],
      };

      final response = await _post('Devoluciones/Insertar', body);

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData is Map &&
            responseData.containsKey('success') &&
            responseData['success'] == true) {
          // Convertir el Map dinámico a Map<String, dynamic>
          return Map<String, dynamic>.from(responseData);
        } else {
          throw Exception(
            responseData['message'] ?? 'Error al procesar la devolución',
          );
        }
      } else {
        throw Exception('Error en la solicitud: ${response.statusCode}');
      }
    } catch (e) {
      developer.log('Error en insertarDevolucion: $e');
      rethrow;
    }
  }

  /// Obtiene la factura completa usando el endpoint GET /Facturas/ObtenerCompleta/{id}
  Future<Map<String, dynamic>?> obtenerFacturaCompleta(int facturaId) async {
    _log('\n=== INICIO DE obtenerFacturaCompleta ===');
    _log('facturaId: $facturaId');

    try {
      final url = '$_apiServer/Facturas/ObtenerCompleta/$facturaId';
      _log('URL: $url');

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'X-Api-Key': _apiKey,
          'Accept': '*/*',
        },
      );

      _log('Response status: ${response.statusCode}');
      _log('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['success'] == true) {
          return responseData;
        } else {
          throw Exception(
            responseData['message'] ?? 'Error al obtener factura completa',
          );
        }
      } else {
        throw Exception('Error HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      _log('Error en obtenerFacturaCompleta: $e', isError: true);
      rethrow;
    }
  }

  /// Anula una factura usando el endpoint POST /Facturas/AnularFactura
  Future<Map<String, dynamic>?> anularFactura({
    required int factId,
    required String motivo,
    required int usuaModificacion,
  }) async {
    _log('\n=== INICIO DE anularFactura ===');
    _log('factId: $factId');
    _log('motivo: $motivo');
    _log('usuaModificacion: $usuaModificacion');

    try {
      final url = '$_apiServer/Facturas/AnularFactura';
      _log('URL: $url');

      final requestBody = {
        'fact_Id': factId,
        'motivo': motivo,
        'usua_Modificacion': usuaModificacion,
      };

      _log('Request body: ${json.encode(requestBody)}');

      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'X-Api-Key': _apiKey,
          'Accept': '*/*',
        },
        body: json.encode(requestBody),
      );

      _log('Response status: ${response.statusCode}');
      _log('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['success'] == true) {
          _log('Factura anulada exitosamente');
          return responseData;
        } else {
          throw Exception(
            responseData['message'] ?? 'Error al anular la factura',
          );
        }
      } else {
        throw Exception('Error HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      _log('Error en anularFactura: $e', isError: true);
      rethrow;
    }
  }

  /// Crea una nueva factura excluyendo los productos devueltos
  Future<Map<String, dynamic>?> crearFacturaAjustada({
    required int facturaId,
    required List<Map<String, dynamic>> productosDevueltos,
    required int usuaCreacion,
  }) async {
    _log('\n=== INICIO DE crearFacturaAjustada ===');
    _log('facturaId: $facturaId');
    _log('usuaCreacion: $usuaCreacion');
    _log('productosDevueltos: $productosDevueltos');

    try {
      // 1. Obtener la factura completa original
      final facturaCompleta = await obtenerFacturaCompleta(facturaId);
      if (facturaCompleta == null) {
        throw Exception('No se pudo obtener la factura original');
      }

      final facturaData = facturaCompleta['data'];
      final detalleFacturaOriginal =
          facturaData['detalleFactura'] as List<dynamic>? ?? [];

      _log('Factura original: ${facturaData['fact_Numero']}');
      _log('Productos originales: ${detalleFacturaOriginal.length}');

      // 2. Crear mapa de productos devueltos
      final Map<int, int> productosDevueltosMap = {};
      for (var producto in productosDevueltos) {
        final prodId = producto['prod_Id'] as int;
        final cantidadDevuelta = producto['cantidadDevolver'] as int;
        productosDevueltosMap[prodId] = cantidadDevuelta;
      }

      // 3. Calcular productos restantes
      final List<DetalleFacturaInput> nuevosDetalles = [];
      for (var detalle in detalleFacturaOriginal) {
        final prodId = detalle['prod_Id'] as int;
        final cantidadOriginal = (detalle['faDe_Cantidad'] as num).toDouble();
        final cantidadDevuelta = productosDevueltosMap[prodId] ?? 0;
        final cantidadRestante = cantidadOriginal - cantidadDevuelta;

        _log(
          'Producto $prodId: original=$cantidadOriginal, devuelta=$cantidadDevuelta, restante=$cantidadRestante',
        );

        if (cantidadRestante > 0) {
          nuevosDetalles.add(
            DetalleFacturaInput(prodId: prodId, faDeCantidad: cantidadRestante),
          );
        }
      }

      // 4. Si no quedan productos, no crear factura
      if (nuevosDetalles.isEmpty) {
        _log('No hay productos restantes - Devolución completa');
        return {
          'success': true,
          'facturaCreada': false,
          'message': 'Devolución completa - no se requiere nueva factura',
        };
      }

      // 5. Obtener dirección del cliente para obtener diClId
      final clienteId = facturaData['clie_Id'] as int;
      _log('Obteniendo direcciones para cliente ID: $clienteId');

      final direcciones = await _clientesService.getDireccionesCliente(
        clienteId,
      );
      if (direcciones.isEmpty) {
        throw Exception(
          'No se encontraron direcciones para el cliente $clienteId',
        );
      }

      _log('Se encontraron ${direcciones.length} direcciones para el cliente');

      // Buscar dirección principal o usar la primera disponible
      Map<String, dynamic>? direccionSeleccionada;

      // Intentar encontrar una dirección marcada como principal
      for (var direccion in direcciones) {
        if (direccion['diCl_Principal'] == true ||
            direccion['diCl_Principal'] == 1) {
          direccionSeleccionada = direccion;
          _log('Usando dirección principal - diClId: ${direccion['diCl_Id']}');
          break;
        }
      }

      // Si no hay dirección principal, usar la primera
      if (direccionSeleccionada == null && direcciones.isNotEmpty) {
        direccionSeleccionada = direcciones.first;
        _log(
          'No se encontró dirección principal, usando la primera - diClId: ${direccionSeleccionada!['diCl_Id']}',
        );
      }

      if (direccionSeleccionada == null) {
        throw Exception(
          'No se pudo seleccionar una dirección válida para el cliente $clienteId',
        );
      }

      final diClId = direccionSeleccionada['diCl_Id'] as int;
      _log('Dirección seleccionada - diClId: $diClId');

      // 6. Generar nuevo número de factura
      final random = Random();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final randomDigits = 100000 + random.nextInt(900000);
      final nuevoNumero = 'FACT-${timestamp}_$randomDigits';

      // 7. Crear nueva factura con datos originales pero productos ajustados
      final nuevaVenta = VentaInsertarViewModel.empty()
        ..factNumero = nuevoNumero
        ..factTipoDeDocumento = facturaData['fact_TipoDeDocumento'] ?? 'FAC'

        ..regCId = 21
        ..diClId =
            diClId // Usar diClId obtenido de direcciones
        ..vendId = facturaData['vend_Id']
        ..factTipoVenta = facturaData['fact_TipoVenta'] ?? 'Contado'
        ..factFechaEmision = DateTime.now()
        ..factLatitud = facturaData['fact_Latitud']?.toDouble() ?? 14.072245
        ..factLongitud = facturaData['fact_Longitud']?.toDouble() ?? -88.212665
        ..factReferencia =
            "Ajuste por devolución - Factura original: ${facturaData['fact_Numero']}"
        ..factAutorizadoPor = facturaData['fact_AutorizadoPor'] ?? "Sistema"
        ..usuaCreacion = usuaCreacion
        ..detallesFacturaInput = nuevosDetalles;

      // 8. Insertar nueva factura ajustada PRIMERO
      _log('Creando nueva factura con ${nuevosDetalles.length} productos...');
      final resultado = await _ventaService.insertarFacturaConValidacion(
        nuevaVenta,
      );

      if (resultado != null && resultado['success'] == true) {
        _log('Factura ajustada creada exitosamente');
        _log('Respuesta del servicio: ${resultado.toString()}');

        return {
          'success': true,
          'facturaCreada': true,
          'facturaNumero': nuevoNumero,
          'facturaOriginal': facturaData['fact_Numero'],
          'productosRestantes': nuevosDetalles.length,
          'ventaServiceResponse':
              resultado, // Respuesta completa del VentaService
        };
      } else {
        throw Exception(
          resultado?['message'] ?? 'Error al crear factura ajustada',
        );
      }
    } catch (e) {
      _log('Error en crearFacturaAjustada: $e', isError: true);
      return {
        'success': false,
        'error': true,
        'message': 'Error al crear factura ajustada: $e',
      };
    }
  }

  /// Inserta devolución y crea factura ajustada en un solo proceso
  /// NUEVO ORDEN: 1) Crear factura ajustada, 2) Insertar devolución, 3) Anular factura original
  /// CON VALIDACIÓN: Si falla la factura, no se ejecutan los pasos siguientes
  Future<Map<String, dynamic>> insertarDevolucionConFacturaAjustada({
    required int clieId,
    required int factId,
    required String devoMotivo,
    required int usuaCreacion,
    required List<Map<String, dynamic>> detalles,
    DateTime? devoFecha,
    bool crearNuevaFactura = true,
  }) async {
    _log('\n=== INICIO DE insertarDevolucionConFacturaAjustada ===');
    _log('NUEVO ORDEN: Factura -> Devolución -> Anular Original');
    _log('crearNuevaFactura: $crearNuevaFactura');

    try {
      Map<String, dynamic>? resultadoFactura;

      // PASO 1: Crear factura ajustada PRIMERO - CRÍTICO
      if (crearNuevaFactura) {
        _log('PASO 1: Creando factura ajustada...');
        resultadoFactura = await crearFacturaAjustada(
          facturaId: factId,
          productosDevueltos: detalles,
          usuaCreacion: usuaCreacion,
        );

        // VALIDACIÓN CRÍTICA: Verificar que el proceso de factura fue exitoso
        if (resultadoFactura == null || resultadoFactura['success'] != true) {
          final errorMsg =
              resultadoFactura?['message'] ??
              'Error desconocido al crear factura ajustada';
          _log(
            'ERROR CRÍTICO: Proceso de factura falló: $errorMsg',
            isError: true,
          );
          throw Exception(
            'PROCESO ABORTADO: No se pudo procesar la devolucion. $errorMsg',
          );
        }

        // Verificar si se creó una nueva factura o si es devolución completa
        if (resultadoFactura['facturaCreada'] == true) {
          _log('✅ Factura ajustada creada exitosamente');
        } else {
          _log('✅ Devolución completa - No se requiere nueva factura');
        }
      }

      // PASO 2: Insertar la devolución (solo si la factura fue exitosa)
      _log('PASO 2: Insertando devolución...');
      final resultadoDevolucion = await insertarDevolucion(
        clieId: clieId,
        factId: factId,
        devoMotivo: devoMotivo,
        usuaCreacion: usuaCreacion,
        detalles: detalles,
        devoFecha: devoFecha,
      );
      _log('✅ Devolución insertada exitosamente');

      // PASO 3: Anular la factura original (solo si todo lo anterior fue exitoso)
      _log('PASO 3: Anulando factura original...');
      final facturaNumero = resultadoFactura?['facturaNumero'] ?? 'N/A';
      await anularFactura(
        factId: factId,
        motivo:
            'Anulación por devolución - Nueva factura ajustada: $facturaNumero',
        usuaModificacion: usuaCreacion,
      );
      _log('✅ Factura original anulada exitosamente');

      // 4. Retornar resultados combinados
      return {
        'success': true,
        'devolucion': resultadoDevolucion,
        'facturaAjustada': resultadoFactura,
        'message': 'Proceso completado exitosamente - Nuevo orden aplicado',
      };
    } catch (e) {
      _log(
        '❌ ERROR CRÍTICO en insertarDevolucionConFacturaAjustada: $e',
        isError: true,
      );
      _log(
        'PROCESO ABORTADO - No se ejecutaron pasos posteriores',
        isError: true,
      );

      // Retornar error estructurado
      return {
        'success': false,
        'error': true,
        'message': 'Error en proceso de devolución: $e',
        'errorDetails': e.toString(),
      };
    }
  }
}

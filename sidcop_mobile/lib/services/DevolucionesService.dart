import 'dart:convert';
import 'dart:developer' as developer;
import 'package:http/http.dart' as http;
import 'package:sidcop_mobile/services/GlobalService.dart';
import 'package:sidcop_mobile/models/DevolucionesViewModel.dart';
import 'package:sidcop_mobile/models/devolucion_detalle_model.dart';

class DevolucionesService {
  final String _endpoint = 'Devoluciones';
  final String _apiServer;
  final String _apiKey;

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

  Future<http.Response> _post(String endpoint, Map<String, dynamic> data) async {
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

  /// Inserta una nueva devolución en el sistema
  /// [clieId] - ID del cliente
  /// [factId] - ID de la factura
  /// [devoMotivo] - Motivo de la devolución
  /// [usuaCreacion] - ID del usuario que crea la devolución
  /// [detalles] - Lista de productos a devolver con sus cantidades
  /// [devoFecha] - Fecha de la devolución (opcional, por defecto es la fecha actual)
  /// [usuaModificacion] - ID del usuario que modifica (opcional)
  /// [devoEstado] - Estado de la devolución (opcional, por defecto true)
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

      // Construir el XML de detalles con la estructura completa
      final detalleXml = StringBuffer('<Detalles>');
      final now = DateTime.now().toIso8601String();
      
      int secuencia = 1;
      for (var detalle in detalles) {
        detalleXml.write('''
          <Detalle>
            <devD_Id>0</devD_Id>
            <devo_Id>0</devo_Id>
            <prod_Id>${detalle['prod_Id']}</prod_Id>
            <usua_Creacion>$usuaCreacion</usua_Creacion>
            <devD_FechaCreacion>$now</devD_FechaCreacion>
            <devD_Estado>true</devD_Estado>
            <secuencia>${secuencia++}</secuencia>
            <cate_Descripcion>${detalle['cate_Descripcion'] ?? 'Sin categoría'}</cate_Descripcion>
            <prod_Imagen>${detalle['prod_Imagen'] ?? ''}</prod_Imagen>
            <prod_Descripcion>${detalle['prod_Descripcion'] ?? ''}</prod_Descripcion>
            <productos_Devueltos>${detalle['cantidadDevolver']}</productos_Devueltos>
            <prod_DescripcionCorta>${detalle['prod_DescripcionCorta'] ?? ''}</prod_DescripcionCorta>
            <usuarioCreacion>${detalle['usuarioCreacion'] ?? 'Sistema'}</usuarioCreacion>
          </Detalle>
        ''');
      }
      detalleXml.write('</Detalles>');

      final body = {
        'Clie_Id': clieId,
        'Fact_Id': factId,
        'Devo_Motivo': devoMotivo,
        'Usua_Creacion': usuaCreacion,
        'Devo_Fecha': (devoFecha ?? DateTime.now()).toIso8601String(),
        'Devo_Estado': devoEstado,
        'Detalle': detalleXml.toString(),
        'devoDetalle_XML': detalleXml.toString(), // Añadido el campo devoDetalle_XML
        // Campos requeridos por el servidor
        'Nombre_Completo': ' ',  // Espacio en blanco como solicitado
        'UsuarioCreacion': ' ',  // Espacio en blanco como solicitado
        'Clie_NombreNegocio': ' ',  // Espacio en blanco como solicitado
        'UsuarioModificacion': ' ',  // Espacio en blanco como solicitado
        // Campo opcional
        if (usuaModificacion != null) 'Usua_Modificacion': usuaModificacion,
      };

      final response = await _post('Devoluciones/Insertar', body);
      
      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData is Map && responseData.containsKey('success') && responseData['success'] == true) {
          // Convertir el Map dinámico a Map<String, dynamic>
          return Map<String, dynamic>.from(responseData);
        } else {
          throw Exception(responseData['message'] ?? 'Error al procesar la devolución');
        }
      } else {
        throw Exception('Error en la solicitud: ${response.statusCode}');
      }
    } catch (e) {
      developer.log('Error en insertarDevolucion: $e');
      rethrow;
    }
  }
}

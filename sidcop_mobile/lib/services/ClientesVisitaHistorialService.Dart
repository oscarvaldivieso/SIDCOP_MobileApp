import 'dart:convert';
import 'dart:developer' as developer;
import 'package:http/http.dart' as http;
import 'package:sidcop_mobile/services/GlobalService.Dart';
// import 'package:sidcop_mobile/services/UsuarioService.dart';
import 'package:sidcop_mobile/models/ClientesVisitaHistorialModel.dart';
import 'package:sidcop_mobile/models/VisitasViewModel.dart';
import 'dart:io';

class ClientesVisitaHistorialService {
  // GET /ClientesVisitaHistorial/ListarVisitasPorVendedor
  Future<List<VisitasViewModel>> listarPorVendedor() async {
    final int? vendId = globalVendId;
    print('globalVendId en listarPorVendedor: $globalVendId');
    if (vendId == null) {
      throw Exception('No se encontró el id del vendedor');
    }

    try {
      // Obtener la fecha actual para filtrar
      final now = DateTime.now();
      final hoy = DateTime(now.year, now.month, now.day);

      final url = Uri.parse(
        '$_apiServer/ClientesVisitaHistorial/ListarVisitasPorVendedor?vend_Id=$vendId',
      );
      developer.log('ListarVisitasPorVendedor Request URL: $url');
      print('ListarVisitasPorVendedor Request URL: $url');

      final response = await http.get(
        url,
        headers: {'accept': '*/*', 'X-Api-Key': _apiKey},
      );

      print('ListarVisitasPorVendedor raw body: ${response.body}');

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);

        // Filtrar solo las visitas de hoy
        final visitasHoy = data.where((visita) {
          try {
            final fechaVisitaStr = visita['clVi_Fecha'] as String?;
            if (fechaVisitaStr == null) return false;

            final fechaVisita = DateTime.parse(fechaVisitaStr);
            final fechaVisitaSinHora = DateTime(
              fechaVisita.year,
              fechaVisita.month,
              fechaVisita.day,
            );

            return fechaVisitaSinHora.isAtSameMomentAs(hoy);
          } catch (e) {
            developer.log('Error al procesar fecha de visita: $e');
            return false;
          }
        }).toList();

        // Ordenar por fecha de creación (más reciente primero)
        visitasHoy.sort((a, b) {
          try {
            final fechaA = DateTime.parse(a['clVi_FechaCreacion'] ?? '');
            final fechaB = DateTime.parse(b['clVi_FechaCreacion'] ?? '');
            return fechaB.compareTo(
              fechaA,
            ); // Orden descendente (más reciente primero)
          } catch (e) {
            return 0; // Si hay error, mantener el orden original
          }
        });

        return visitasHoy.map((e) => VisitasViewModel.fromJson(e)).toList();
      } else {
        throw Exception(
          'Error al listar visitas por vendedor: Código ${response.statusCode}, Respuesta: ${response.body}',
        );
      }
    } catch (e) {
      developer.log('Error en listarPorVendedor: $e');
      rethrow;
    }
  }

  // GET /ClientesVisitaHistorial/Listar
  Future<List<ClientesVisitaHistorialModel>> listar() async {
    final url = Uri.parse('$_apiServer/ClientesVisitaHistorial/Listar');
    developer.log('Listar ClientesVisitaHistorial Request URL: $url');
    try {
      final response = await http.get(
        url,
        headers: {'accept': '*/*', 'X-Api-Key': _apiKey},
      );
      // Mostrar el body crudo en la consola (flutter run)
      print(response.body);
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data
            .map((e) => ClientesVisitaHistorialModel.fromJson(e))
            .toList();
      } else {
        throw Exception(
          'Error al listar historial: Código ${response.statusCode}, Respuesta: ${response.body}',
        );
      }
    } catch (e) {
      developer.log('Listar ClientesVisitaHistorial Error: $e');
      rethrow;
    }
  }

  // Public getters
  final String _apiServer = apiServer;
  final String _apiKey = apikey;

  // POST /ClientesVisitaHistorial/Insertar
  Future<Map<String, dynamic>> insertar(
    ClientesVisitaHistorialModel registro,
  ) async {
    final url = Uri.parse('$_apiServer/ClientesVisitaHistorial/Insertar');
    developer.log('Insertar ClientesVisitaHistorial Request URL: $url');
    final bodyMap = registro.toJson();
    try {
      final response = await http.post(
        url,
        headers: {
          'accept': '*/*',
          'X-Api-Key': _apiKey,
          'Content-Type': 'application/json',
        },
        body: jsonEncode(bodyMap),
      );
      // Imprimir cuerpo enviado y respuesta para depuración en consola
      print('Insertar request body: ${jsonEncode(bodyMap)}');
      print('Insertar response status: ${response.statusCode}');
      print('Insertar response body: ${response.body}');
      if (response.statusCode == 200 || response.statusCode == 201) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        throw Exception(
          'Error al insertar historial: Código ${response.statusCode}, Respuesta: ${response.body}',
        );
      }
    } catch (e) {
      developer.log('Insertar ClientesVisitaHistorial Error: $e');
      rethrow;
    }
  }

  // POST /ClientesVisitaHistorial/InsertarConImagenes
  Future<Map<String, dynamic>> crearVisitaConImagenes({
    required int diClId,
    required int veRuId,
    required int clieId,
    required int esViId,
    required String clViObservaciones,
    required DateTime clViFecha,
    required List<String> imagenesBase64,
  }) async {
    final int? usuaCreacion = globalVendId;
    if (usuaCreacion == null) {
      throw Exception('No se encontró el ID del usuario actual');
    }

    final url = Uri.parse('$_apiServer/ImagenVisita/Insertar');

    final Map<String, dynamic> requestBody = {
      'diCl_Id': diClId,
      'veRu_Id': veRuId,
      'clie_Id': clieId,
      'esVi_Id': esViId,
      'clVi_Observaciones': clViObservaciones,
      'clVi_Fecha': clViFecha.toIso8601String(),
      'usua_Creacion': usuaCreacion,
      'imagenesBase64': imagenesBase64,
    };

    developer.log('Crear visita con imágenes - URL: $url');
    developer.log('Request body: $requestBody');

    try {
      final response = await http.post(
        url,
        headers: {
          'accept': '*/*',
          'X-Api-Key': _apiKey,
          'Content-Type': 'application/json',
        },
        body: jsonEncode(requestBody),
      );

      developer.log('Response status: ${response.statusCode}');
      developer.log('Response body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        throw Exception(
          'Error al crear la visita: Código ${response.statusCode}, Respuesta: ${response.body}',
        );
      }
    } catch (e) {
      developer.log('Error en crearVisitaConImagenes: $e');
      rethrow;
    }
  }

  // GET /EstadoVisita/Listar
  Future<List<Map<String, dynamic>>> obtenerEstadosVisita() async {
    final url = Uri.parse('$_apiServer/EstadoVisita/Listar');
    developer.log('Obtener estados de visita - URL: $url');

    try {
      final response = await http.get(
        url,
        headers: {'accept': '*/*', 'X-Api-Key': _apiKey},
      );

      developer.log('obtenerEstadosVisita status: ${response.statusCode}');
      developer.log('obtenerEstadosVisita body: ${response.body}');

      if (response.statusCode == 200) {
        final parsed = jsonDecode(response.body);

        // Helper: try to extract a List from common wrapper shapes
        List<dynamic>? extractList(dynamic node) {
          if (node == null) return null;
          if (node is List) return node;
          if (node is Map<String, dynamic>) {
            // Common keys where a list may be placed
            for (final k in ['data', 'result', 'items', 'lista', 'estado']) {
              if (node.containsKey(k)) {
                final candidate = node[k];
                if (candidate is List) return candidate;
                // if nested map with a list inside, try deeper
                if (candidate is Map<String, dynamic>) {
                  // try common nested keys
                  for (final nk in ['data', 'items', 'lista']) {
                    if (candidate.containsKey(nk) && candidate[nk] is List) {
                      return candidate[nk] as List<dynamic>;
                    }
                  }
                }
              }
            }
            // As a last-resort, scan values for the first list
            for (final v in node.values) {
              if (v is List) return v;
            }
          }
          return null;
        }

        final extracted = extractList(parsed) ?? [];
        try {
          return List<Map<String, dynamic>>.from(extracted);
        } catch (e) {
          developer.log('Error casteando estados de visita a List<Map>: $e');
          // If cast fails, attempt to coerce each element
          final coerced = <Map<String, dynamic>>[];
          for (final item in extracted) {
            if (item is Map<String, dynamic>)
              coerced.add(item);
            else if (item is Map)
              coerced.add(Map<String, dynamic>.from(item));
          }
          return coerced;
        }
      } else {
        throw Exception(
          'Error al obtener estados de visita: Código ${response.statusCode}, Respuesta: ${response.body}',
        );
      }
    } catch (e) {
      developer.log('Error en obtenerEstadosVisita: $e');
      rethrow;
    }
  }

  Future<List<int>> obtenerRutasPorVendedor(int vendId) async {
    final url = Uri.parse('$_apiServer/Vendedores/ListarPorRutas');

    try {
      final response = await http.get(
        url,
        headers: {'accept': '*/*', 'X-Api-Key': _apiKey},
      );

      if (response.statusCode == 200) {
        final List<dynamic> rutas = jsonDecode(response.body);

        // Filtra solo las rutas del vendedor específico
        final rutasDelVendedor = rutas
            .where((item) => item['vend_Id'] == vendId)
            .map<int>((item) => item['ruta_Id'] as int)
            .toList();

        return rutasDelVendedor;
      } else {
        throw Exception('Error al obtener rutas por vendedor');
      }
    } catch (e) {
      developer.log('Error en obtenerRutasPorVendedor: $e');
      return [];
    }
  }

  // GET /clientes/listar
  Future<List<Map<String, dynamic>>> obtenerClientesPorVendedor() async {
    try {
      final vendId = globalVendId;
      if (vendId == null) throw Exception('ID del vendedor no disponible');

      // Obtener rutas con toda la info, no solo ruta_Id
      final urlRutas = Uri.parse('$_apiServer/Vendedores/ListarPorRutas');
      final resRutas = await http.get(
        urlRutas,
        headers: {'accept': '*/*', 'X-Api-Key': _apiKey},
      );

      if (resRutas.statusCode != 200) throw Exception('Error al obtener rutas');

      final List<dynamic> relacionesVendedorRuta = jsonDecode(resRutas.body);

      final rutasDelVendedor = relacionesVendedorRuta
          .where((item) => item['vend_Id'] == vendId)
          .toList();

      final rutaIds = rutasDelVendedor.map((e) => e['ruta_Id'] as int).toList();

      final resClientes = await http.get(
        Uri.parse('$_apiServer/Cliente/listar'),
        headers: {'accept': '*/*', 'X-Api-Key': _apiKey},
      );

      if (resClientes.statusCode != 200)
        throw Exception('Error al obtener clientes');

      final List<dynamic> clientes = jsonDecode(resClientes.body);

      final clientesFiltrados = clientes
          .where((cliente) {
            final rutaId = cliente['ruta_Id'];
            return rutaId != null && rutaIds.contains(rutaId);
          })
          .map<Map<String, dynamic>>((cliente) {
            final rutaId = cliente['ruta_Id'];
            final relacion = rutasDelVendedor.firstWhere(
              (rel) => rel['ruta_Id'] == rutaId,
              orElse: () => {},
            );
            return {
              ...cliente,
              'veRu_Id':
                  relacion['veRu_Id'] ?? 0, // <-- Aquí agregas el veRu_Id
            };
          })
          .toList();

      return clientesFiltrados;
    } catch (e) {
      developer.log('Error en obtenerClientesPorVendedor: $e');
      rethrow;
    }
  }

  // GET /DireccionesPorCliente/Buscar/{clieId}
  Future<List<Map<String, dynamic>>> obtenerDireccionesPorCliente(
    int clienteId,
  ) async {
    print('clienteId en obtenerDireccionesPorCliente: $clienteId');
    final url = Uri.parse(
      '$_apiServer/DireccionesPorCliente/Buscar/$clienteId',
    );

    final response = await http.get(
      url,
      headers: {'accept': '*/*', 'X-Api-Key': _apiKey},
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return List<Map<String, dynamic>>.from(data);
    } else {
      throw Exception('Error al obtener direcciones: ${response.statusCode}');
    }
  }

  // Método auxiliar para convertir archivos a base64
  Future<List<String>> convertirImagenesABase64(List<File> imagenes) async {
    final List<String> imagenesBase64 = [];

    for (final imagen in imagenes) {
      try {
        final bytes = await imagen.readAsBytes();
        final base64Image = base64Encode(bytes);
        imagenesBase64.add(base64Image);
      } catch (e) {
        developer.log('Error al convertir imagen a base64: $e');
        // Continuar con las demás imágenes si hay un error
      }
    }

    return imagenesBase64;
  }

  // 1. Insertar una nueva visita
  Future<Map<String, dynamic>> insertarVisita(
    Map<String, dynamic> visitaData,
  ) async {
    print('\n=== INICIANDO INSERCIÓN DE VISITA ===');
    print('DEBUG - INSERTANDO VISITA CON DATOS:');
    try {
      print(const JsonEncoder.withIndent('  ').convert(visitaData));
    } catch (e) {
      print('Error al imprimir datos: $e');
      print('Datos sin formato: $visitaData');
    }

    try {
      // Asegurarse de que los campos críticos están presentes
      final camposCriticos = ['clie_Id', 'diCl_Id', 'esVi_Id', 'usua_Creacion'];
      for (final campo in camposCriticos) {
        if (visitaData[campo] == null) {
          throw Exception('Campo crítico faltante: $campo');
        }
      }

      // Asegurar que usua_Creacion sea un número válido
      if ((visitaData['usua_Creacion'] is String) ||
          (visitaData['usua_Creacion'] is num &&
              (visitaData['usua_Creacion'] as num) <= 0)) {
        throw Exception(
          'usua_Creacion inválido: ${visitaData['usua_Creacion']}',
        );
      }

      final url = Uri.parse('$_apiServer/ClientesVisitaHistorial/Insertar');
      print('URL: $url');

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json', 'X-Api-Key': _apiKey},
        body: jsonEncode(visitaData),
      );

      print('\nDEBUG - RESPUESTA DE API:');
      print('Status: ${response.statusCode}');
      print('Body: ${response.body}');

      // Intentar decodificar la respuesta con mejor manejo de errores
      Map<String, dynamic>? responseData;
      try {
        responseData = jsonDecode(response.body) as Map<String, dynamic>;
      } catch (e) {
        print('Error al decodificar respuesta: $e');
        throw Exception('Respuesta inválida del servidor: ${response.body}');
      }

      if (response.statusCode == 200 || response.statusCode == 201) {
        print('RESPUESTA RECIBIDA CON ÉXITO, ANALIZANDO ESTRUCTURA...');

        if (responseData != null &&
            responseData['data'] != null &&
            responseData['data']['code_Status'] == 1) {
          // Si la respuesta tiene el formato esperado
          final clViId =
              int.tryParse(responseData['data']['data']?.toString() ?? '0') ??
              0;
          print('VISITA CREADA EXITOSAMENTE CON ID: $clViId');

          return {'clVi_Id': clViId, 'success': true};
        } else {
          print('ERROR: Respuesta con formato inesperado');
          print('Respuesta completa: $responseData');
          throw Exception('Respuesta con formato inesperado: ${response.body}');
        }
      }

      // Si llegamos aquí, hubo un error
      final errorMsg =
          responseData?['data']?['message_Status'] ??
          responseData?['message'] ??
          'Error desconocido al insertar visita';
      print('ERROR EN INSERCIÓN: $errorMsg');
      throw Exception(errorMsg);
    } catch (e) {
      print('ERROR CRÍTICO en insertarVisita: $e');
      developer.log('Error en insertarVisita: $e');
      rethrow;
    }
  }

  // 2. Obtener la lista de visitas
  Future<List<dynamic>> obtenerVisitas() async {
    try {
      final response = await http.get(
        Uri.parse('$_apiServer/ClientesVisitaHistorial/Listar'),
        headers: {'X-Api-Key': _apiKey},
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Error al obtener visitas: ${response.statusCode}');
      }
    } catch (e) {
      developer.log('Error en obtenerVisitas: $e');
      rethrow;
    }
  }

  // 3. Asociar imagen a una visita
  Future<bool> asociarImagenAVisita({
    required int visitaId,
    required String imagenUrl,
    required int usuarioId,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_apiServer/ImagenVisita/Insertar'),
        headers: {'Content-Type': 'application/json', 'X-Api-Key': _apiKey},
        body: jsonEncode({
          'ImVi_Imagen': imagenUrl,
          'ClVi_Id': visitaId,
          'Usua_Creacion': usuarioId,
          'ImVi_FechaCreacion': DateTime.now().toIso8601String(),
        }),
      );

      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      developer.log('Error en asociarImagenAVisita: $e');
      return false;
    }
  }

  // 4. Obtener la última visita creada
  Future<Map<String, dynamic>?> obtenerUltimaVisita() async {
    try {
      final visitas = await obtenerVisitas();
      if (visitas.isNotEmpty) {
        return visitas.first;
      }
      return null;
    } catch (e) {
      developer.log('Error en obtenerUltimaVisita: $e');
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> listarImagenesPorVisita(
    int visitaId,
  ) async {
    try {
      final url = Uri.parse(
        '$_apiServer/ImagenVisita/ListarPorVisita/$visitaId',
      );

      developer.log('ListarImagenesPorVisita Request URL: $url');

      final response = await http.post(
        url,
        headers: {'accept': '*/*', 'X-Api-Key': _apiKey},
      );

      developer.log('ListarImagenesPorVisita status: ${response.statusCode}');
      developer.log('ListarImagenesPorVisita body: ${response.body}');

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data);
      } else {
        throw Exception(
          'Error al cargar las imágenes de la visita: ${response.statusCode}',
        );
      }
    } catch (e) {
      developer.log('ListarImagenesPorVisita Error: $e');
      rethrow;
    }
  }
}

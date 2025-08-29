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
              fechaVisita.day
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
            return fechaB.compareTo(fechaA); // Orden descendente (más reciente primero)
          } catch (e) {
            return 0; // Si hay error, mantener el orden original
          }
        });
        
        return visitasHoy
            .map((e) => VisitasViewModel.fromJson(e))
            .toList();
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

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.cast<Map<String, dynamic>>();
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
      final response = await http.get(url, headers: {
        'accept': '*/*',
        'X-Api-Key': _apiKey,
      });

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
      final resRutas = await http.get(urlRutas, headers: {
        'accept': '*/*',
        'X-Api-Key': _apiKey,
      });

      if (resRutas.statusCode != 200) throw Exception('Error al obtener rutas');

      final List<dynamic> relacionesVendedorRuta = jsonDecode(resRutas.body);

      final rutasDelVendedor = relacionesVendedorRuta
          .where((item) => item['vend_Id'] == vendId)
          .toList();

      final rutaIds = rutasDelVendedor.map((e) => e['ruta_Id'] as int).toList();

      final resClientes = await http.get(
        Uri.parse('$_apiServer/Cliente/listar'),
        headers: {
          'accept': '*/*',
          'X-Api-Key': _apiKey,
        },
      );

      if (resClientes.statusCode != 200) throw Exception('Error al obtener clientes');

      final List<dynamic> clientes = jsonDecode(resClientes.body);

      final clientesFiltrados = clientes.where((cliente) {
        final rutaId = cliente['ruta_Id'];
        return rutaId != null && rutaIds.contains(rutaId);
      }).map<Map<String, dynamic>>((cliente) {
        final rutaId = cliente['ruta_Id'];
        final relacion = rutasDelVendedor.firstWhere(
          (rel) => rel['ruta_Id'] == rutaId,
          orElse: () => {},
        );
        return {
          ...cliente,
          'veRu_Id': relacion['veRu_Id'] ?? 0, // <-- Aquí agregas el veRu_Id
        };
      }).toList();

      return clientesFiltrados;
    } catch (e) {
      developer.log('Error en obtenerClientesPorVendedor: $e');
      rethrow;
    }
  }

  // GET /DireccionesPorCliente/Buscar/{clieId}
  Future<List<Map<String, dynamic>>> obtenerDireccionesPorCliente(int clienteId) async {
    print('clienteId en obtenerDireccionesPorCliente: $clienteId');
    final url = Uri.parse('$_apiServer/DireccionesPorCliente/Buscar/$clienteId');
    
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
  Future<Map<String, dynamic>?> insertarVisita(Map<String, dynamic> visitaData) async {
    print('Insertando visita con datos: $visitaData');
    try {
      final url = Uri.parse('$_apiServer/ClientesVisitaHistorial/Insertar');
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'X-Api-Key': _apiKey,
        },
        body: jsonEncode(visitaData),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Error al insertar visita: ${response.statusCode}');
      }
    } catch (e) {
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
        headers: {
          'Content-Type': 'application/json',
          'X-Api-Key': _apiKey,
        },
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
}
import 'dart:convert';
import 'dart:developer' as developer;
import 'package:http/http.dart' as http;
import 'package:sidcop_mobile/services/GlobalService.Dart';
import 'package:sidcop_mobile/services/UsuarioService.dart';
import 'package'
import 'package:sidcop_mobile/models/VisitasViewModel.dart';

class ClientesVisitaHistorialService {
  // GET /ClientesVisitaHistorial/ListarVisitasPorVendedor
  Future<List<VisitasViewModel>> listarPorVendedor() async {
    final int? vendId = globalVendId;
    print('globalVendId en listarPorVendedor: $globalVendId');
    if (vendId == null) {
      throw Exception('No se encontró el id del vendedor'); 
    }
    final url = Uri.parse(
      '$_apiServer/ClientesVisitaHistorial/ListarVisitasPorVendedor?vend_Id=$vendId',
    );
    developer.log('ListarVisitasPorVendedor Request URL: $url');
    print('ListarVisitasPorVendedor Request URL: $url');
  
    try {
      final response = await http.get(
        url,
        headers: {'accept': '*/*', 'X-Api-Key': _apiKey},
      );
      // Mostrar el body crudo en la consola (flutter run)
      print('ListarVisitasPorVendedor raw body: ${response.body}');
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data
            .map((e) => VisitasViewModel.fromJson(e))
            .toList();
      } else {
        throw Exception(
          'Error al listar visitas por vendedor: Código ${response.statusCode}, Respuesta: ${response.body}',
        );
      }
    } catch (e) {
      developer.log('ListarVisitasPorVendedor Error: $e');
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
}

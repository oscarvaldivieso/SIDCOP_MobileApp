import 'dart:convert';
import 'dart:developer' as developer;
import 'package:http/http.dart' as http;
import 'package:sidcop_mobile/services/GlobalService.Dart';
import 'package:sidcop_mobile/models/ClientesVisitaHistorialModel.Dart';

class ClientesVisitaHistorialService {
  // GET /ClientesVisitaHistorial/ListarVisitasPorVendedor
  Future<List<ClientesVisitaHistorialModel>> listarPorVendedor() async {
    final int? vendId = globalVendId;
    if (vendId == null) {
      throw Exception('No se encontró el id del vendedor');
    }
    final url = Uri.parse(
      '$_apiServer/ClientesVisitaHistorial/ListarVisitasPorVendedor?vend_Id=$vendId',
    );
    developer.log('ListarVisitasPorVendedor Request URL: $url');
    try {
      final response = await http.get(
        url,
        headers: {'accept': '*/*', 'X-Api-Key': _apiKey},
      );
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data
            .map((e) => ClientesVisitaHistorialModel.fromJson(e))
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
      developer.log(
        'Insertar ClientesVisitaHistorial Status: ${response.statusCode}',
      );
      developer.log('Insertar ClientesVisitaHistorial Body: ${response.body}');
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

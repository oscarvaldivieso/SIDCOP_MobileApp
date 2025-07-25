import 'dart:convert';
import 'dart:developer' as developer;
import 'package:http/http.dart' as http;
import 'package:sidcop_mobile/services/GlobalService.dart';
import 'package:sidcop_mobile/models/RecargasViewModel.dart'; 

class RecargasService 
{
  final String _apiServer = apiServer;
  final String _apiKey = apikey;

  Future<List<RecargasViewModel>> getRecargas(int personaId) async 
  {
    final url = Uri.parse('$_apiServer/Recargas/Listar');
  //  final url = Uri.parse('https://$_apiServer/Recargas/ListarVendedor/$personaId');

    try
    {
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json', 
          'X-Api-Key': _apiKey
        },
      );

      developer.log('Get Recargas Response Status: ${response.statusCode}');
      developer.log('Get Recargas Response Body: ${response.body}');
      print('Get Recargas Response Body: ${response.body}');

      if (response.statusCode == 200) 
      {
        final responseBody = response.body;
        if (responseBody.isEmpty) 
        {
          developer.log('Response body is empty');
          return [];
        }
        
        final decoded = jsonDecode(responseBody);
        List<dynamic> recargasList;
        if (decoded is List) {
          recargasList = decoded;
        } else if (decoded is Map<String, dynamic>) {
          // Busca una propiedad común: "data", "recargas", "result", etc.
          recargasList = decoded['data'] ?? decoded['recargas'] ?? decoded['result'] ?? [];
          if (recargasList is! List) {
            recargasList = [];
          }
        } else {
          recargasList = [];
        }
        return recargasList
            .map((json) => RecargasViewModel.fromJson(json as Map<String, dynamic>))
            .toList();

      } 
      else
      {
        throw Exception(
          'Error en la solicitud: Código ${response.statusCode}, Respuesta: ${response.body}',
        );
      }
    }
    catch (e)
    {
      developer.log('Get Recargas Error: $e');
      rethrow;
    }
  }

  Future<bool> insertarRecarga({required int usuaCreacion, required List<Map<String, dynamic>> detalles}) async {
    final url = Uri.parse('https://$_apiServer/Recargas/Insertar'); // Ajusta la ruta si es necesario
    final now = DateTime.now();
    final fechaString = now.toIso8601String();

    final body = {
      "vend_Id": 1,
      "bode_Id": 8,
      "reca_Fecha": fechaString,
      "reca_observaciones": "N/A",
      "usua_creacion": usuaCreacion,
      "reca_FechaCreacion": fechaString,
      "detalles": detalles
    };

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'X-Api-Key': _apiKey
        },
        body: jsonEncode(body),
      );
      developer.log('Insertar Recarga Response Status: ${response.statusCode}');
      developer.log('Insertar Recarga Response Body: ${response.body}');
      if (response.statusCode == 200) {
        return true;
      } else {
        developer.log('Error al insertar recarga: Código ${response.statusCode}, Respuesta: ${response.body}');
        return false;
      }
    } catch (e) {
      developer.log('Excepción al insertar recarga: ${e}');
      return false;
    }
  }
}
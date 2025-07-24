import 'dart:convert';
import 'dart:developer' as developer;
import 'package:http/http.dart' as http;
import 'package:sidcop_mobile/services/GlobalService.dart';
import 'package:sidcop_mobile/models/RecargasViewModel.dart'; 

class RecargasService 
{
  final String _apiServer = apiServer;
  final String _apiKey = apikey;

  Future<List<RecargasViewModel>> getRecargas() async 
  {
    final url = Uri.parse('$_apiServer/Recargas/Listar');

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
        
        final List<dynamic> recargasList = jsonDecode(responseBody);
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
}
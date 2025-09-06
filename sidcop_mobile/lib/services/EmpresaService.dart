import 'dart:convert';
import 'dart:developer' as developer;
import 'package:http/http.dart' as http;
import 'package:sidcop_mobile/services/GlobalService.dart';
import 'package:sidcop_mobile/models/ConfiguracionFacturaViewModel.dart'; 
import 'package:sidcop_mobile/services/PerfilUsuarioService.dart';

class EmpresaService 
{
  final String _apiServer = apiServer;
  final String _apiKey = apikey;

  Future<List<ConfiguracionFacturaViewModel>> getConfiguracionFactura() async 
  {
    final url = Uri.parse('$_apiServer/ConfiguracionFactura/Listar');

    try
    {
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json', 
          'X-Api-Key': _apiKey
        },
      );

      developer.log('Get ConfiguracionFactura Response Status: ${response.statusCode}');
      developer.log('Get ConfiguracionFactura Response Body: ${response.body}');
      print('Get ConfiguracionFactura Response Body: ${response.body}');

      if (response.statusCode == 200) 
      {
        final responseBody = response.body;
        if (responseBody.isEmpty) 
        {
          developer.log('Response body is empty');
          return [];
        }
        
        final decoded = jsonDecode(responseBody);
        List<dynamic> configuracionFacturaList;
        if (decoded is List) {
          configuracionFacturaList = decoded;
        } else if (decoded is Map<String, dynamic>) {
          configuracionFacturaList = decoded['data'] ?? decoded['configuracionFactura'] ?? decoded['result'] ?? [];
          if (configuracionFacturaList is! List) {
            configuracionFacturaList = [];
          }
        } else {
          configuracionFacturaList = [];
        }

        var config = configuracionFacturaList.map((json) => ConfiguracionFacturaViewModel.fromJson(json as Map<String, dynamic>)).toList();
        print('ConfiguracionFactura: ${config[0].coFa_NombreEmpresa}');
        return config;

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
      developer.log('Get ConfiguracionFactura Error: $e');
      rethrow;
    }
  }

}

import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:ffi';
import 'global_service.dart';

class ClientesService {
  final String _apiServer = apiServer;
  final String _apiKey = _apikey;

  Future<List<dynamic>> getClientes() async{

    final url = Uri.parse('http://$_apiServer/api/Clientes/Listar');
    developer.log('Get Clientes Request URL: $url');
    try {
        final response = await http.get(
          url,
          headers: {'Content-Type': 'application/json', 'X-Api-Key': _apikey},
        );

        developer.log('Get Clientes Response Status: ${response.statusCode}');
        developer.log('Get Clientes Response Body: ${response.body}');

        if (response.statusCode == 200) {

          final List<dynamic> clientesList = jsonDecode(response.body);
          return clientesList;

        } else {
          throw Exception(
            'Error en la solicitud: Código ${response.statusCode}, Respuesta: ${response.body}',
          );
        }
      } catch (e) {
        developer.log('Get Clientes Error: $e');
        throw Exception('Error en la solicitud: $e');
      }
  }
}




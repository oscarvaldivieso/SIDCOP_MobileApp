import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:sidcop_mobile/services/GlobalService.dart';
import 'package:sidcop_mobile/services/SyncService.dart';
import 'package:sidcop_mobile/Offline_Services/Clientes_OfflineService.dart';

class DropdownDataService {
  final String _baseUrl = '$apiServer';
  final String _apiKey = 'bdccf3f3-d486-4e1e-ab44-74081aefcdbc';

  Future<List<dynamic>> getCanales() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/Canal/Listar'),
        headers: {'accept': '*/*', 'X-Api-Key': _apiKey},
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as List;
      } else {
        throw Exception('Failed to load canales');
      }
    } catch (e) {
      print('Error fetching canales: $e');
      return [];
    }
  }

  Future<List<dynamic>> getEstadosCiviles() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/EstadosCiviles/Listar'),
        headers: {'accept': '*/*', 'X-Api-Key': _apiKey},
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as List;
      } else {
        throw Exception('Failed to load estados civiles');
      }
    } catch (e) {
      print('Error fetching estados civiles: $e');
      return [];
    }
  }

  Future<List<dynamic>> getRutas() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/Rutas/Listar'),
        headers: {'accept': '*/*', 'X-Api-Key': _apiKey},
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as List;
      } else {
        throw Exception('Failed to load rutas');
      }
    } catch (e) {
      print('Error fetching rutas: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> insertCliente(
    Map<String, dynamic> clienteData,
  ) async {
    try {
      // Set default values if not provided
      clienteData['clie_FechaCreacion'] = DateTime.now().toIso8601String();
      clienteData['clie_DNI'] = clienteData['clie_DNI'] ?? '';
      clienteData['clie_RTN'] = clienteData['clie_RTN'] ?? '';
      clienteData['clie_Nacionalidad'] =
          clienteData['clie_Nacionalidad'] ?? 'HND';
      clienteData['clie_Imagen'] = clienteData['clie_Imagen'] ?? '';

      final hasConnection = await SyncService.hasInternetConnection();

      if (hasConnection) {
        print('Enviando datos del cliente al servidor: $clienteData');

        final response = await http.post(
          Uri.parse('$_baseUrl/Cliente/Insertar'),
          headers: {
            'accept': '*/*',
            'X-Api-Key': _apiKey,
            'Content-Type': 'application/json',
          },
          body: jsonEncode(clienteData),
        );

        if (response.statusCode == 200) {
          final responseData = jsonDecode(response.body);
          print('Respuesta del servidor: $responseData');
          return responseData;
        } else {
          print(
            'Error del servidor: ${response.statusCode} - ${response.body}',
          );
          return {
            'success': false,
            'message': 'Error del servidor: ${response.statusCode}',
          };
        }
      } else {
        // Guardar cliente localmente si no hay conexión
        await ClientesOfflineService.guardarClientesPendientes([clienteData]);
        return {
          'success': false,
          'message':
              'Cliente guardado localmente. Se sincronizará cuando haya conexión.',
        };
      }
    } catch (e) {
      print('Error en insertCliente: $e');
      return {'success': false, 'message': 'Error al insertar cliente: $e'};
    }
  }
}

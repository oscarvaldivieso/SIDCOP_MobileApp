import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:sidcop_mobile/services/GlobalService.Dart';

class GoalsService {
  final String _apiServer = apiServer;
  final String _apiKey = apikey;

  Future<List<dynamic>?> getGoalsByVendor(int vendorId) async {
    final url = '$_apiServer/Metas/ListarPorVendedor/$vendorId';
    debugPrint('[GoalsService] Solicitando metas para el vendedor: $vendorId');
    debugPrint('[GoalsService] URL: $url');
    
    try {
      final response = await http.put(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'X-Api-Key': _apiKey,
          'accept': '*/*',
        },
      );

      debugPrint('[GoalsService] Código de estado: ${response.statusCode}');
      debugPrint('[GoalsService] Cuerpo de respuesta: ${response.body}');

      if (response.statusCode == 200) {
        try {
          final List<dynamic> data = json.decode(response.body);
          debugPrint('[GoalsService] Metas obtenidas: ${data.length}');
          return data;
        } catch (e) {
          debugPrint('[GoalsService] Error al decodificar la respuesta: $e');
          return null;
        }
      } else {
        debugPrint('[GoalsService] Error en la respuesta: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e, stackTrace) {
      debugPrint('[GoalsService] Excepción al obtener metas: $e');
      debugPrint('Stack trace: $stackTrace');
      return null;
    }
  }
}
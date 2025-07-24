import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/inventory_item.dart';
import 'GlobalService.dart';

class InventoryService {
  final String _apiServer = apiServer;
  final String _apiKey = apikey;

  Future<List<InventoryItem>> getInventoryByVendor(int vendorId) async {
    final url = Uri.parse('$_apiServer/InventarioBodegas/Buscar/$vendorId');
    try {
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'X-Api-Key': _apiKey,
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> jsonData = json.decode(response.body);
        return jsonData.map((item) => InventoryItem.fromJson(item)).toList();
      } else {
        throw Exception('Failed to load inventory: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching inventory: $e');
    }
  }
}

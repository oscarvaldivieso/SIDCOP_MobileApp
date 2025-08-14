import 'dart:convert';
import 'dart:developer' as developer;
import 'package:http/http.dart' as http;
import 'package:sidcop_mobile/services/global_service.dart' as globals;
import 'package:sidcop_mobile/models/vendedoresViewModel.dart';

class VendedoresService {
  final String _apiServer = apiServer;
  final String _apiKey = apikey;

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'accept': 'application/json',
    'X-Api-Key': _apiKey,
  };

  Uri _uri(String path) => Uri.parse('$_apiServer$path');

  Future<List<VendedoresViewModel>> listar() async {
    final url = _uri('/Vendedores/Listar');
    developer.log('GET Vendedores -> $url');
    final resp = await http.get(url, headers: _headers);
    developer.log(
      'Resp ${resp.statusCode}: ${resp.body.substring(0, resp.body.length.clamp(0, 500))}',
    );
    if (resp.statusCode == 200) {
      final data = jsonDecode(resp.body);
      if (data is List) {
        return data
            .whereType<Map<String, dynamic>>()
            .map((e) => VendedoresViewModel.fromJson(e))
            .toList();
      }
      throw Exception('Formato inesperado listar vendedores');
    }
    throw Exception('Error listar vendedores: ${resp.statusCode}');
  }
}

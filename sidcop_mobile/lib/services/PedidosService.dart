import 'dart:convert';
import 'dart:developer' as developer;
import 'package:http/http.dart' as http;
import 'package:sidcop_mobile/services/GlobalService.dart';
import 'package:sidcop_mobile/models/PedidosViewModel.Dart';
import 'package:sidcop_mobile/models/ProductosPedidosViewModel.dart';

class PedidosService {
  final String _apiServer = apiServer;
  final String _apiKey = apikey;

  Future<List<PedidosViewModel>> getPedidos() async {
    final url = Uri.parse('$_apiServer/Pedido/Listar');
    try {
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'X-Api-Key': _apiKey,
        },
      );
      developer.log('Get Pedidos Response Status: \\${response.statusCode}');
      developer.log('Get Pedidos Response Body: \\${response.body}');
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => PedidosViewModel.fromJson(json)).toList();
      } else {
        return [];
      }
    } catch (e) {
      developer.log('Error fetching pedidos: \\${e.toString()}');
      return [];
    }
  }

  Future<List<ProductosPedidosViewModel>> getProductosConListaPrecio(int clienteId) async {
    final url = Uri.parse('$_apiServer/Productos/ListaPrecio/$clienteId');
    try {
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'X-Api-Key': _apiKey,
        },
      );
      developer.log('Get Productos ListaPrecio Response Status: \\${response.statusCode}');
      developer.log('Get Productos ListaPrecio Response Body: \\${response.body}');
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => ProductosPedidosViewModel.fromJson(json)).toList();
      } else {
        return [];
      }
    } catch (e) {
      developer.log('Error fetching productos con lista precio: \\${e.toString()}');
      return [];
    }
  }
}

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
      print('Get Pedidos Response Status: \\${response.statusCode}');
      print('Get Pedidos Response Body: \\${response.body}');
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => PedidosViewModel.fromJson(json)).toList();
      } else {
        return [];
      }
    } catch (e) {
      print('Error fetching pedidos: \\${e.toString()}');
      return [];
    }
  }


  Future<List<ProductosPedidosViewModel>> getProductosConListaPrecio(int clienteId) async {
    print('Get Productos ListaPrecio clienteId: $clienteId');
    final url = Uri.parse('$_apiServer/Productos/ListaPrecio/$clienteId');
    try {
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'X-Api-Key': _apiKey,
        },
      );
      print('Get Productos ListaPrecio Response Status: ${response.statusCode}');
      print('Get Productos ListaPrecio Response Body: ${response.body}');
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        print('Get Productos ListaPrecio Response Data: ${data}');

        final List<ProductosPedidosViewModel> productos = data.map((json)=> ProductosPedidosViewModel.fromJson(json)).toList();
        final ProdList = productos.map((p) => p.toJson()).toList();
        print('Get Productos ListaPrecio Response Productos: ${ProdList}');
        return productos;
      } else {
        return [];
      }
    } catch (e) {
      print('Error fetching productos con lista precio: ${e.toString()}');
      return [];
    }
  }

  Future<Map<String, dynamic>> insertarPedido({
    required int diClId,
    required int vendId,
    required String pediCodigo,
    required DateTime fechaPedido,
    required DateTime fechaEntrega,
    required int usuaCreacion,
    required int clieId,
    required List<Map<String, dynamic>> detalles,
  }) async {
    print('Insertando pedido - Cliente: $clieId, DiCl: $diClId, Vendedor: $vendId');
    final url = Uri.parse('$_apiServer/Pedido/Insertar');
    
    final body = {
      "secuencia": 0,
      "pedi_Id": 0,
      "pedi_Codigo": pediCodigo,
      "diCl_Id": diClId,
      "vend_Id": vendId,
      "pedi_FechaPedido": fechaPedido.toIso8601String(),
      "pedi_FechaEntrega": fechaEntrega.toIso8601String(),
      "usua_Creacion": usuaCreacion,
      "pedi_FechaCreacion": DateTime.now().toIso8601String(),
      "usua_Modificacion": 0,
      "pedi_FechaModificacion": DateTime.now().toIso8601String(),
      "pedi_Estado": true,
      "clie_Codigo": "",
      "clie_Id": clieId,
      "clie_NombreNegocio": "",
      "clie_Nombres": "",
      "clie_Apellidos": "",
      "colo_Descripcion": "",
      "muni_Descripcion": "",
      "depa_Descripcion": "",
      "diCl_DireccionExacta": "",
      "vend_Nombres": "",
      "vend_Apellidos": "",
      "usuarioCreacion": "",
      "usuarioModificacion": "",
      "prod_Codigo": "",
      "prod_Descripcion": "",
      "peDe_ProdPrecio": 0,
      "peDe_Cantidad": 0,
      "detalles": detalles,
      "detallesJson": ""
    };

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'X-Api-Key': _apiKey,
        },
        body: json.encode(body),
      );
      
      print('Insertar Pedido Response Status: ${response.statusCode}');
      print('Insertar Pedido Response Body: ${response.body}');
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        return {
          'success': true,
          'data': json.decode(response.body),
          'message': 'Pedido creado exitosamente'
        };
      } else {
        return {
          'success': false,
          'error': 'Error del servidor: ${response.statusCode}',
          'message': 'No se pudo crear el pedido'
        };
      }
    } catch (e) {
      print('Error insertando pedido: ${e.toString()}');
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Error de conexión'
      };
    }
  }
}

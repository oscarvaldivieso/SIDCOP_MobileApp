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
        final responseData = json.decode(response.body);
        print('DEBUG API: Respuesta completa del servidor: $responseData');
        return {
          'success': true,
          'data': responseData,
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

  // Método para obtener información de una ruta por ID
  Future<Map<String, dynamic>?> getRutaById(int rutaId) async {
    final url = Uri.parse('$_apiServer/Rutas/Buscar/$rutaId');
    try {
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'X-Api-Key': _apiKey,
        },
      );
      
      print('Get Ruta Response Status: ${response.statusCode}');
      print('Get Ruta Response Body: ${response.body}');
      
      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        print('Error al obtener ruta: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('Error fetching ruta: ${e.toString()}');
      return null;
    }
  }

  // Método para generar el siguiente código de pedido
  Future<String> generarSiguienteCodigo({
    required int diClId,
    required List<dynamic> direcciones,
    required List<dynamic> clientes,
  }) async {
    try {
      // 1. Encontrar la dirección seleccionada
      final direccionSeleccionada = direcciones.firstWhere(
        (d) => d['diCl_Id'] == diClId,
        orElse: () => null,
      );
      
      if (direccionSeleccionada == null) {
        print('Dirección no encontrada para diCl_Id: $diClId');
        return '';
      }
      
      final clienteId = direccionSeleccionada['clie_Id'];
      
      // 2. Encontrar el cliente
      final cliente = clientes.firstWhere(
        (c) => c['clie_Id'] == clienteId,
        orElse: () => null,
      );
      
      if (cliente == null || cliente['ruta_Id'] == null) {
        print('Cliente no encontrado o sin ruta_Id para clie_Id: $clienteId');
        return '';
      }
      
      final rutaId = cliente['ruta_Id'];
      
      // 3. Obtener información de la ruta
      final ruta = await getRutaById(rutaId);
      if (ruta == null || ruta['ruta_Codigo'] == null) {
        print('Ruta no encontrada para ruta_Id: $rutaId');
        return '';
      }
      
      final rutaCodigo = ruta['ruta_Codigo'] as String; // ej: RT-012
      final rutaCodigoNumerico = rutaCodigo.split('-')[1]; // extrae "012"
      
      // 4. Obtener todos los pedidos para filtrar códigos existentes
      final pedidos = await getPedidos();
      
      // 5. Filtrar códigos existentes de esta ruta
      final codigosRuta = pedidos
          .map((p) => p.pedi_Codigo ?? '')
          .where((c) => c.isNotEmpty && RegExp(r'^PED-' + rutaCodigoNumerico + r'-\d{8}$').hasMatch(c))
          .toList();
      
      // 6. Calcular el siguiente número
      int siguienteNumero = 1;
      if (codigosRuta.isNotEmpty) {
        codigosRuta.sort();
        final ultimoCodigo = codigosRuta.last;
        final numero = int.parse(ultimoCodigo.split('-')[2]);
        siguienteNumero = numero + 1;
      }
      
      // 7. Generar el nuevo código
      final nuevoCodigo = 'PED-$rutaCodigoNumerico-${siguienteNumero.toString().padLeft(8, '0')}';
      print('Código generado: $nuevoCodigo');
      
      return nuevoCodigo;
      
    } catch (e) {
      print('Error generando código de pedido: ${e.toString()}');
      return '';
    }
  }
}

import 'dart:convert';
import 'dart:developer' as developer;
import 'package:http/http.dart' as http;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:sidcop_mobile/services/GlobalService.dart';
import 'package:sidcop_mobile/models/PedidosViewModel.Dart';
import 'package:sidcop_mobile/models/ProductosPedidosViewModel.dart';
import 'package:sidcop_mobile/Offline_Services/Pedidos_OfflineService.dart';

class PedidosService {
  final String _apiServer = apiServer;
  final String _apiKey = apikey;

  Future<List<PedidosViewModel>> getPedidos() async {
    try {
      // Check connectivity
      final connectivityResult = await Connectivity().checkConnectivity();
      final isOnline = connectivityResult != ConnectivityResult.none;
      
      if (isOnline) {
        // Try to get from server first
        try {
          final url = Uri.parse('$_apiServer/Pedido/Listar');
          final response = await http.get(
            url,
            headers: {
              'Content-Type': 'application/json',
              'X-Api-Key': _apiKey,
            },
          );
      print('Get Pedidos Response Status: \\${response.statusCode}');
      print('Get Pedidos Response Body: \\${response.body}');
          if (response.statusCode == 200) 
            final List<dynamic> data = json.decode(response.body);
            final pedidos = data.map((json) => PedidosViewModel.fromJson(json)).toList();
            
            // Save to cache for offline use
            await PedidosOfflineService.guardarPedidosEnCache(pedidos);
            
            // Get any pending offline pedidos and combine
            final pedidosPendientes = await PedidosOfflineService.obtenerPedidosPendientes();
            return [...pedidosPendientes, ...pedidos];
          }
        } catch (e) {
          print('Error fetching pedidos from server: $e');
          // Continue to return cached data if available
        }
      }
      
      // If offline or error, return cached data
      final pedidosCache = await PedidosOfflineService.obtenerPedidosDeCache();
      final pedidosPendientes = await PedidosOfflineService.obtenerPedidosPendientes();
      return [...pedidosPendientes, ...pedidosCache];
      
    } catch (e) {
      print('Error in getPedidos: $e');
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

  Future<Map<String, dynamic>> crearPedido(PedidosViewModel pedido) async {
    try {
      // Check connectivity
      final connectivityResult = await Connectivity().checkConnectivity();
      final isOnline = connectivityResult != ConnectivityResult.none;

      if (isOnline) {
        // If online, try to create the order on the server
        final url = Uri.parse('$_apiServer/Pedido/Insertar');
        
        final response = await http.post(
          url,
          headers: {
            'Content-Type': 'application/json',
            'X-Api-Key': _apiKey,
          },
          body: json.encode(pedido.toJson()),
        );
        
        print('Insertar Pedido Response Status: ${response.statusCode}');
        print('Insertar Pedido Response Body: ${response.body}');
        
        if (response.statusCode == 200 || response.statusCode == 201) {
          final responseData = json.decode(response.body);
          return {
            'success': true,
            'data': responseData,
            'message': 'Pedido creado exitosamente'
          };
        } else {
          // If server error, save to offline
          await PedidosOfflineService.guardarPedidoPendiente(pedido);
          return {
            'success': false,
            'offline': true,
            'message': 'Se guardó localmente para sincronizar más tarde',
            'data': pedido.toJson()
          };
        }
      } else {
        // If offline, save to local storage
        await PedidosOfflineService.guardarPedidoPendiente(pedido);
        return {
          'success': true,
          'offline': true,
          'message': 'Pedido guardado localmente para sincronizar cuando haya conexión',
          'data': pedido.toJson()
        };
      }
    } catch (e) {
      // On any error, try to save offline
      try {
        await PedidosOfflineService.guardarPedidoPendiente(pedido);
        return {
          'success': true,
          'offline': true,
          'message': 'Error de conexión. Pedido guardado localmente: ${e.toString()}',
          'data': pedido.toJson()
        };
      } catch (saveError) {
        print('Error saving order offline: $saveError');
        return {
          'success': false,
          'error': 'Error al guardar el pedido: ${e.toString()}',
          'message': 'No se pudo guardar el pedido'
        };
      }
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
    
    // Create PedidosViewModel from parameters
    final pedido = PedidosViewModel(
      pedi_Id: 0, // Will be set by the server or offline service
      pedi_Codigo: pediCodigo,
      diCl_Id: diClId,
      vend_Id: vendId,
      pedi_FechaPedido: fechaPedido.toIso8601String(),
      pedi_FechaEntrega: fechaEntrega.toIso8601String(),
      usua_Creacion: usuaCreacion,
      pedi_FechaCreacion: DateTime.now().toIso8601String(),
      pedi_Estado: true,
      clie_Id: clieId,
      detalles: detalles,
      detallesJson: jsonEncode(detalles),
      // Other required fields with default values
      coFa_NombreEmpresa: "",
      coFa_DireccionEmpresa: "",
      coFa_RTN: "",
      coFa_Correo: "",
      coFa_Telefono1: "",
      coFa_Telefono2: "",
      coFa_Logo: "",
      secuencia: 0,
      usua_Modificacion: 0,
      pedi_FechaModificacion: "",
      clie_Codigo: "",
      clie_NombreNegocio: "",
      clie_Nombres: "",
      clie_Apellidos: "",
      colo_Descripcion: "",
      muni_Descripcion: "",
      depa_Descripcion: "",
      diCl_DireccionExacta: "",
      vend_Nombres: "",
      vend_Apellidos: "",
      usuarioCreacion: "",
      usuarioModificacion: "",
      prod_Codigo: "",
      prod_Descripcion: "",
      peDe_ProdPrecio: 0,
      peDe_Cantidad: 0,
    );

    return await crearPedido(pedido);
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
          .where((c) => c.isNotEmpty && RegExp(r'^PED-' + rutaCodigoNumerico + r'-\d{7}$').hasMatch(c))
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
      final nuevoCodigo = 'PED-$rutaCodigoNumerico-${siguienteNumero.toString().padLeft(7, '0')}';
      print('Código generado: $nuevoCodigo');
      
      return nuevoCodigo;
      
    } catch (e) {
      print('Error generando código de pedido: ${e.toString()}');
      return '';
    }
  }

  // Sincronizar pedidos pendientes
  Future<int> sincronizarPedidosPendientes() async {
    return await PedidosOfflineService.sincronizarPedidosPendientes();
  }
}

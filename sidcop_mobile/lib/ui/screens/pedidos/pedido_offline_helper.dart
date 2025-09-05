import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:sidcop_mobile/Offline_Services/Pedidos_OfflineService.dart';
import 'package:sidcop_mobile/models/PedidosViewModel.Dart';
import 'package:sidcop_mobile/services/PedidosService.Dart';

class PedidoOfflineHelper {
  final PedidosService _pedidosService = PedidosService();

  /// Verifica si hay conexión a internet
  static Future<bool> tieneConexion() async {
    var connectivityResult = await Connectivity().checkConnectivity();
    return connectivityResult != ConnectivityResult.none;
  }

  /// Obtiene la lista de pedidos, ya sea del servidor o del almacenamiento local
  static Future<List<PedidosViewModel>> obtenerPedidos() async {
    try {
      final tieneInternet = await tieneConexion();

      if (tieneInternet) {
        // Si hay conexión, obtener del servidor
        final pedidosService = PedidosService();
        final pedidos = await pedidosService.getPedidos();

        // Guardar localmente para uso offline
        if (pedidos.isNotEmpty) {
          await PedidosScreenOffline.guardarPedidos(pedidos);
        }

        return pedidos;
      } else {
        // Si no hay conexión, obtener del almacenamiento local
        return await PedidosScreenOffline.obtenerPedidos();
      }
    } catch (e) {
      // En caso de error, intentar obtener del almacenamiento local
      return await PedidosScreenOffline.obtenerPedidos();
    }
  }

  /// Obtiene el detalle de un pedido, ya sea del servidor o del almacenamiento local
  static Future<PedidosViewModel?> obtenerDetallePedido(int pedidoId) async {
    try {
      final tieneInternet = await tieneConexion();

      if (tieneInternet) {
        // Si hay conexión, obtener del servidor
        final pedidosService = PedidosService();
        final pedido = await pedidosService.getPedidoDetalle(pedidoId);

        if (pedido != null) {
          await PedidosScreenOffline.guardarDetallePedido(pedido);
        }

        return pedido;
      } else {
        // Si no hay conexión, obtener del almacenamiento local
        return await PedidosScreenOffline.obtenerDetallePedido(pedidoId);
      }
    } catch (e) {
      // En caso de error, intentar obtener del almacenamiento local
      return await PedidosScreenOffline.obtenerDetallePedido(pedidoId);
    }
  }

  /// Guarda un pedido, ya sea en el servidor o localmente si no hay conexión
  static Future<Map<String, dynamic>> guardarPedido({
    required PedidosViewModel pedido,
  }) async {
    try {
      final tieneInternet = await tieneConexion();

      if (tieneInternet) {
        // Si hay conexión, guardar en el servidor
        final pedidosService = PedidosService();

        // Convertir los detalles al formato esperado
        final detalles = (pedido.detalles as List<dynamic>)
            .map((d) => d as Map<String, dynamic>)
            .toList();

        final resultado = await pedidosService.insertarPedido(
          diClId: pedido.diClId,
          vendId: pedido.vendId,
          pediCodigo:
              pedido.pedi_Codigo ??
              'PED-${DateTime.now().millisecondsSinceEpoch}',
          fechaPedido: pedido.pediFechaPedido,
          fechaEntrega:
              pedido.pediFechaEntrega ??
              DateTime.now().add(const Duration(days: 1)),
          usuaCreacion: pedido.usuaCreacion,
          clieId: pedido.clieId ?? 0,
          detalles: detalles,
        );

        // Guardar localmente también
        await PedidosScreenOffline.guardarDetallePedido(pedido);

        return {
          'success': true,
          'message': 'Pedido guardado correctamente',
          'data': resultado,
        };
      } else {
        // Si no hay conexión, guardar localmente
        await PedidosScreenOffline.guardarDetallePedido(pedido);
        await PedidosScreenOffline.agregarPedidoPendiente(pedido);

        return {
          'success': true,
          'message':
              'Pedido guardado localmente. Se sincronizará cuando haya conexión.',
          'data': pedido.toJson(),
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Error al guardar el pedido: $e'};
    }
  }

  /// Sincroniza los pedidos pendientes con el servidor
  static Future<void> sincronizarPedidosPendientes() async {
    try {
      await PedidosScreenOffline.sincronizarPedidosPendientes();
    } catch (e) {
      rethrow;
    }
  }

  /// Verifica si hay pedidos pendientes de sincronización
  static Future<bool> tienePedidosPendientes() async {
    try {
      final pendientes = await PedidosScreenOffline.obtenerPedidosPendientes();
      return pendientes.isNotEmpty;
    } catch (e) {
      return false;
    }
  }
}

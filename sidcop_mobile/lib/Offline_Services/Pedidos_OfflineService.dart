import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sidcop_mobile/services/PedidosService.Dart';
import 'package:sidcop_mobile/models/PedidosViewModel.Dart';

class PedidosScreenOffline {
  static const _storage = FlutterSecureStorage();
  static const String _pedidosKey = 'pedidos_list';
  static const String _pedidoDetalleKey = 'pedido_detalle_';
  static const String _pedidosPendientesKey = 'pedidos_pendientes';

  /// Guarda la lista de pedidos en el almacenamiento seguro
  static Future<void> guardarPedidos(List<PedidosViewModel> pedidos) async {
    try {
      final listaJson = pedidos.map((pedido) => pedido.toMap()).toList();
      await _storage.write(key: _pedidosKey, value: jsonEncode(listaJson));
    } catch (e) {
      rethrow;
    }
  }

  /// Obtiene la lista de pedidos guardados localmente
  static Future<List<PedidosViewModel>> obtenerPedidos() async {
    try {
      final pedidosJson = await _storage.read(key: _pedidosKey);
      if (pedidosJson == null) return [];

      final List<dynamic> lista = jsonDecode(pedidosJson);
      return lista.map((json) => PedidosViewModel.fromJson(json)).toList();
    } catch (e) {
      return [];
    }
  }

  /// Guarda el detalle de un pedido específico
  static Future<void> guardarDetallePedido(PedidosViewModel pedido) async {
    try {
      await _storage.write(
        key: '$_pedidoDetalleKey${pedido.pediId}',
        value: jsonEncode(pedido.toMap()),
      );
    } catch (e) {
      rethrow;
    }
  }

  /// Obtiene el detalle de un pedido específico guardado localmente
  static Future<PedidosViewModel?> obtenerDetallePedido(int pedidoId) async {
    try {
      final pedidoJson = await _storage.read(
        key: '$_pedidoDetalleKey$pedidoId',
      );
      if (pedidoJson == null) return null;

      return PedidosViewModel.fromJson(jsonDecode(pedidoJson));
    } catch (e) {
      return null;
    }
  }

  /// Agrega un pedido a la lista de pendientes de sincronización
  static Future<void> agregarPedidoPendiente(PedidosViewModel pedido) async {
    try {
      final pedidosPendientes = await obtenerPedidosPendientes();
      pedidosPendientes.add(pedido);
      await _storage.write(
        key: _pedidosPendientesKey,
        value: jsonEncode(pedidosPendientes.map((p) => p.toMap()).toList()),
      );
    } catch (e) {
      rethrow;
    }
  }

  /// Obtiene la lista de pedidos pendientes de sincronización
  static Future<List<PedidosViewModel>> obtenerPedidosPendientes() async {
    try {
      final pendientesJson = await _storage.read(key: _pedidosPendientesKey);
      if (pendientesJson == null) return [];

      final List<dynamic> lista = jsonDecode(pendientesJson);
      return lista.map((json) => PedidosViewModel.fromJson(json)).toList();
    } catch (e) {
      return [];
    }
  }

  /// Elimina un pedido de la lista de pendientes después de sincronizar
  static Future<void> eliminarPedidoPendiente(int pedidoId) async {
    try {
      final pedidosPendientes = await obtenerPedidosPendientes();
      pedidosPendientes.removeWhere((p) => p.pediId == pedidoId);

      await _storage.write(
        key: _pedidosPendientesKey,
        value: jsonEncode(pedidosPendientes.map((p) => p.toMap()).toList()),
      );
    } catch (e) {
      rethrow;
    }
  }

  /// Sincroniza los pedidos pendientes con el servidor
  static Future<void> sincronizarPedidosPendientes() async {
    try {
      final pedidosService = PedidosService();
      final pedidosPendientes = await obtenerPedidosPendientes();

      for (final pedido in pedidosPendientes) {
        try {
          // Convertir los detalles del pedido al formato esperado por el servicio
          final detalles = (pedido.detalles as List<dynamic>)
              .map((d) => d as Map<String, dynamic>)
              .toList();

          // Llamar al servicio para insertar el pedido
          await pedidosService.insertarPedido(
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

          // Si se sincronizó correctamente, eliminarlo de los pendientes
          await eliminarPedidoPendiente(pedido.pediId);

          // Actualizar la lista de pedidos locales
          final pedidosActuales = await obtenerPedidos();
          pedidosActuales.removeWhere((p) => p.pediId == pedido.pediId);
          pedidosActuales.add(pedido);
          await guardarPedidos(pedidosActuales);
        } catch (e) {
          // Si falla, continuar con el siguiente pedido
          continue;
        }
      }
    } catch (e) {
      rethrow;
    }
  }
}

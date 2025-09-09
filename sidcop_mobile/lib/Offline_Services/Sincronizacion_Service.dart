import 'package:sidcop_mobile/Offline_Services/Rutas_OfflineService.dart';
import 'package:sidcop_mobile/Offline_Services/Visitas_OfflineServices.dart';
import 'package:sidcop_mobile/Offline_Services/Ventas_OfflineService.dart';
import 'package:sidcop_mobile/Offline_Services/Clientes_OfflineService.dart';

/// Servicio global para sincronizar y almacenar datos offline.
/// Llama a los servicios offline para guardar toda la información necesaria
/// cuando el usuario inicia sesión o cuando se requiera actualizar el almacenamiento local.
class SincronizacionService {
  /// Sincroniza rutas, visitas, facturas y productos con descuento de todos los clientes locales.
  /// Solo necesitas pasar el vendedorId logueado.
  static Future<void> sincronizarTodoOfflineConClientesAuto({required int vendedorId}) async {
    try {
      await RutasScreenOffline.sincronizarTodo();
      await VisitasOffline.sincronizarTodo();
      await VentasOfflineService.sincronizarTodo(vendedorId);
      // Obtener la lista de clientes guardados offline
      final clientes = await ClientesOfflineService.cargarClientes();
      final clientesIds = clientes.map((c) => c['clie_Id'] as int).toList();
      print('IDs de clientes obtenidos para sincronización: $clientesIds');
      if (clientesIds.isNotEmpty) {
        await VentasOfflineService.descargarYGuardarProductosConDescuentoDeTodosLosClientesOffline(vendedorId, clientesIds);
        print('Guardado de productos con descuento completado para todos los clientes.');
      }
      print('Sincronización offline completada.');
    } catch (e) {
      print('Error en la sincronización offline: $e');
    }
  }
}
// Llama a SincronizacionService.sincronizarTodoOfflineConClientesAuto(vendedorId: vendedorId);
// para sincronizar todo y guardar productos de todos los clientes locales.
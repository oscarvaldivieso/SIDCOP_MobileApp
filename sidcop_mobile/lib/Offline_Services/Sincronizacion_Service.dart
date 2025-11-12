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
      print('[DEBUG] Iniciando sincronización offline...');
      await RutasScreenOffline.sincronizarTodo();
      print('[DEBUG] Rutas sincronizadas');
      
      await VisitasOffline.sincronizarTodo();
      print('[DEBUG] Visitas sincronizadas');
      
      await VentasOfflineService.sincronizarTodo(vendedorId);
      print('[DEBUG] Facturas sincronizadas');
      
      // Obtener la lista de clientes guardados offline
      final clientes = await ClientesOfflineService.cargarClientes();
      final clientesIds = clientes.map((c) => c['clie_Id'] as int).toList();
      print('[DEBUG] IDs de clientes obtenidos para sincronización: $clientesIds');
      
      if (clientesIds.isNotEmpty) {
        print('[DEBUG] Iniciando descarga de productos para ${clientesIds.length} clientes...');
        await VentasOfflineService.descargarYGuardarProductosConDescuentoDeTodosLosClientesOffline(vendedorId, clientesIds);
        print('[DEBUG] Guardado de productos con descuento completado para todos los clientes.');
      } else {
        print('[DEBUG] No hay clientes guardados offline, saltando descarga de productos');
      }
      
      print('[DEBUG] ✅ Sincronización offline completada exitosamente.');
    } catch (e, stackTrace) {
      print('[DEBUG] ❌ Error en la sincronización offline: $e');
      print('[DEBUG] Stack trace: $stackTrace');
      // No relanzar para que no bloquee el login
    }
  }
}
// Llama a SincronizacionService.sincronizarTodoOfflineConClientesAuto(vendedorId: vendedorId);
// para sincronizar todo y guardar productos de todos los clientes locales.
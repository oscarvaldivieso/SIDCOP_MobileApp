import 'package:sidcop_mobile/Offline_Services/Rutas_OfflineService.dart';
import 'package:sidcop_mobile/Offline_Services/Visitas_OfflineServices.dart';
import 'package:sidcop_mobile/Offline_Services/Ventas_OfflineService.dart';

// Aquí puedes importar otros servicios offline cuando los agregues:
// import 'package:sidcop_mobile/Offline_Services/OtroOfflineService.dart';

/// Servicio global para sincronizar y almacenar datos offline.
/// Llama a los servicios offline para guardar toda la información necesaria
/// cuando el usuario inicia sesión o cuando se requiera actualizar el almacenamiento local.
class SincronizacionService {
  static Future<void> sincronizarTodoOffline({int? vendedorId}) async {
    try {
      await RutasScreenOffline.sincronizarTodo();
      await VisitasOffline.sincronizarTodo();
      if (vendedorId != null) {
        await VentasOfflineService.sincronizarTodo(vendedorId);
      }
      print('Sincronización offline completada.');
    } catch (e) {
      print('Error en la sincronización offline: $e');
    }
  }
}
/// Apartado para agregar más servicios offline:
/// 1. Importa el servicio offline arriba.
/// 2. Llama a su método de sincronización dentro de [sincronizarTodoOffline].
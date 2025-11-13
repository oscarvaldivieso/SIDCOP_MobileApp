import 'package:sidcop_mobile/Offline_Services/Rutas_OfflineService.dart';
import 'package:sidcop_mobile/Offline_Services/Visitas_OfflineServices.dart';
import 'package:sidcop_mobile/Offline_Services/Ventas_OfflineService.dart';
import 'package:sidcop_mobile/Offline_Services/Clientes_OfflineService.dart';

/// Callback para actualizar el estado de sincronización en la UI
typedef SyncProgressCallback = void Function(String message);

class SincronizacionService {
  static SyncProgressCallback? _progressCallback;

  /// Establece el callback para recibir actualizaciones de progreso
  static void setProgressCallback(SyncProgressCallback? callback) {
    _progressCallback = callback;
  }

  static void _updateProgress(String message) {
    _progressCallback?.call(message);
    print('[SYNC] $message');
  }

  /// Sincroniza rutas, visitas, facturas y productos con descuento de todos los clientes locales.
  static Future<void> sincronizarTodoOfflineConClientesAuto({required int vendedorId}) async {
    try {
      _updateProgress('Sincronizando rutas...');
      await RutasScreenOffline.sincronizarTodo();
      
      _updateProgress('Sincronizando visitas...');
      await VisitasOffline.sincronizarTodo();
      
      _updateProgress('Sincronizando facturas...');
      await VentasOfflineService.sincronizarTodo(vendedorId);
      
      final clientes = await ClientesOfflineService.cargarClientes();
      final clientesIds = clientes.map((c) => c['clie_Id'] as int).toList();
      
      if (clientesIds.isNotEmpty) {
        _updateProgress('Descargando productos para ${clientesIds.length} clientes...');
        await VentasOfflineService.descargarYGuardarProductosConDescuentoDeTodosLosClientesOffline(vendedorId, clientesIds);
        _updateProgress('✅ Todos los productos cargados correctamente');
      } else {
        _updateProgress('ℹ️ No hay clientes guardados');
      }
      
      _updateProgress('✅ Sincronización completada');
    } catch (e) {
      _updateProgress('❌ Error: $e');
    }
  }
}
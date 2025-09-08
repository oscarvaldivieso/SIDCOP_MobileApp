import 'dart:developer' as developer;
import 'package:sidcop_mobile/Offline_Services/VerificarService.dart';
import 'package:sidcop_mobile/Offline_Services/Visitas_OfflineServices.dart';
import 'package:sidcop_mobile/services/ClientesVisitaHistorialService.dart';

/// Servicio para sincronizar datos offline cuando hay conexión a internet.
/// Centraliza las funciones de sincronización para toda la aplicación.
class SincronizacionService {
  /// Verifica conexión y sincroniza las visitas pendientes si hay internet
  static Future<int> sincronizarVisitasPendientes() async {
    try {
      developer.log(' Verificando sincronización de visitas pendientes...');

      // Verificar si hay conexión a internet usando VerificarService
      final isOnline = await VerificarService.verificarConexion();

      if (!isOnline) {
        developer.log(' Sin conexión, no se pueden sincronizar visitas');
        return 0;
      }

      // Si hay conexión, sincronizar visitas pendientes
      developer.log(' Conexión detectada, sincronizando visitas pendientes...');
      final visitasSincronizadas = await VisitasOffline.sincronizarPendientes();

      if (visitasSincronizadas > 0) {
        developer.log(
          ' Sincronizadas $visitasSincronizadas visitas pendientes',
        );
      } else {
        developer.log(' No hay visitas pendientes para sincronizar');
      }

      return visitasSincronizadas;
    } catch (e) {
      developer.log(' Error sincronizando visitas pendientes: $e');
      return 0;
    }
  }

  /// Cuenta las visitas pendientes de sincronización
  static Future<int> contarVisitasPendientes() async {
    try {
      final visitas = await VisitasOffline.obtenerVisitasPendientesLocal();
      return visitas.length;
    } catch (_) {
      return 0;
    }
  }

  /// Sincroniza datos maestros (clientes, direcciones, estados) para uso offline
  static Future<bool> sincronizarDatosMaestros() async {
    try {
      developer.log(' Sincronizando datos maestros para uso offline...');

      // Verificar conexión
      final isOnline = await VerificarService.verificarConexion();
      if (!isOnline) {
        developer.log(' Sin conexión, no se pueden sincronizar datos maestros');
        return false;
      }

      bool success = true;

      // Sincronizar estados de visita
      try {
        developer.log(' Sincronizando estados de visita...');
        await VisitasOffline.sincronizarEstadosVisita();
      } catch (e) {
        developer.log('❌ Error sincronizando estados de visita: $e');
        success = false;
      }

      // Sincronizar clientes
      try {
        developer.log(' Sincronizando clientes...');
        await VisitasOffline.sincronizarClientes();
      } catch (e) {
        developer.log('❌ Error sincronizando clientes: $e');
        success = false;
      }

      // Sincronizar direcciones
      try {
        developer.log(' Sincronizando direcciones...');
        await VisitasOffline.sincronizarDirecciones();
      } catch (e) {
        developer.log(' Error sincronizando direcciones: $e');
        success = false;
      }

      return success;
    } catch (e) {
      developer.log(' Error general sincronizando datos maestros: $e');
      return false;
    }
  }

  /// Realiza una sincronización completa (bidireccional):
  /// 1. Primero sincroniza las visitas pendientes (offline → online)
  /// 2. Luego sincroniza los datos maestros (online → offline)
  static Future<Map<String, dynamic>> sincronizacionCompleta() async {
    try {
      developer.log('🔄 Iniciando sincronización bidireccional...');

      // Verificar conexión
      final isOnline = await VerificarService.verificarConexion();
      if (!isOnline) {
        return {
          'success': false,
          'message': 'Sin conexión a internet',
          'visitasSincronizadas': 0,
          'datosMaestrosSincronizados': false,
        };
      }

      // Primero subir visitas pendientes al servidor
      final visitasSincronizadas = await sincronizarVisitasPendientes();

      // Después bajar datos maestros actualizados
      final datosMaestrosSincronizados = await sincronizarDatosMaestros();

      return {
        'success': visitasSincronizadas > 0 || datosMaestrosSincronizados,
        'message': 'Sincronización completa',
        'visitasSincronizadas': visitasSincronizadas,
        'datosMaestrosSincronizados': datosMaestrosSincronizados,
      };
    } catch (e) {
      developer.log('❌ Error en sincronización completa: $e');
      return {
        'success': false,
        'message': 'Error: $e',
        'visitasSincronizadas': 0,
        'datosMaestrosSincronizados': false,
      };
    }
  }

  /// Intenta una sincronización automática si hay conexión.
  /// Ideal para llamar cuando la aplicación se inicia o vuelve a primer plano.
  static Future<void> intentarSincronizacionAutomatica() async {
    try {
      // Verificar si hay visitas pendientes sin bloquear la UI
      final pendientes = await contarVisitasPendientes();

      if (pendientes > 0) {
        developer.log(
          '🔄 Hay $pendientes visita(s) pendiente(s), intentando sincronizar automáticamente...',
        );

        // Verificar conexión y sincronizar si hay internet
        final isOnline = await VerificarService.verificarConexion();
        if (isOnline) {
          final sincronizadas = await sincronizarVisitasPendientes();
          if (sincronizadas > 0) {
            developer.log(
              ' Sincronización automática completada: $sincronizadas visitas',
            );
          }
        } else {
          developer.log(' Sin conexión para sincronización automática');
        }
      }
    } catch (e) {
      // No interrumpir el flujo de la app si falla la sincronización automática
      developer.log(' Error en sincronización automática: $e');
    }
  }

  /// Sincroniza las visitas pendientes en la aplicación
  /// Método para usar desde cualquier parte de la aplicación (splash, home, etc.)
  static Future<void> syncVisitas() async {
    try {
      // Utilizar el método sincronizarVisitasPendientes para sincronizar visitas
      final visitasSincronizadas = await sincronizarVisitasPendientes();
      if (visitasSincronizadas > 0) {
        developer.log(
          '✅ Sincronizadas $visitasSincronizadas visitas pendientes',
        );
      }
    } catch (e) {
      developer.log('❌ Error sincronizando visitas pendientes: $e');
      // No interrumpir el flujo de la app si falla la sincronización
    }
  }

  /// Sincroniza las imágenes de las visitas de hoy
  /// Descarga y almacena localmente todas las imágenes de las visitas actuales
  static Future<Map<String, dynamic>> sincronizarImagenesVisitas() async {
    try {
      developer.log('🖼️ Iniciando sincronización de imágenes de visitas...');

      // Verificar conexión
      final isOnline = await VerificarService.verificarConexion();
      if (!isOnline) {
        developer.log('❌ Sin conexión, no se pueden sincronizar imágenes');
        return {
          'success': false,
          'message': 'Sin conexión a internet',
          'visitasConImagenes': 0,
          'imagenesDescargadas': 0,
        };
      }

      // Obtener visitas del día
      final service = ClientesVisitaHistorialService();
      final visitas = await service.listarPorVendedor();

      if (visitas.isEmpty) {
        developer.log('ℹ️ No hay visitas para sincronizar imágenes');
        return {
          'success': true,
          'message': 'No hay visitas disponibles',
          'visitasConImagenes': 0,
          'imagenesDescargadas': 0,
        };
      }

      developer.log('📋 Encontradas ${visitas.length} visitas para procesar');

      // Variables para estadísticas
      int visitasConImagenes = 0;
      int totalImagenesDescargadas = 0;

      // Procesar cada visita para sincronizar sus imágenes
      for (final visita in visitas) {
        try {
          final visitaId = visita.clVi_Id ?? 0;
          if (visitaId <= 0) continue;

          developer.log('🔄 Sincronizando imágenes para visita ID: $visitaId');

          // Usar el método de VisitasOffline para sincronizar imágenes
          final imagenes = await VisitasOffline.sincronizarImagenesVisita(
            visitaId,
          );

          if (imagenes != null && imagenes.isNotEmpty) {
            visitasConImagenes++;
            totalImagenesDescargadas += imagenes.length;
            developer.log(
              '✅ Descargadas ${imagenes.length} imágenes para visita $visitaId',
            );
          } else {
            developer.log(
              'ℹ️ No se encontraron imágenes para la visita $visitaId',
            );
          }
        } catch (e) {
          developer.log('⚠️ Error sincronizando imágenes de visita: $e');
          // Continuar con la siguiente visita si hay error
        }
      }

      developer.log(
        '✅ Sincronización de imágenes completada: $visitasConImagenes visitas con imágenes, $totalImagenesDescargadas imágenes descargadas',
      );

      return {
        'success': true,
        'message': 'Sincronización de imágenes completada',
        'visitasConImagenes': visitasConImagenes,
        'imagenesDescargadas': totalImagenesDescargadas,
      };
    } catch (e) {
      developer.log('❌ Error general sincronizando imágenes de visitas: $e');
      return {
        'success': false,
        'message': 'Error: $e',
        'visitasConImagenes': 0,
        'imagenesDescargadas': 0,
      };
    }
  }
}

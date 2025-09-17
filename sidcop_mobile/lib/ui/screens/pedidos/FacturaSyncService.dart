import 'dart:convert';
import 'package:sidcop_mobile/Offline_Services/Pedidos_OfflineService.dart';
import 'package:sidcop_mobile/services/FacturaService.dart';
import 'package:sidcop_mobile/services/SyncService.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class FacturaSyncService {
  static final FacturaService _facturaService = FacturaService();
  
  /// Inicializa el sistema de sincronización automática de facturas
  static Future<void> inicializarSincronizacion() async {
    print('[SYNC] Inicializando sistema de sincronización de facturas...');
    
    // Ejecutar sincronización inicial si hay conexión
    final hasConnection = await SyncService.hasInternetConnection();
    if (hasConnection) {
      print('[SYNC] Conexión disponible. Ejecutando sincronización inicial...');
      await sincronizarFacturasPendientes();
    }
    
    // Configurar listener para cambios de conectividad
    _configurarListenerConectividad();
    
    // Programar sincronización periódica cada 10 minutos
    _programarSincronizacionPeriodica();
  }
  
  /// Configura el listener para detectar cuando regresa la conexión
  static void _configurarListenerConectividad() {
    Connectivity().onConnectivityChanged.listen((ConnectivityResult result) async {
      if (result != ConnectivityResult.none) {
        print('[SYNC] Conectividad restaurada. Verificando facturas pendientes...');
        
        // Esperar un poco para asegurar que la conexión esté estable
        await Future.delayed(const Duration(seconds: 2));
        
        final facturasPendientes = await PedidosScreenOffline.obtenerFacturasPendientes();
        if (facturasPendientes.isNotEmpty) {
          print('[SYNC] ${facturasPendientes.length} facturas pendientes encontradas. Sincronizando...');
          await PedidosScreenOffline.sincronizarFacturasPendientes();
        }
      }
    });
  }
  
  /// Programa sincronización periódica
  static void _programarSincronizacionPeriodica() {
    Stream.periodic(const Duration(minutes: 10)).listen((_) async {
      final hasConnection = await SyncService.hasInternetConnection();
      if (hasConnection) {
        final facturasPendientes = await PedidosScreenOffline.obtenerFacturasPendientes();
        if (facturasPendientes.isNotEmpty) {
          print('[SYNC] Sincronización periódica - ${facturasPendientes.length} facturas pendientes');
          await sincronizarFacturasPendientes();
        }
      }
    });
  }
  
  /// Sincroniza todas las facturas pendientes con el servidor
  static Future<int> sincronizarFacturasPendientes() async {
    try {
      print('[SYNC] Iniciando sincronización de facturas...');
      
      // Verificar conectividad
      final hasConnection = await SyncService.hasInternetConnection();
      if (!hasConnection) {
        print('[SYNC] Sin conexión a internet');
        return 0;
      }
      
      // Obtener facturas pendientes
      final facturasPendientes = await PedidosScreenOffline.obtenerFacturasPendientes();
      
      if (facturasPendientes.isEmpty) {
        print('[SYNC] No hay facturas pendientes');
        return 0;
      }
      
      print('[SYNC] Sincronizando ${facturasPendientes.length} facturas...');
      
      int sincronizadas = 0;
      final facturasNoSincronizadas = <Map<String, dynamic>>[];
      
      for (final factura in facturasPendientes) {
        try {
          print('[SYNC] Procesando factura: ${factura['numeroFactura']}');
          
          // Convertir factura offline al formato de API
          final facturaData = _convertirFacturaParaAPI(factura);
          
          // Enviar al servidor
          final response = await _facturaService.insertarFactura(facturaData);
          
          print('[SYNC] Respuesta completa del servidor: ${jsonEncode(response)}');
          
          // Verificar respuesta
          if (response != null && (response['success'] == true || response['data'] != null)) {
            sincronizadas++;
            print('[SYNC] ✓ Factura ${factura['fact_Numero'] ?? factura['numeroFactura']} sincronizada');
          } else {
            facturasNoSincronizadas.add(factura);
            print('[SYNC] ⚠ Factura ${factura['fact_Numero'] ?? factura['numeroFactura']} falló');
            print('[SYNC] Error del servidor: ${response?['message']}');
            print('[SYNC] Datos enviados que causaron error: ${jsonEncode(facturaData)}');
          }
          
        } catch (e) {
          facturasNoSincronizadas.add(factura);
          print('[SYNC] ❌ Error sincronizando ${factura['numeroFactura']}: $e');
        }
        
        // Pausa pequeña entre sincronizaciones
        await Future.delayed(const Duration(milliseconds: 500));
      }
      
      // Actualizar lista de pendientes (solo mantener las que no se sincronizaron)
      await PedidosScreenOffline.guardarJson('facturas_pendientes.json', facturasNoSincronizadas);
      
      print('[SYNC] Sincronización completada: $sincronizadas/${facturasPendientes.length} facturas');
      return sincronizadas;
      
    } catch (e) {
      print('[SYNC] Error general en sincronización: $e');
      return 0;
    }
  }
  
  /// Convierte una factura offline al formato requerido por la API
  static Map<String, dynamic> _convertirFacturaParaAPI(Map<String, dynamic> facturaOffline) {
    print('[SYNC] Convirtiendo factura offline: ${facturaOffline['fact_Numero'] ?? facturaOffline['numeroFactura']}');
    print('[SYNC] Campos disponibles en factura offline: ${facturaOffline.keys.toList()}');
    print('[SYNC] Detalles originales: ${facturaOffline['detallesFacturaInput'] ?? facturaOffline['detalles']}');
    
    // La factura offline ya tiene el formato correcto, solo necesitamos extraer los campos principales
    final facturaData = <String, dynamic>{};
    
    // Copiar todos los campos que ya están en formato API
    if (facturaOffline.containsKey('fact_Numero')) {
      facturaData['fact_Numero'] = facturaOffline['fact_Numero'];
    }
    if (facturaOffline.containsKey('fact_TipoDeDocumento')) {
      facturaData['fact_TipoDeDocumento'] = facturaOffline['fact_TipoDeDocumento'];
    }
    if (facturaOffline.containsKey('regC_Id')) {
      facturaData['regC_Id'] = facturaOffline['regC_Id'];
    }
    if (facturaOffline.containsKey('diCl_Id')) {
      facturaData['diCl_Id'] = facturaOffline['diCl_Id'];
    }
    if (facturaOffline.containsKey('vend_Id')) {
      facturaData['vend_Id'] = facturaOffline['vend_Id'];
    }
    if (facturaOffline.containsKey('fact_TipoVenta')) {
      facturaData['fact_TipoVenta'] = facturaOffline['fact_TipoVenta'];
    }
    if (facturaOffline.containsKey('fact_FechaEmision')) {
      facturaData['fact_FechaEmision'] = facturaOffline['fact_FechaEmision'];
    }
    if (facturaOffline.containsKey('fact_Latitud')) {
      facturaData['fact_Latitud'] = facturaOffline['fact_Latitud'];
    }
    if (facturaOffline.containsKey('fact_Longitud')) {
      facturaData['fact_Longitud'] = facturaOffline['fact_Longitud'];
    }
    if (facturaOffline.containsKey('fact_Referencia')) {
      facturaData['fact_Referencia'] = facturaOffline['fact_Referencia'];
    }
    if (facturaOffline.containsKey('fact_AutorizadoPor')) {
      facturaData['fact_AutorizadoPor'] = facturaOffline['fact_AutorizadoPor'];
    }
    if (facturaOffline.containsKey('Usua_Creacion')) {
      facturaData['Usua_Creacion'] = facturaOffline['Usua_Creacion'];
    }
    if (facturaOffline.containsKey('fact_EsPedido')) {
      facturaData['fact_EsPedido'] = facturaOffline['fact_EsPedido'];
    }
    if (facturaOffline.containsKey('pedi_Id')) {
      facturaData['pedi_Id'] = facturaOffline['pedi_Id'];
    }
    if (facturaOffline.containsKey('detallesFacturaInput')) {
      facturaData['detallesFacturaInput'] = facturaOffline['detallesFacturaInput'];
    }
    
    print('[SYNC] Factura convertida para API: ${jsonEncode(facturaData)}');
    return facturaData;
  }
  
  
  /// Método manual para forzar sincronización
  static Future<bool> forzarSincronizacion() async {
    try {
      final sincronizadas = await sincronizarFacturasPendientes();
      return sincronizadas > 0;
    } catch (e) {
      print('[SYNC] Error en sincronización forzada: $e');
      return false;
    }
  }
  
  /// Obtiene el número de facturas pendientes
  static Future<int> obtenerNumeroFacturasPendientes() async {
    try {
      final facturas = await PedidosScreenOffline.obtenerFacturasPendientes();
      return facturas.length;
    } catch (e) {
      return 0;
    }
  }
}
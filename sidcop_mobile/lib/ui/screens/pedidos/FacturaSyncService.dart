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
          await sincronizarFacturasPendientes();
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
          
          // Verificar respuesta
          if (response != null && (response['success'] == true || response['data'] != null)) {
            sincronizadas++;
            print('[SYNC] ✓ Factura ${factura['numeroFactura']} sincronizada');
          } else {
            facturasNoSincronizadas.add(factura);
            print('[SYNC] ⚠ Factura ${factura['numeroFactura']} falló: ${response?['message']}');
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
    print('[SYNC] Convirtiendo factura offline: ${facturaOffline['numeroFactura']}');
    print('[SYNC] Detalles originales: ${facturaOffline['detalles']}');
    
    // Procesar detalles de la factura
    final detallesFactura = <Map<String, dynamic>>[];
    final detalles = facturaOffline['detalles'] as List<dynamic>? ?? [];
    
    for (var item in detalles) {
      if (item is Map<String, dynamic>) {
        // Intentar extraer ID del producto con diferentes nombres de campo
        final int prodId = _extraerProdId(item);
        final int cantidad = _extraerCantidad(item);
        
        print('[SYNC] Procesando item: prodId=$prodId, cantidad=$cantidad');
        
        if (prodId > 0 && cantidad > 0) {
          detallesFactura.add({
            'prod_Id': prodId,
            'faDe_Cantidad': cantidad
          });
          print('[SYNC] ✓ Detalle añadido: prodId=$prodId, cantidad=$cantidad');
        } else {
          print('[SYNC] ⚠ Item ignorado: prodId=$prodId, cantidad=$cantidad');
        }
      }
    }
    
    print('[SYNC] Total detalles procesados: ${detallesFactura.length}');
    
    // Construir objeto para API
    final facturaData = {
      'fact_Numero': facturaOffline['numeroFactura'],
      'fact_TipoDeDocumento': 'FAC',
      'regC_Id': 21,
      'diCl_Id': facturaOffline['diClId'] ?? 1,
      'vend_Id': facturaOffline['vendedorId'],
      'fact_TipoVenta': 'CO',
      'fact_FechaEmision': facturaOffline['fechaEmision'],
      'fact_Latitud': 0.0,
      'fact_Longitud': 0.0,
      'fact_Referencia': 'Factura sincronizada desde offline - ${facturaOffline['local_signature']}',
      'fact_AutorizadoPor': facturaOffline['vendedor'] ?? '',
      'usua_Creacion': facturaOffline['usuaCreacion'] ?? facturaOffline['vendedorId'] ?? 1,
      'fact_EsPedido': facturaOffline['pediId'] != null,
      'pedi_Id': facturaOffline['pediId'],
      'detallesFacturaInput': detallesFactura,
    };
    
    print('[SYNC] Factura convertida para API: ${jsonEncode(facturaData)}');
    return facturaData;
  }
  
  /// Extrae el ID del producto con diferentes nombres de campo
  static int _extraerProdId(Map<String, dynamic> item) {
    // Lista de posibles nombres de campo para el ID del producto
    final posiblesCampos = ['id', 'prod_Id', 'prodId', 'Prod_Id'];
    
    for (final campo in posiblesCampos) {
      final valor = item[campo];
      if (valor != null) {
        if (valor is int) return valor;
        if (valor is String) {
          final parsed = int.tryParse(valor);
          if (parsed != null && parsed > 0) return parsed;
        }
      }
    }
    
    return 0;
  }
  
  /// Extrae la cantidad con diferentes nombres de campo
  static int _extraerCantidad(Map<String, dynamic> item) {
    // Lista de posibles nombres de campo para la cantidad
    final posiblesCampos = ['cantidad', 'peDe_Cantidad', 'faDe_Cantidad', 'cantidadProducto'];
    
    for (final campo in posiblesCampos) {
      final valor = item[campo];
      if (valor != null) {
        if (valor is int) return valor;
        if (valor is String) {
          final parsed = int.tryParse(valor);
          if (parsed != null && parsed > 0) return parsed;
        }
      }
    }
    
    return 0;
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
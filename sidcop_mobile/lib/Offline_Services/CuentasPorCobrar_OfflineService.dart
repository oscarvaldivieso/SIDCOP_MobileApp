import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:async';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:sidcop_mobile/services/cuentasPorCobrarService.dart';
import 'package:sidcop_mobile/services/PagosCxCService.dart';
import 'package:sidcop_mobile/models/ventas/cuentasporcobrarViewModel.dart';
import 'package:sidcop_mobile/models/ventas/PagosCXCViewModel.dart';
import 'package:sidcop_mobile/models/FormasDePagoViewModel.dart';

/// Servicios para operaciones offline de Cuentas por Cobrar:
/// - Sincronización y almacenamiento de cuentas por cobrar
/// - Manejo de pagos pendientes offline
/// - Cache de formas de pago y datos relacionados

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// CUENTAS POR COBRAR OFFLINE SERVICE
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
class CuentasPorCobrarOfflineService {
  // Carpeta raíz dentro de documents para los archivos offline
  static const String _carpetaOffline = 'offline_cuentas_cobrar';
  
  // Nombres de archivos para diferentes tipos de datos
  static const String _archivoCuentasPorCobrar = 'cuentas_por_cobrar.json';
  static const String _archivoFormasPago = 'formas_pago.json';
  static const String _archivoResumenClientes = 'resumen_clientes.json';
  static const String _archivoPagosPendientes = 'pagos_pendientes.json';
  static const String _archivoTimelineClientes = 'timeline_clientes.json';

  // Instancia de secure storage para valores sensibles
  static final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  
  // CONTROL DE SINCRONIZACIÓN CONCURRENTE
  static bool _sincronizacionEnProceso = false;
  static Completer<int>? _completadorSincronizacion;

  // Devuelve el directorio de documents
  static Future<Directory> _directorioDocuments() async {
    return await getApplicationDocumentsDirectory();
  }

  // Construye la ruta absoluta para un archivo relativo dentro de la carpeta offline
  static Future<String> _rutaArchivo(String nombreRelativo) async {
    final docs = await _directorioDocuments();
    final ruta = p.join(docs.path, _carpetaOffline, nombreRelativo);
    final dirPadre = Directory(p.dirname(ruta));
    if (!await dirPadre.exists()) {
      await dirPadre.create(recursive: true);
    }
    return ruta;
  }

  ///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
  // MÉTODOS BÁSICOS DE ALMACENAMIENTO (JSON y BINARIOS)
  ///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

  /// Guarda cualquier objeto JSON-serializable en `nombreArchivo`.
  /// La escritura es atómica: escribe en un temporal y renombra.
  static Future<void> guardarJson(String nombreArchivo, Object objeto) async {
    try {
      // Guardar JSON en almacenamiento seguro
      final contenido = jsonEncode(objeto);
      final key = 'cxc_json:$nombreArchivo';
      await _secureStorage.write(key: key, value: contenido);
    } catch (e) {
      rethrow;
    }
  }

  /// Lee y decodifica JSON desde `nombreArchivo`. Devuelve null si no existe.
  static Future<dynamic> leerJson(String nombreArchivo) async {
    try {
      final key = 'cxc_json:$nombreArchivo';
      final s = await _secureStorage.read(key: key);
      if (s == null) return null;
      return jsonDecode(s);
    } catch (e) {
      rethrow;
    }
  }

  /// Guarda bytes en un archivo (por ejemplo documentos PDF, imágenes). Escritura atómica.
  static Future<void> guardarBytes(
    String nombreArchivo,
    Uint8List bytes,
  ) async {
    try {
      // Guardar bytes en secure storage como base64
      final key = 'cxc_bin:$nombreArchivo';
      final encoded = base64Encode(bytes);
      await _secureStorage.write(key: key, value: encoded);

      // También escribir a disco para compatibilidad
      final ruta = await _rutaArchivo(nombreArchivo);
      final tempRuta = '$ruta.tmp';
      final tempFile = File(tempRuta);
      await tempFile.writeAsBytes(bytes);
      
      try {
        await tempFile.rename(ruta);
      } catch (e) {
        // Si falla el rename, intentar copiar y borrar
        await tempFile.copy(ruta);
        await tempFile.delete();
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Lee bytes desde un archivo. Devuelve null si no existe.
  static Future<Uint8List?> leerBytes(String nombreArchivo) async {
    try {
      // Intentar leer desde disco primero
      final ruta = await _rutaArchivo(nombreArchivo);
      final archivo = File(ruta);
      if (await archivo.exists()) {
        return await archivo.readAsBytes();
      }

      // Fallback: leer desde secure storage
      final key = 'cxc_bin:$nombreArchivo';
      final encoded = await _secureStorage.read(key: key);
      if (encoded != null) {
        return base64Decode(encoded);
      }
      
      return null;
    } catch (e) {
      rethrow;
    }
  }

  /// Comprueba si un archivo existe.
  static Future<bool> existe(String nombreArchivo) async {
    // Comprobar secure storage
    if (nombreArchivo.toLowerCase().endsWith('.json')) {
      final key = 'cxc_json:$nombreArchivo';
      final s = await _secureStorage.read(key: key);
      if (s != null) return true;
    }
    
    final binKey = 'cxc_bin:$nombreArchivo';
    final b = await _secureStorage.read(key: binKey);
    if (b != null) return true;
    
    // Comprobar disco
    final ruta = await _rutaArchivo(nombreArchivo);
    final archivo = File(ruta);
    return archivo.exists();
  }

  /// Borra un archivo si existe.
  static Future<void> borrar(String nombreArchivo) async {
    try {
      // Borrar de secure storage
      if (nombreArchivo.toLowerCase().endsWith('.json')) {
        final key = 'cxc_json:$nombreArchivo';
        await _secureStorage.delete(key: key);
      }
      
      final binKey = 'cxc_bin:$nombreArchivo';
      await _secureStorage.delete(key: binKey);
      
      // Borrar de disco
      final ruta = await _rutaArchivo(nombreArchivo);
      final archivo = File(ruta);
      if (await archivo.exists()) {
        await archivo.delete();
      }
    } catch (e) {
      rethrow;
    }
  }

  ///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
  // MÉTODOS DE SINCRONIZACIÓN CON ENDPOINTS
  ///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

  /// Sincroniza las cuentas por cobrar desde el endpoint y las guarda localmente.
  static Future<List<dynamic>> sincronizarCuentasPorCobrar() async {
    try {
      final servicio = CuentasXCobrarService();
      final data = await servicio.getCuentasPorCobrar();
      
      ('SYNC: sincronizarCuentasPorCobrar fetched ${data.length} items');
      
      // Guardar la respuesta
      await guardarJson(_archivoCuentasPorCobrar, data);
      return data;
    } catch (e) {
      ('Error sincronizando cuentas por cobrar: $e');
      rethrow;
    }
  }

  /// Sincroniza las formas de pago desde el endpoint.
  static Future<List<FormaPago>> sincronizarFormasPago() async {
    try {
      final servicio = PagoCuentasXCobrarService();
      final data = await servicio.getFormasPago();
      
      ('SYNC: sincronizarFormasPago fetched ${data.length} items');
      
      // Convertir a JSON para almacenar
      final jsonData = data.map((formaPago) => formaPago.toJson()).toList();
      await guardarJson(_archivoFormasPago, jsonData);
      
      return data;
    } catch (e) {
      ('Error sincronizando formas de pago: $e');
      rethrow;
    }
  }

  /// Sincroniza el resumen por cliente desde el endpoint.
  static Future<List<dynamic>> sincronizarResumenClientes() async {
    try {
      final servicio = CuentasXCobrarService();
      final data = await servicio.getResumenCliente();
      
      ('SYNC: sincronizarResumenClientes fetched ${data.length} items');
      
      await guardarJson(_archivoResumenClientes, data);
      return data;
    } catch (e) {
      ('Error sincronizando resumen clientes: $e');
      rethrow;
    }
  }

  /// Sincroniza el timeline de un cliente específico.
  static Future<List<dynamic>> sincronizarTimelineCliente(int clienteId) async {
    try {
      final servicio = CuentasXCobrarService();
      final data = await servicio.getTimelineCliente(clienteId);
      
      ('SYNC: sincronizarTimelineCliente para cliente $clienteId fetched ${data.length} items');
      
      // Guardar con clave específica del cliente
      final key = 'timeline_cliente_$clienteId';
      await guardarJsonSeguro(key, data);
      
      return data;
    } catch (e) {
      ('Error sincronizando timeline cliente $clienteId: $e');
      rethrow;
    }
  }

  /// Sincroniza los timelines de múltiples clientes de forma eficiente
  static Future<Map<int, List<dynamic>>> sincronizarTimelineMultiplesClientes(List<int> clienteIds) async {
    final resultados = <int, List<dynamic>>{};
    
    // Procesar clientes en lotes para evitar sobrecargar el servidor
    const tamanoLote = 5;
    for (int i = 0; i < clienteIds.length; i += tamanoLote) {
      final lote = clienteIds.skip(i).take(tamanoLote).toList();
      
      // Procesar lote en paralelo
      final futurosSincronizacion = lote.map((clienteId) async {
        try {
          final timeline = await sincronizarTimelineCliente(clienteId);
          return MapEntry(clienteId, timeline);
        } catch (e) {
          ('Error sincronizando cliente $clienteId: $e');
          return MapEntry(clienteId, <dynamic>[]);
        }
      });
      
      final resultadosLote = await Future.wait(futurosSincronizacion);
      for (final resultado in resultadosLote) {
        resultados[resultado.key] = resultado.value;
      }
      
      // Pausa breve entre lotes para no sobrecargar
      if (i + tamanoLote < clienteIds.length) {
        await Future.delayed(const Duration(milliseconds: 200));
      }
    }
    
    ('✅ Sincronización de ${clienteIds.length} timelines de clientes completada');
    return resultados;
  }

  /// Sincroniza todos los datos relacionados con cuentas por cobrar.
  static Future<Map<String, dynamic>> sincronizarTodo() async {
    try {
      final resultados = await Future.wait([
        sincronizarCuentasPorCobrar(),
        sincronizarFormasPago(),
        sincronizarResumenClientes(),
      ]);

      // Extraer IDs de clientes del resumen para sincronizar sus timelines
      final resumenClientes = resultados[2];
      final clienteIds = <int>[];
      
      for (final item in resumenClientes) {
        try {
          final clienteId = item['clie_Id'];
          if (clienteId is int && !clienteIds.contains(clienteId)) {
            clienteIds.add(clienteId);
          }
        } catch (e) {
          ('Error extrayendo cliente ID: $e');
        }
      }
      
      // Sincronizar timelines de clientes en background (no bloquear la respuesta principal)
      if (clienteIds.isNotEmpty) {
        ('🔄 Iniciando sincronización de ${clienteIds.length} timelines de clientes...');
        
        // Ejecutar sincronización de timelines en background
        Future.microtask(() async {
          try {
            await sincronizarTimelineMultiplesClientes(clienteIds);
            ('✅ Sincronización de timelines completada para ${clienteIds.length} clientes');
          } catch (e) {
            ('⚠️ Error en sincronización de timelines: $e');
          }
        });
      }

      return {
        'cuentasPorCobrar': resultados[0],
        'formasPago': resultados[1],
        'resumenClientes': resultados[2],
        'clientesParaTimeline': clienteIds.length,
        'timestamp': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      ('Error en sincronización completa: $e');
      rethrow;
    }
  }

  ///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
  // MÉTODOS DE LECTURA LOCAL
  ///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

  /// Obtiene las cuentas por cobrar almacenadas localmente.
  static Future<List<dynamic>> obtenerCuentasPorCobrarLocal() async {
    final raw = await leerJson(_archivoCuentasPorCobrar);
    if (raw == null) return [];
    return List.from(raw as List);
  }

  /// Obtiene las formas de pago almacenadas localmente.
  static Future<List<FormaPago>> obtenerFormasPagoLocal() async {
    final raw = await leerJson(_archivoFormasPago);
    if (raw == null) return [];
    
    try {
      final lista = List.from(raw as List);
      return lista.map((item) => FormaPago.fromJson(item)).toList();
    } catch (e) {
      ('Error convirtiendo formas de pago: $e');
      return [];
    }
  }

  /// Obtiene el resumen de clientes almacenado localmente.
  static Future<List<dynamic>> obtenerResumenClientesLocal() async {
    final raw = await leerJson(_archivoResumenClientes);
    if (raw == null) return [];
    return List.from(raw as List);
  }

  /// Obtiene el timeline de un cliente específico almacenado localmente.
  static Future<List<dynamic>> obtenerTimelineClienteLocal(int clienteId) async {
    final key = 'timeline_cliente_$clienteId';
    final raw = await leerJsonSeguro(key);
    if (raw == null) return [];
    return List.from(raw as List);
  }

  /// Pre-carga todos los datos necesarios para un cliente específico
  static Future<void> precargarDatosCliente(int clienteId) async {
    try {
      ('🔄 Pre-cargando datos para cliente $clienteId...');
      
      // Verificar si ya tenemos datos del timeline
      final timelineExistente = await obtenerTimelineClienteLocal(clienteId);
      
      if (timelineExistente.isEmpty) {
        // Si no hay timeline, intentar sincronizar
        try {
          await sincronizarTimelineCliente(clienteId);
          ('✅ Timeline sincronizado para cliente $clienteId');
        } catch (e) {
          ('⚠️ Error sincronizando timeline cliente $clienteId: $e');
        }
      } else {
        ('✅ Timeline ya disponible offline para cliente $clienteId (${timelineExistente.length} elementos)');
      }
      
      // También verificar y pre-cargar información de crédito si es necesario
      final infoCredito = await obtenerInfoCreditoCliente(clienteId);
      if (infoCredito == null) {
        try {
          final servicio = CuentasXCobrarService();
          final creditInfo = await servicio.getClienteCreditInfo(clienteId);
          await guardarInfoCreditoCliente(clienteId, creditInfo);
          ('✅ Información de crédito sincronizada para cliente $clienteId');
        } catch (e) {
          ('⚠️ Error sincronizando info crédito cliente $clienteId: $e');
        }
      }
      
    } catch (e) {
      ('Error en pre-carga de datos cliente $clienteId: $e');
    }
  }

  ///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
  // MÉTODOS PARA PAGOS PENDIENTES (MODO OFFLINE)
  ///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

  /// Guarda un pago con actualización inmediata del saldo para mejor UX
  static Future<void> guardarPagoConActualizacionInmediata(PagosCuentasXCobrar pago) async {
    try {
      // VALIDACIONES PREVIAS ANTES DE GUARDAR
      final validacionResult = await validarPagoOffline(pago);
      if (!validacionResult['valido']) {
        throw Exception(validacionResult['mensaje']);
      }

      // Obtener pagos pendientes existentes
      final pendientes = await obtenerPagosPendientesLocal();
      
      // VALIDACIÓN ANTI-DUPLICADOS: Verificar que no exista un pago idéntico pendiente
      final pagoYaExiste = pendientes.any((item) {
        try {
          final pagoExistente = item['pago'] as Map<String, dynamic>;
          return pagoExistente['CPCo_Id'] == pago.cpCoId &&
                 pagoExistente['Pago_Monto'] == pago.pagoMonto &&
                 pagoExistente['Pago_NumeroReferencia'] == pago.pagoNumeroReferencia &&
                 item['sincronizado'] != true; // Solo considerar pagos no sincronizados
        } catch (e) {
          return false;
        }
      });

      if (pagoYaExiste) {
        ('⚠️ Pago duplicado detectado en cola offline, omitiendo...');
        return;
      }
      
      // Generar ID temporal único para evitar duplicados
      final idTemporal = '${DateTime.now().millisecondsSinceEpoch}_${pago.cpCoId}_${pago.pagoMonto.toStringAsFixed(2)}';
      
      // Agregar el nuevo pago con timestamp y metadatos optimizados
      final pagoConMetadata = {
        'pago': pago.toJson(),
        'timestamp': DateTime.now().toIso8601String(),
        'intentos': 0,
        'id_temporal': idTemporal,
        'sincronizado': false,
        'prioridad': 'alta', // Para sincronización prioritaria
        'hash_validacion': _generarHashPago(pago), // Hash para validación de duplicados
      };
      
      pendientes.add(pagoConMetadata);
      
      // Guardar la lista actualizada de forma rápida
      await guardarJson(_archivoPagosPendientes, pendientes);
      
      // IMPORTANTE: Actualizar inmediatamente los datos locales para reflejar el cambio
      await _actualizarDatosLocalesConPago(pago);
      
      // Actualizar timeline inmediatamente
      await _actualizarTimelineInmediato(pago);
      
      ('✅ Pago guardado con actualización inmediata. ID temporal: $idTemporal, Total pendientes: ${pendientes.length}');
    } catch (e) {
      ('❌ Error guardando pago con actualización inmediata: $e');
      rethrow;
    }
  }

  /// Guarda un pago pendiente cuando no hay conexión.
  static Future<void> guardarPagoPendiente(PagosCuentasXCobrar pago) async {
    try {
      // VALIDACIONES PREVIAS ANTES DE GUARDAR
      final validacionResult = await validarPagoOffline(pago);
      if (!validacionResult['valido']) {
        throw Exception(validacionResult['mensaje']);
      }

      // Obtener pagos pendientes existentes
      final pendientes = await obtenerPagosPendientesLocal();
      
      // Agregar el nuevo pago con timestamp
      final pagoConMetadata = {
        'pago': pago.toJson(),
        'timestamp': DateTime.now().toIso8601String(),
        'intentos': 0,
        'id_temporal': DateTime.now().millisecondsSinceEpoch.toString(),
      };
      
      pendientes.add(pagoConMetadata);
      
      // Guardar la lista actualizada
      await guardarJson(_archivoPagosPendientes, pendientes);
      
      // IMPORTANTE: Simular el pago localmente actualizando el saldo
      await _simularPagoLocal(pago);
      
      ('Pago pendiente guardado. Total pendientes: ${pendientes.length}');
    } catch (e) {
      ('Error guardando pago pendiente: $e');
      rethrow;
    }
  }

  /// Valida un pago offline para asegurar que sea válido antes de procesarlo
  static Future<Map<String, dynamic>> validarPagoOffline(PagosCuentasXCobrar pago) async {
    try {
      final cpCoId = pago.cpCoId;
      final montoPago = pago.pagoMonto;

      // 1. Validar que la cuenta existe en los datos offline
      final cuentaDetalle = await obtenerDetalleCuentaLocal(cpCoId);
      if (cuentaDetalle == null) {
        // Buscar en el resumen de clientes
        final resumenClientes = await obtenerResumenClientesLocal();
        final cuentaEnResumen = resumenClientes.firstWhere(
          (item) => item['cpCo_Id'] == cpCoId,
          orElse: () => null,
        );
        
        if (cuentaEnResumen == null) {
          return {
            'valido': false,
            'mensaje': 'La cuenta por cobrar no existe en los datos offline'
          };
        }
      }

      // 2. CORRECCIÓN: Obtener el saldo real actualizado (mismo que ve el usuario)
      // Este saldo YA incluye todos los pagos pendientes offline aplicados
      final saldoRealActualizado = await obtenerSaldoRealCuentaActualizado(cpCoId);
      
      ('💰 Validación de pago - Cuenta: $cpCoId');
      ('   - Monto solicitado: ${_formatCurrency(montoPago)}');
      ('   - Saldo real disponible: ${_formatCurrency(saldoRealActualizado)}');

      // 3. Validar que el monto no exceda el saldo disponible real
      if (montoPago > saldoRealActualizado) {
        return {
          'valido': false,
          'mensaje': 'El monto del pago (${_formatCurrency(montoPago)}) excede el saldo disponible (${_formatCurrency(saldoRealActualizado)})'
        };
      }

      // 4. Validación adicional: verificar que el saldo sea positivo
      if (saldoRealActualizado <= 0) {
        return {
          'valido': false,
          'mensaje': 'Esta cuenta ya está completamente saldada. Saldo actual: ${_formatCurrency(saldoRealActualizado)}'
        };
      }

      // 5. Validaciones de negocio básicas
      if (montoPago <= 0) {
        return {
          'valido': false,
          'mensaje': 'El monto del pago debe ser mayor a cero'
        };
      }

      if (pago.pagoNumeroReferencia.trim().isEmpty) {
        return {
          'valido': false,
          'mensaje': 'El número de referencia es requerido'
        };
      }

      if (pago.foPaId <= 0) {
        return {
          'valido': false,
          'mensaje': 'Debe seleccionar una forma de pago válida'
        };
      }

      return {
        'valido': true,
        'mensaje': 'Pago válido',
        'saldoRealActualizado': saldoRealActualizado,
        'saldoDisponible': saldoRealActualizado
      };

    } catch (e) {
      return {
        'valido': false,
        'mensaje': 'Error validando pago: $e'
      };
    }
  }

  /// Simula un pago localmente actualizando los saldos en cache
  static Future<void> _simularPagoLocal(PagosCuentasXCobrar pago) async {
    try {
      final cpCoId = pago.cpCoId;
      final montoPago = pago.pagoMonto;
      
      ('🔄 Simulando pago local para cuenta $cpCoId: ${_formatCurrency(montoPago)}');
      
      // 1. Actualizar el detalle de la cuenta si existe
      final cuentaDetalle = await obtenerDetalleCuentaLocal(cpCoId);
      if (cuentaDetalle != null) {
        final saldoAnterior = cuentaDetalle.cpCo_Saldo ?? 0;
        final nuevoSaldo = saldoAnterior - montoPago;
        
        // Crear una nueva instancia con el saldo actualizado
        final cuentaJson = cuentaDetalle.toJson();
        cuentaJson['cpCo_Saldo'] = nuevoSaldo > 0 ? nuevoSaldo : 0;
        
        // Si el saldo llega a 0, marcar como saldada
        if (nuevoSaldo <= 0) {
          cuentaJson['cpCo_Saldada'] = true;
          cuentaJson['cpCo_FechaSaldada'] = DateTime.now().toIso8601String();
        }
        
        final cuentaActualizada = CuentasXCobrar.fromJson(cuentaJson);
        await guardarDetalleCuenta(cpCoId, cuentaActualizada);
        
        ('✅ Detalle de cuenta actualizado: Saldo ${_formatCurrency(saldoAnterior)} → ${_formatCurrency(nuevoSaldo)}');
      }
      
      // 2. Actualizar el resumen de clientes
      final resumenClientes = await obtenerResumenClientesLocal();
      bool resumenActualizado = false;
      
      for (int i = 0; i < resumenClientes.length; i++) {
        final item = resumenClientes[i];
        final cuenta = CuentasXCobrar.fromJson(item);
        
        if (cuenta.cpCo_Id == cpCoId) {
          final saldoAnterior = cuenta.totalPendiente ?? cuenta.cpCo_Saldo ?? 0;
          final nuevoSaldo = saldoAnterior - montoPago;
          
          // Crear una nueva instancia con valores actualizados
          final cuentaJson = cuenta.toJson();
          cuentaJson['cpCo_Saldo'] = nuevoSaldo > 0 ? nuevoSaldo : 0;
          cuentaJson['totalPendiente'] = cuentaJson['cpCo_Saldo'];
          
          if (nuevoSaldo <= 0) {
            cuentaJson['cpCo_Saldada'] = true;
            cuentaJson['cpCo_FechaSaldada'] = DateTime.now().toIso8601String();
          }
          
          // Actualizar información de último pago
          cuentaJson['ultimoPago'] = DateTime.now().toIso8601String();
          
          // Actualizar el item en la lista
          resumenClientes[i] = cuentaJson;
          resumenActualizado = true;
          ('✅ Resumen de cliente actualizado: Pendiente ${_formatCurrency(saldoAnterior)} → ${_formatCurrency(nuevoSaldo)}');
          break;
        }
      }
      
      // Guardar el resumen actualizado solo si se hicieron cambios
      if (resumenActualizado) {
        await guardarJson(_archivoResumenClientes, resumenClientes);
      }
      
      // 3. Agregar el pago al historial local
      await _agregarPagoAlHistorialLocal(pago);
      
      // 4. Actualizar el timeline del cliente inmediatamente
      await _actualizarTimelineInmediato(pago);
      
      ('✅ Simulación de pago local completada para cuenta $cpCoId');
    } catch (e) {
      ('❌ Error simulando pago local: $e');
      rethrow;
    }
  }

  /// Método auxiliar para formatear moneda en los logs
  static String _formatCurrency(double amount) {
    return 'L ${amount.toStringAsFixed(2)}';
  }

  /// Obtiene el saldo real actualizado de una cuenta considerando todos los pagos aplicados offline
  static Future<double> obtenerSaldoRealCuentaActualizado(int cpCoId) async {
    try {
      // 1. Obtener saldo base de la cuenta
      double saldoBase = 0;
      
      final cuentaDetalle = await obtenerDetalleCuentaLocal(cpCoId);
      if (cuentaDetalle != null) {
        saldoBase = cuentaDetalle.cpCo_Saldo ?? cuentaDetalle.totalPendiente ?? 0;
      } else {
        // Buscar en resumen de clientes
        final resumenClientes = await obtenerResumenClientesLocal();
        for (final item in resumenClientes) {
          if (item['cpCo_Id'] == cpCoId) {
            saldoBase = (item['totalPendiente'] ?? item['cpCo_Saldo'] ?? 0).toDouble();
            break;
          }
        }
      }

      // 2. Restar pagos pendientes offline (incluye pagos ya aplicados localmente)
      final pagosPendientes = await obtenerPagosPendientesLocal();
      double totalPagosPendientes = 0;
      
      for (final item in pagosPendientes) {
        try {
          final pagoData = item['pago'] as Map<String, dynamic>;
          if (pagoData['cpCoId'] == cpCoId && !item['sincronizado']) {
            final montoPago = (pagoData['pagoMonto'] ?? 0).toDouble();
            totalPagosPendientes += montoPago;
          }
        } catch (e) {
          ('Error procesando pago pendiente: $e');
        }
      }

      // 3. Restar también pagos ya aplicados en el historial local (evitar doble conteo)
      // Solo para verificación, no se restan del saldo base ya que ya están considerados
      final historialPagos = await obtenerHistorialPagosLocal(cpCoId);
      ('📄 Historial de pagos cuenta $cpCoId: ${historialPagos.length} pagos encontrados');

      final saldoActualizado = saldoBase - totalPagosPendientes;
      
      ('📊 Saldo actualizado cuenta $cpCoId: Base=${_formatCurrency(saldoBase)}, Pendientes=${_formatCurrency(totalPagosPendientes)}, Final=${_formatCurrency(saldoActualizado)}');
      
      return saldoActualizado > 0 ? saldoActualizado : 0;
    } catch (e) {
      ('Error obteniendo saldo real actualizado de cuenta $cpCoId: $e');
      return 0;
    }
  }

  /// Obtiene el saldo real de una cuenta considerando pagos pendientes offline
  static Future<double> obtenerSaldoRealCuenta(int cpCoId) async {
    try {
      // 1. Obtener saldo base de la cuenta
      double saldoBase = 0;
      
      final cuentaDetalle = await obtenerDetalleCuentaLocal(cpCoId);
      if (cuentaDetalle != null) {
        saldoBase = cuentaDetalle.cpCo_Saldo ?? cuentaDetalle.totalPendiente ?? 0;
      } else {
        // Buscar en resumen de clientes
        final resumenClientes = await obtenerResumenClientesLocal();
        for (final item in resumenClientes) {
          if (item['cpCo_Id'] == cpCoId) {
            saldoBase = (item['totalPendiente'] ?? item['cpCo_Saldo'] ?? 0).toDouble();
            break;
          }
        }
      }

      return saldoBase;
    } catch (e) {
      ('Error obteniendo saldo real de cuenta $cpCoId: $e');
      return 0;
    }
  }

  /// Agrega un pago al historial local
  static Future<void> _agregarPagoAlHistorialLocal(PagosCuentasXCobrar pago) async {
    try {
      final key = 'pagos_cuenta_${pago.cpCoId}';
      final pagosExistentes = await leerJsonSeguro(key) ?? [];
      final listaPagos = List.from(pagosExistentes as List);
      
      // Agregar el nuevo pago al inicio (más reciente primero)
      listaPagos.insert(0, pago.toFullJson());
      
      await guardarJsonSeguro(key, listaPagos);
      ('Pago agregado al historial local de cuenta ${pago.cpCoId}');
    } catch (e) {
      ('Error agregando pago al historial local: $e');
    }
  }

  /// Obtiene el historial de pagos de una cuenta desde cache local
  static Future<List<PagosCuentasXCobrar>> obtenerHistorialPagosLocal(int cpCoId) async {
    try {
      final key = 'pagos_cuenta_$cpCoId';
      final raw = await leerJsonSeguro(key);
      if (raw == null) {
        ('📋 No hay pagos en cache para cuenta $cpCoId');
        return [];
      }
      
      ('📋 Datos raw encontrados para cuenta $cpCoId: ${raw.toString().length} caracteres');
      
      final lista = List.from(raw as List);
      ('📋 Lista deserializada: ${lista.length} elementos');
      
      // Debug: Mostrar el primer elemento si existe
      if (lista.isNotEmpty) {
        ('🔍 Primer elemento raw: ${lista[0]}');
      }
      
      final pagos = lista.map((item) {
        try {
          final pago = PagosCuentasXCobrar.fromJson(item);
          ('✅ Pago convertido: ID=${pago.pagoId}, Monto=${pago.pagoMonto}, FormaPago="${pago.pagoFormaPago}"');
          return pago;
        } catch (e) {
          ('❌ Error convirtiendo pago: $e');
          ('   Datos del item: $item');
          rethrow;
        }
      }).toList();
      
      ('📋 Obtenidos ${pagos.length} pagos desde cache para cuenta $cpCoId');
      return pagos;
    } catch (e) {
      ('❌ Error obteniendo historial de pagos local para cuenta $cpCoId: $e');
      return [];
    }
  }

  /// Sincroniza el historial de pagos de una cuenta específica
  static Future<void> sincronizarHistorialPagos(int cpCoId) async {
    try {
      final servicio = PagoCuentasXCobrarService();
      final pagos = await servicio.listarPagosPorCuenta(cpCoId);
      
      // Guardar en cache local con el formato correcto para fromJson
      final key = 'pagos_cuenta_$cpCoId';
      final pagosJson = pagos.map((pago) => {
        'pago_Id': pago.pagoId,
        'cpCo_Id': pago.cpCoId,
        'pago_Fecha': pago.pagoFecha.toIso8601String(),
        'pago_Monto': pago.pagoMonto,
        'pago_FormaPago': pago.pagoFormaPago,
        'pago_NumeroReferencia': pago.pagoNumeroReferencia,
        'pago_Observaciones': pago.pagoObservaciones,
        'usua_Creacion': pago.usuaCreacion,
        'pago_FechaCreacion': pago.pagoFechaCreacion.toIso8601String(),
        'usua_Modificacion': pago.usuaModificacion,
        'pago_FechaModificacion': pago.pagoFechaModificacion?.toIso8601String(),
        'pago_Estado': pago.pagoEstado,
        'pago_Anulado': pago.pagoAnulado,
        'foPa_Id': pago.foPaId,
        'usuarioCreacion': pago.usuarioCreacion,
        'usuarioModificacion': pago.usuarioModificacion,
        'clie_Id': pago.clieId,
        'clie_NombreCompleto': pago.clieNombreCompleto,
        'clie_RTN': pago.clieRTN,
        'fact_Id': pago.factId,
        'fact_Numero': pago.factNumero,
      }).toList();
      await guardarJsonSeguro(key, pagosJson);
      
      ('✅ Historial de pagos sincronizado para cuenta $cpCoId (${pagos.length} pagos)');
    } catch (e) {
      ('❌ Error sincronizando historial de pagos para cuenta $cpCoId: $e');
      rethrow;
    }
  }

  /// Marca un pago como sincronizado exitosamente
  static Future<void> marcarPagoComoSincronizado(PagosCuentasXCobrar pago) async {
    try {
      final pendientes = await obtenerPagosPendientesLocal();
      bool encontrado = false;
      
      // Buscar el pago en los pendientes y marcarlo como sincronizado
      for (int i = 0; i < pendientes.length; i++) {
        final item = pendientes[i];
        try {
          final pagoData = item['pago'] as Map<String, dynamic>;
          
          // Comparar por cpCoId, monto y timestamp para identificar el pago
          if (pagoData['cpCoId'] == pago.cpCoId && 
              pagoData['pagoMonto'] == pago.pagoMonto &&
              !item['sincronizado']) {
            
            // Marcar como sincronizado
            item['sincronizado'] = true;
            item['fechaSincronizacion'] = DateTime.now().toIso8601String();
            encontrado = true;
            
            ('✅ Pago marcado como sincronizado: Cuenta ${pago.cpCoId}, Monto ${_formatCurrency(pago.pagoMonto)}');
            break;
          }
        } catch (e) {
          ('Error procesando item de pago pendiente: $e');
        }
      }
      
      if (encontrado) {
        // Guardar la lista actualizada
        await guardarJson(_archivoPagosPendientes, pendientes);
        
        // Opcional: Limpiar pagos ya sincronizados después de un tiempo
        await _limpiarPagosSincronizadosAntiguos();
      } else {
        ('⚠️ No se encontró el pago para marcar como sincronizado');
      }
    } catch (e) {
      ('❌ Error marcando pago como sincronizado: $e');
    }
  }

  /// Limpia pagos sincronizados antiguos para mantener el cache limpio
  static Future<void> _limpiarPagosSincronizadosAntiguos() async {
    try {
      final pendientes = await obtenerPagosPendientesLocal();
      final ahora = DateTime.now();
      
      // Filtrar pagos: mantener solo no sincronizados y sincronizados recientes (últimas 24 horas)
      final pendientesFiltrados = pendientes.where((item) {
        try {
          final sincronizado = item['sincronizado'] ?? false;
          
          if (!sincronizado) {
            return true; // Mantener pagos no sincronizados
          }
          
          // Para pagos sincronizados, verificar si son recientes
          final fechaSincronizacion = item['fechaSincronizacion'];
          if (fechaSincronizacion != null) {
            final fecha = DateTime.parse(fechaSincronizacion);
            final diferencia = ahora.difference(fecha);
            return diferencia.inHours < 24; // Mantener solo últimas 24 horas
          }
          
          return false; // Remover pagos sincronizados sin fecha
        } catch (e) {
          return true; // En caso de error, mantener el item
        }
      }).toList();
      
      if (pendientesFiltrados.length < pendientes.length) {
        await guardarJson(_archivoPagosPendientes, pendientesFiltrados);
        ('🧹 Cache de pagos limpiado: ${pendientes.length - pendientesFiltrados.length} pagos antiguos removidos');
      }
    } catch (e) {
      ('Error limpiando pagos sincronizados antiguos: $e');
    }
  }

  /// Obtiene todos los pagos pendientes de sincronización.
  static Future<List<dynamic>> obtenerPagosPendientesLocal() async {
    final raw = await leerJson(_archivoPagosPendientes);
    if (raw == null) return [];
    return List.from(raw as List);
  }

  /// Sincroniza los pagos pendientes con el servidor (con control de concurrencia).
  static Future<int> sincronizarPagosPendientes() async {
    // CONTROL DE CONCURRENCIA: Si ya hay una sincronización en proceso, esperar a que termine
    if (_sincronizacionEnProceso) {
      ('⏳ Sincronización ya en proceso, esperando...');
      if (_completadorSincronizacion != null) {
        return await _completadorSincronizacion!.future;
      }
      return 0;
    }

    // Marcar que la sincronización está en proceso
    _sincronizacionEnProceso = true;
    _completadorSincronizacion = Completer<int>();

    try {
      final pendientes = await obtenerPagosPendientesLocal();
      if (pendientes.isEmpty) {
        _completadorSincronizacion!.complete(0);
        return 0;
      }

      final servicio = PagoCuentasXCobrarService();
      int sincronizados = 0;
      List<dynamic> restantes = [];

      ('🔄 Iniciando sincronización de ${pendientes.length} pagos pendientes...');
      
      // Limpiar duplicados offline antes de sincronizar
      final duplicadosEliminados = await limpiarPagosDuplicadosOffline();
      if (duplicadosEliminados > 0) {
        ('🧹 Pre-limpieza: $duplicadosEliminados duplicados eliminados');
        // Recargar la lista actualizada
        final pendientesLimpios = await obtenerPagosPendientesLocal();
        pendientes.clear();
        pendientes.addAll(pendientesLimpios);
      }

      for (final item in pendientes) {
        try {
          // VALIDACIÓN ADICIONAL: Solo procesar pagos no sincronizados
          if (item['sincronizado'] == true) {
            ('⏭️ Saltando pago ya sincronizado: ${item['id_temporal']}');
            restantes.add(item);
            continue;
          }

          final pagoData = item['pago'] as Map<String, dynamic>;
          final pago = PagosCuentasXCobrar.fromJson(pagoData);
          
          ('🔍 VERIFICANDO DUPLICADOS - ID Temporal: ${item['id_temporal']}, CpCo: ${pago.cpCoId}, Monto: ${pago.pagoMonto}, Ref: ${pago.pagoNumeroReferencia}');
          
          // VALIDACIÓN ANTI-DUPLICADOS: Verificar si ya existe en el servidor
          final existeEnServidor = await _verificarPagoExisteEnServidor(pago);
          if (existeEnServidor) {
            ('⚠️ DUPLICADO DETECTADO - Pago ya existe en servidor, marcando como sincronizado: ${item['id_temporal']}');
            item['sincronizado'] = true;
            item['fechaSincronizacion'] = DateTime.now().toIso8601String();
            item['razon_sincronizacion'] = 'duplicado_detectado';
            restantes.add(item);
            continue;
          }
          
          ('📤 ENVIANDO AL SERVIDOR - ID Temporal: ${item['id_temporal']}');
          // Intentar enviar el pago
          final resultado = await servicio.insertarPago(pago);
          
          if (resultado['success'] == true) {
            sincronizados++;
            // Marcar como sincronizado en lugar de eliminarlo
            item['sincronizado'] = true;
            item['fechaSincronizacion'] = DateTime.now().toIso8601String();
            restantes.add(item);
            ('✅ Pago sincronizado exitosamente: ${item['id_temporal']}');
          } else {
            // Incrementar intentos y mantener en pendientes si no ha excedido el límite
            item['intentos'] = (item['intentos'] ?? 0) + 1;
            if (item['intentos'] < 3) {
              restantes.add(item);
            } else {
              ('❌ Pago descartado después de 3 intentos: ${item['id_temporal']}');
            }
            ('⚠️ Error sincronizando pago: ${resultado['message']}');
          }
        } catch (e) {
          // Incrementar intentos en caso de excepción
          item['intentos'] = (item['intentos'] ?? 0) + 1;
          if (item['intentos'] < 3) {
            restantes.add(item);
          } else {
            ('❌ Pago descartado después de 3 intentos por error: ${item['id_temporal']}');
          }
          ('❌ Error procesando pago: $e');
        }
      }

      // Actualizar la lista de pendientes
      await guardarJson(_archivoPagosPendientes, restantes);
      
      // Limpiar pagos sincronizados antiguos para evitar acumulación
      await limpiarPagosSincronizadosAntiguos();
      
      final pendientesRestantes = restantes.where((item) => item['sincronizado'] != true).length;
      ('🔄 Sincronización completada. Sincronizados: $sincronizados, Pendientes: $pendientesRestantes');
      
      _completadorSincronizacion!.complete(sincronizados);
      return sincronizados;
    } catch (e) {
      ('❌ Error general en sincronización: $e');
      _completadorSincronizacion!.completeError(e);
      rethrow;
    } finally {
      // Limpiar el estado de sincronización
      _sincronizacionEnProceso = false;
      _completadorSincronizacion = null;
    }
  }

  /// Verifica si un pago ya existe en el servidor para evitar duplicados
  static Future<bool> _verificarPagoExisteEnServidor(PagosCuentasXCobrar pago) async {
    try {
      final servicio = PagoCuentasXCobrarService();
      final pagosServidor = await servicio.listarPagosPorCuenta(pago.cpCoId);
      
      ('🔍 Verificando duplicados - Cuenta: ${pago.cpCoId}, Pagos en servidor: ${pagosServidor.length}');
      ('🔍 Pago a verificar - Monto: ${pago.pagoMonto}, Ref: "${pago.pagoNumeroReferencia}", Fecha: ${pago.pagoFecha}');
      
      // Buscar pagos con características similares (mismo monto, referencia y fecha cercana)
      final fechaPago = pago.pagoFecha;
      for (final pagoServidor in pagosServidor) {
        ('  📊 Comparando con servidor - ID: ${pagoServidor.pagoId}, Monto: ${pagoServidor.pagoMonto}, Ref: "${pagoServidor.pagoNumeroReferencia}", Fecha: ${pagoServidor.pagoFecha}');
        
        // Comparar por monto exacto Y referencia exacta (no vacía)
        if (pagoServidor.pagoMonto == pago.pagoMonto && 
            pagoServidor.pagoNumeroReferencia.isNotEmpty &&
            pago.pagoNumeroReferencia.isNotEmpty &&
            pagoServidor.pagoNumeroReferencia == pago.pagoNumeroReferencia) {
          
          // Verificar si la fecha es del mismo día (tolerancia de 2 horas para ser más estricto)
          final diferenciaTiempo = pagoServidor.pagoFecha.difference(fechaPago).abs();
          if (diferenciaTiempo.inHours <= 2) {
            ('❌ DUPLICADO CONFIRMADO: Servidor ID=${pagoServidor.pagoId}, Local Monto=${pago.pagoMonto}, Ref="${pago.pagoNumeroReferencia}", Diferencia: ${diferenciaTiempo.inMinutes} minutos');
            return true;
          } else {
            ('✅ SIMILAR PERO DIFERENTE TIEMPO: Diferencia de ${diferenciaTiempo.inHours} horas');
          }
        } else {
          ('  ➡️ No coincide - Monto: ${pagoServidor.pagoMonto == pago.pagoMonto ? "✓" : "✗"}, Ref: "${pagoServidor.pagoNumeroReferencia}" vs "${pago.pagoNumeroReferencia}"');
        }
      }
      
      ('✅ No se encontraron duplicados para este pago');
      return false;
    } catch (e) {
      ('❌ Error verificando duplicados en servidor: $e');
      // En caso de error, asumir que no existe para intentar el envío
      return false;
    }
  }

  /// Genera un hash único para un pago para validación de duplicados
  static String _generarHashPago(PagosCuentasXCobrar pago) {
    final contenido = '${pago.cpCoId}_${pago.pagoMonto}_${pago.pagoNumeroReferencia}_${pago.pagoFecha.toIso8601String().substring(0, 10)}';
    return contenido.hashCode.toString();
  }

  /// Limpia pagos ya sincronizados que tienen más de 7 días
  static Future<void> limpiarPagosSincronizadosAntiguos() async {
    try {
      final pendientes = await obtenerPagosPendientesLocal();
      final ahora = DateTime.now();
      
      // Mantener solo pagos no sincronizados o sincronizados recientes (últimos 7 días)
      final pagosFiltrados = pendientes.where((item) {
        if (item['sincronizado'] != true) {
          return true; // Mantener pagos no sincronizados
        }
        
        // Para pagos sincronizados, verificar la fecha
        try {
          final fechaSincronizacion = DateTime.parse(item['fechaSincronizacion']);
          final diferencia = ahora.difference(fechaSincronizacion).inDays;
          return diferencia <= 7; // Mantener solo los últimos 7 días
        } catch (e) {
          return false; // Si no se puede parsear la fecha, eliminar
        }
      }).toList();
      
      if (pagosFiltrados.length < pendientes.length) {
        await guardarJson(_archivoPagosPendientes, pagosFiltrados);
        final eliminados = pendientes.length - pagosFiltrados.length;
        ('🧹 Limpieza automática: $eliminados pagos sincronizados antiguos eliminados');
      }
    } catch (e) {
      ('⚠️ Error en limpieza de pagos sincronizados: $e');
    }
  }

  /// Limpia manualmente pagos duplicados de la cola offline
  static Future<int> limpiarPagosDuplicadosOffline() async {
    try {
      final pendientes = await obtenerPagosPendientesLocal();
      if (pendientes.isEmpty) return 0;

      final Map<String, dynamic> hashesVistosYaEnviados = {};
      final List<dynamic> pagosFiltrados = [];
      int eliminados = 0;

      for (final item in pendientes) {
        try {
          final pagoData = item['pago'] as Map<String, dynamic>;
          final hash = _generarHashPago(PagosCuentasXCobrar.fromJson(pagoData));
          
          // Si ya está marcado como sincronizado, mantenerlo pero no duplicar
          if (item['sincronizado'] == true) {
            if (!hashesVistosYaEnviados.containsKey(hash)) {
              hashesVistosYaEnviados[hash] = item;
              pagosFiltrados.add(item);
            } else {
              eliminados++;
              ('🗑️ Eliminado pago sincronizado duplicado: ${item['id_temporal']}');
            }
          } else {
            // Para pagos no sincronizados, verificar si hay duplicados
            final hashExiste = pagosFiltrados.any((existente) {
              try {
                final existenteData = existente['pago'] as Map<String, dynamic>;
                final hashExistente = _generarHashPago(PagosCuentasXCobrar.fromJson(existenteData));
                return hashExistente == hash && existente['sincronizado'] != true;
              } catch (e) {
                return false;
              }
            });

            if (!hashExiste) {
              pagosFiltrados.add(item);
            } else {
              eliminados++;
              ('🗑️ Eliminado pago pendiente duplicado: ${item['id_temporal']}');
            }
          }
        } catch (e) {
          // Si hay error procesando el item, mantenerlo para no perder datos
          pagosFiltrados.add(item);
          ('⚠️ Error procesando item para limpieza: $e');
        }
      }

      if (eliminados > 0) {
        await guardarJson(_archivoPagosPendientes, pagosFiltrados);
        ('🧹 Limpieza de duplicados completada: $eliminados pagos eliminados, ${pagosFiltrados.length} restantes');
      }

      return eliminados;
    } catch (e) {
      ('❌ Error en limpieza de duplicados: $e');
      return 0;
    }
  }

  /// Elimina todos los pagos pendientes (usar con precaución).
  static Future<void> limpiarPagosPendientes() async {
    await guardarJson(_archivoPagosPendientes, []);
  }

  ///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
  // MÉTODOS DE UTILIDAD Y SECURE STORAGE
  ///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

  /// Guarda un objeto JSON en el almacenamiento seguro bajo la clave `key`.
  static Future<void> guardarJsonSeguro(String key, Object objeto) async {
    try {
      final contenido = jsonEncode(objeto);
      await _secureStorage.write(key: 'cxc_$key', value: contenido);
    } catch (e) {
      rethrow;
    }
  }

  /// Lee y decodifica un JSON almacenado en secure storage bajo `key`.
  static Future<dynamic> leerJsonSeguro(String key) async {
    try {
      final s = await _secureStorage.read(key: 'cxc_$key');
      if (s == null) return null;
      return jsonDecode(s);
    } catch (e) {
      rethrow;
    }
  }

  /// Borra una clave específica del secure storage.
  static Future<void> borrarJsonSeguro(String key) async {
    try {
      await _secureStorage.delete(key: 'cxc_$key');
    } catch (e) {
      rethrow;
    }
  }

  /// Obtiene información de crédito de un cliente específico.
  static Future<Map<String, dynamic>?> obtenerInfoCreditoCliente(int clienteId) async {
    final key = 'credito_cliente_$clienteId';
    final raw = await leerJsonSeguro(key);
    if (raw == null) return null;
    
    try {
      return Map<String, dynamic>.from(raw as Map);
    } catch (_) {
      return null;
    }
  }

  /// Guarda información de crédito de un cliente.
  static Future<void> guardarInfoCreditoCliente(
    int clienteId,
    Map<String, dynamic> infoCredito,
  ) async {
    final key = 'credito_cliente_$clienteId';
    await guardarJsonSeguro(key, infoCredito);
  }

  /// Obtiene el detalle de una cuenta por cobrar específica.
  static Future<CuentasXCobrar?> obtenerDetalleCuentaLocal(int cpCoId) async {
    final key = 'detalle_cuenta_$cpCoId';
    final raw = await leerJsonSeguro(key);
    if (raw == null) return null;
    
    try {
      return CuentasXCobrar.fromJson(Map<String, dynamic>.from(raw as Map));
    } catch (e) {
      ('Error convirtiendo detalle cuenta: $e');
      return null;
    }
  }

  /// Guarda el detalle de una cuenta por cobrar específica.
  static Future<void> guardarDetalleCuenta(
    int cpCoId,
    CuentasXCobrar cuenta,
  ) async {
    final key = 'detalle_cuenta_$cpCoId';
    await guardarJsonSeguro(key, cuenta.toJson());
  }

  /// Lista todos los archivos almacenados en la carpeta offline.
  static Future<List<String>> listarArchivos() async {
    final archivos = <String>[];
    
    // Listar archivos en disco
    final docs = await _directorioDocuments();
    final carpeta = Directory(p.join(docs.path, _carpetaOffline));
    if (await carpeta.exists()) {
      final items = carpeta.listSync();
      for (final item in items) {
        if (item is File) {
          archivos.add(p.basename(item.path));
        }
      }
    }
    
    // Agregar keys de secure storage
    try {
      final all = await _secureStorage.readAll();
      for (final key in all.keys) {
        if (key.startsWith('cxc_json:') || key.startsWith('cxc_bin:')) {
          final nombre = key.substring(key.indexOf(':') + 1);
          if (!archivos.contains(nombre)) {
            archivos.add(nombre);
          }
        }
      }
    } catch (_) {
      // Ignorar errores de secure storage en el listado
    }
    
    return archivos;
  }

  /// Limpia todos los datos offline (usar con precaución).
  static Future<void> limpiarTodosLosDatos() async {
    try {
      // Limpiar archivos principales
      final archivos = [
        _archivoCuentasPorCobrar,
        _archivoFormasPago,
        _archivoResumenClientes,
        _archivoPagosPendientes,
        _archivoTimelineClientes,
      ];
      
      for (final archivo in archivos) {
        await borrar(archivo);
      }
      
      // Limpiar secure storage con prefijo cxc_
      final all = await _secureStorage.readAll();
      for (final key in all.keys) {
        if (key.startsWith('cxc_')) {
          await _secureStorage.delete(key: key);
        }
      }
      
      ('Todos los datos offline de Cuentas por Cobrar han sido limpiados');
    } catch (e) {
      ('Error limpiando datos offline: $e');
      rethrow;
    }
  }

  /// Obtiene estadísticas de los datos almacenados offline.
  static Future<Map<String, dynamic>> obtenerEstadisticas() async {
    try {
      final cuentas = await obtenerCuentasPorCobrarLocal();
      final formasPago = await obtenerFormasPagoLocal();
      final resumenClientes = await obtenerResumenClientesLocal();
      final pagosPendientes = await obtenerPagosPendientesLocal();
      
      // Contar timelines de clientes almacenados
      int timelinesClientes = 0;
      try {
        final all = await _secureStorage.readAll();
        timelinesClientes = all.keys.where((key) => key.startsWith('cxc_timeline_cliente_')).length;
      } catch (_) {
        // Ignorar errores de secure storage
      }
      
      return {
        'cuentasPorCobrar': cuentas.length,
        'formasPago': formasPago.length,
        'resumenClientes': resumenClientes.length,
        'pagosPendientes': pagosPendientes.length,
        'timelinesClientes': timelinesClientes,
        'ultimaActualizacion': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      return {
        'error': e.toString(),
      };
    }
  }

  /// Obtiene estadísticas específicas de un cliente
  static Future<Map<String, dynamic>> obtenerEstadisticasCliente(int clienteId) async {
    try {
      final timeline = await obtenerTimelineClienteLocal(clienteId);
      final infoCredito = await obtenerInfoCreditoCliente(clienteId);
      final historialPagos = await obtenerHistorialPagosLocal(clienteId);
      
      return {
        'clienteId': clienteId,
        'timelineElementos': timeline.length,
        'tieneInfoCredito': infoCredito != null,
        'historialPagos': historialPagos.length,
        'ultimaConsulta': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      return {
        'clienteId': clienteId,
        'error': e.toString(),
      };
    }
  }

  /// Método completo de sincronización optimizada que debe llamarse cuando se detecte conectividad.
  /// Sincroniza datos y envía pagos pendientes de forma eficiente.
  static Future<Map<String, dynamic>> sincronizacionCompleta() async {
    final resultado = <String, dynamic>{
      'exito': false,
      'pagosSincronizados': 0,
      'datosSincronizados': false,
      'errores': <String>[],
      'tiempoEjecucion': 0,
    };

    final inicioTiempo = DateTime.now();

    try {
      ('🚀 Iniciando sincronización completa optimizada...');

      // 1. Sincronizar pagos pendientes con alta prioridad
      try {
        final pagosSincronizados = await sincronizarPagosPendientes();
        resultado['pagosSincronizados'] = pagosSincronizados;
        ('✅ Pagos sincronizados: $pagosSincronizados');
      } catch (e) {
        resultado['errores'].add('Error sincronizando pagos: $e');
        ('❌ Error sincronizando pagos: $e');
      }

      // 2. Sincronizar datos básicos en paralelo (formas de pago, etc.)
      try {
        await Future.wait([
          sincronizarFormasPago(),
          // Otros datos críticos se pueden agregar aquí
        ]);
        resultado['datosSincronizados'] = true;
        ('✅ Datos básicos sincronizados');
      } catch (e) {
        resultado['errores'].add('Error sincronizando datos básicos: $e');
        ('❌ Error sincronizando datos básicos: $e');
      }

      // 3. Sincronización de datos detallados (en background, baja prioridad)
      _sincronizarDatosDetalladosEnBackground();

      resultado['exito'] = resultado['errores'].isEmpty;
      
    } catch (e) {
      resultado['errores'].add('Error general en sincronización: $e');
      ('❌ Error general en sincronización completa: $e');
    }

    final tiempoEjecucion = DateTime.now().difference(inicioTiempo).inMilliseconds;
    resultado['tiempoEjecucion'] = tiempoEjecucion;
    
    ('⏱️ Sincronización completa finalizada en ${tiempoEjecucion}ms');
    return resultado;
  }

  /// Sincroniza datos detallados en background sin bloquear operaciones críticas
  static Future<void> _sincronizarDatosDetalladosEnBackground() async {
    try {
      ('📡 Iniciando sincronización de datos detallados en background...');
      
      // Sincronizar datos menos críticos sin await para no bloquear
      Future.wait([
        sincronizarCuentasPorCobrar(),
        sincronizarResumenClientes(),
      ]).then((_) {
        ('✅ Datos detallados sincronizados en background');
      }).catchError((e) {
        ('⚠️ Error en sincronización de background: $e');
      });
      
    } catch (e) {
      ('Error iniciando sincronización de background: $e');
    }
  }

  /// Método completo de sincronización que debe llamarse cuando se detecte conectividad.
  /// Sincroniza datos y envía pagos pendientes.
  static Future<Map<String, dynamic>> sincronizacionCompletaLegacy() async {
    final Map<String, dynamic> resultado = {
      'exito': false,
      'sincronizacionDatos': false,
      'pagosSincronizados': 0,
      'errores': <String>[],
    };

    try {
      // 1. Sincronizar datos frescos desde el servidor
      try {
        await sincronizarTodo();
        resultado['sincronizacionDatos'] = true;
        ('✅ Datos sincronizados correctamente');
      } catch (e) {
        resultado['errores'].add('Error sincronizando datos: $e');
        ('❌ Error sincronizando datos: $e');
      }

      // 2. Enviar pagos pendientes
      try {
        final pagosSincronizados = await sincronizarPagosPendientes();
        resultado['pagosSincronizados'] = pagosSincronizados;
        ('✅ $pagosSincronizados pagos sincronizados');
      } catch (e) {
        resultado['errores'].add('Error sincronizando pagos: $e');
        ('❌ Error sincronizando pagos: $e');
      }

      // 3. Determinar éxito general
      resultado['exito'] = resultado['sincronizacionDatos'] == true || 
                          resultado['pagosSincronizados'] > 0;

      return resultado;
    } catch (e) {
      resultado['errores'].add('Error general: $e');
      return resultado;
    }
  }

  /// Inicializa la sincronización automática al iniciar la aplicación
  static Future<void> inicializarSincronizacionAutomatica() async {
    try {
      ('🔄 Inicializando sincronización automática...');
      
      // Verificar conectividad inmediatamente
      final connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult != ConnectivityResult.none) {
        // Ejecutar sincronización inmediata en background
        sincronizacionCompleta().then((resultado) {
          ('✅ Sincronización inicial completada: ${resultado['pagosSincronizados']} pagos sincronizados');
        }).catchError((e) {
          ('⚠️ Error en sincronización inicial: $e');
        });
      }
      
      // Configurar sincronización periódica (cada 5 minutos cuando hay conectividad)
      _configurarSincronizacionPeriodica();
      
    } catch (e) {
      ('Error inicializando sincronización automática: $e');
    }
  }

  /// Configura la sincronización periódica
  static void _configurarSincronizacionPeriodica() {
    try {
      // Usar un timer para verificar periódicamente si hay datos pendientes (cada 15 minutos)
      Timer.periodic(const Duration(minutes: 15), (timer) async {
        try {
          final connectivityResult = await Connectivity().checkConnectivity();
          if (connectivityResult != ConnectivityResult.none) {
            final pendientes = await obtenerPagosPendientesLocal();
            final pagosNoSincronizados = pendientes.where((item) => item['sincronizado'] != true).length;
            if (pagosNoSincronizados > 0) {
              ('🔄 Sincronización periódica: $pagosNoSincronizados pagos no sincronizados detectados');
              sincronizarPagosPendientes().then((sincronizados) {
                if (sincronizados > 0) {
                  ('✅ Sincronización periódica: $sincronizados pagos sincronizados');
                }
              }).catchError((e) {
                ('⚠️ Error en sincronización periódica: $e');
              });
            } else if (pendientes.isNotEmpty) {
              ('ℹ️ Sincronización periódica: ${pendientes.length} pagos en cola pero todos ya sincronizados');
            }
          }
        } catch (e) {
          ('Error en verificación periódica: $e');
        }
      });
    } catch (e) {
      ('Error configurando sincronización periódica: $e');
    }
  }

  /// Consolidación de sincronización completa de Cuentas por Cobrar
  /// Método wrapper que ejecuta sincronizacionCompleta para mantener consistencia con otros servicios
  static Future<void> sincronizarCuentasPorCobrar_Todo() async {
    try {
      final resultado = await sincronizacionCompleta();
      ('✅ Sincronización completa de Cuentas por Cobrar finalizada');
      ('   - Éxito: ${resultado['exito']}');
      ('   - Datos sincronizados: ${resultado['sincronizacionDatos']}');
      ('   - Pagos sincronizados: ${resultado['pagosSincronizados']}');
    } catch (e) {
      ('❌ Error en sincronización completa de Cuentas por Cobrar: $e');
      rethrow;
    }
  }

  /// Actualiza los datos locales inmediatamente con el nuevo pago para reflejar cambios
  static Future<void> _actualizarDatosLocalesConPago(PagosCuentasXCobrar pago) async {
    try {
      final cpCoId = pago.cpCoId;
      final montoPago = pago.pagoMonto;

      // 1. Actualizar el detalle de la cuenta específica si existe
      final cuentaDetalle = await obtenerDetalleCuentaLocal(cpCoId);
      if (cuentaDetalle != null) {
        final saldoActual = cuentaDetalle.cpCo_Saldo ?? cuentaDetalle.totalPendiente ?? 0;
        final nuevoSaldo = saldoActual - montoPago;
        
        // Crear una nueva instancia con el saldo actualizado (debido a campos finales)
        final cuentaActualizada = CuentasXCobrar.fromJson({
          ...cuentaDetalle.toJson(),
          'cpCo_Saldo': nuevoSaldo > 0 ? nuevoSaldo : 0,
          'totalPendiente': nuevoSaldo > 0 ? nuevoSaldo : 0,
          'ultimoMovimiento': DateTime.now().toIso8601String(),
        });
        
        // Guardar el detalle actualizado
        await guardarDetalleCuenta(cpCoId, cuentaActualizada);
        ('📊 Detalle cuenta $cpCoId actualizado: Saldo=${_formatCurrency(nuevoSaldo)}');
      }

      // 2. Actualizar también en el resumen de clientes
      final resumenClientes = await obtenerResumenClientesLocal();
      bool clienteActualizado = false;
      
      for (int i = 0; i < resumenClientes.length; i++) {
        final item = resumenClientes[i];
        if (item['cpCo_Id'] == cpCoId) {
          final saldoActual = (item['totalPendiente'] ?? item['cpCo_Saldo'] ?? 0).toDouble();
          final nuevoSaldo = saldoActual - montoPago;
          
          // Actualizar el saldo en el resumen
          item['totalPendiente'] = nuevoSaldo > 0 ? nuevoSaldo : 0;
          item['cpCo_Saldo'] = nuevoSaldo > 0 ? nuevoSaldo : 0;
          
          clienteActualizado = true;
          ('📋 Resumen cliente actualizado: Cuenta $cpCoId, Nuevo saldo=${_formatCurrency(nuevoSaldo)}');
          break;
        }
      }
      
      if (clienteActualizado) {
        // Guardar el resumen actualizado
        await guardarJson(_archivoResumenClientes, resumenClientes);
      }

      // 3. Agregar el pago al historial local inmediatamente
      await _agregarPagoAlHistorialLocal(pago);
      
      ('✅ Datos locales actualizados inmediatamente para cuenta $cpCoId');
    } catch (e) {
      ('❌ Error actualizando datos locales con pago: $e');
      rethrow;
    }
  }

  /// Actualiza el timeline del cliente inmediatamente después de un pago
  static Future<void> _actualizarTimelineInmediato(PagosCuentasXCobrar pago) async {
    try {
      // Obtener los datos actualizados de la cuenta desde el resumen de clientes
      final resumenClientes = await obtenerResumenClientesLocal();
      
      // Buscar la cuenta específica y obtener su cliente ID
      int? clienteId;
      for (final item in resumenClientes) {
        if (item['cpCo_Id'] == pago.cpCoId) {
          clienteId = item['clie_Id'];
          break;
        }
      }
      
      if (clienteId != null) {
        // Obtener el timeline actual del cliente
        final timelineKey = 'timeline_cliente_$clienteId';
        final timelineActual = await leerJsonSeguro(timelineKey) ?? [];
        final listaTimeline = List.from(timelineActual as List);
        
        // Buscar y actualizar la cuenta específica en el timeline
        bool cuentaActualizada = false;
        for (int i = 0; i < listaTimeline.length; i++) {
          final item = listaTimeline[i];
          if (item['cpCo_Id'] == pago.cpCoId) {
            // Actualizar el saldo en el timeline
            final saldoAnterior = (item['totalPendiente'] ?? item['cpCo_Saldo'] ?? 0).toDouble();
            final nuevoSaldo = saldoAnterior - pago.pagoMonto;
            
            item['cpCo_Saldo'] = nuevoSaldo > 0 ? nuevoSaldo : 0;
            item['totalPendiente'] = item['cpCo_Saldo'];
            
            if (nuevoSaldo <= 0) {
              item['cpCo_Saldada'] = true;
              item['cpCo_FechaSaldada'] = DateTime.now().toIso8601String();
            }
            
            // Actualizar fecha de último pago
            item['ultimoPago'] = DateTime.now().toIso8601String();
            
            listaTimeline[i] = item;
            cuentaActualizada = true;
            break;
          }
        }
        
        // Guardar el timeline actualizado si se hicieron cambios
        if (cuentaActualizada) {
          await guardarJsonSeguro(timelineKey, listaTimeline);
          ('✅ Timeline de cliente $clienteId actualizado inmediatamente');
        }
      }
    } catch (e) {
      ('⚠️ Error actualizando timeline inmediatamente: $e');
    }
  }
}

import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sidcop_mobile/models/ventas/ProductosDescuentoViewModel.dart';
import 'package:sidcop_mobile/services/VentaService.dart';
import 'package:sidcop_mobile/services/ProductosService.dart';
import 'package:sidcop_mobile/models/ventas/ProductosDescuentoViewModel.dart';
import 'package:sidcop_mobile/models/ventas/VentaInsertarViewModel.dart';

class VentasOfflineService {
  static final FlutterSecureStorage _secureStorage = FlutterSecureStorage();
  static const String _archivoFacturas = 'facturas_por_vendedor.json';
  static const String _archivoFacturaCompletaPrefix = 'factura_completa_';

  /// Sincroniza y guarda todas las facturas del vendedor actual.
  static Future<List<dynamic>> sincronizarFacturasPorVendedor(int vendedorId) async {
    final servicio = VentaService();
    final resp = await servicio.listarVentasPorVendedor(vendedorId);
    final facturas = resp?['data'] ?? [];
    await _secureStorage.write(
      key: 'json:$_archivoFacturas',
      value: jsonEncode(facturas),
    );
    return facturas;
  }

  /// Lista las facturas guardadas offline.
  static Future<List<dynamic>> listarFacturasOffline() async {
    final s = await _secureStorage.read(key: 'json:$_archivoFacturas');
    if (s == null) return [];
    try {
      return List.from(jsonDecode(s) as List);
    } catch (_) {
      return [];
    }
  }

  /// Guarda una factura completa offline bajo una clave única.
  static Future<void> guardarFacturaCompletaOffline(int facturaId, Map<String, dynamic> factura) async {
    final key = 'json:${_archivoFacturaCompletaPrefix}$facturaId';
    await _secureStorage.write(key: key, value: jsonEncode(factura));
  }

  /// Obtiene una factura completa offline por su ID.
  static Future<Map<String, dynamic>?> obtenerFacturaCompletaOffline(int facturaId) async {
    final key = 'json:${_archivoFacturaCompletaPrefix}$facturaId';
    final s = await _secureStorage.read(key: key);
    if (s == null) return null;
    try {
      return jsonDecode(s) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  /// Guarda la lista de ventas/facturas offline in secure storage.
  static Future<void> guardarVentasOffline(List<dynamic> ventas) async {
    await _secureStorage.write(
      key: 'json:$_archivoFacturas',
      value: jsonEncode(ventas),
    );
  }

  /// Lee la lista de ventas/facturas offline desde secure storage.
  static Future<List<dynamic>> obtenerVentasOffline() async {
    final s = await _secureStorage.read(key: 'json:facturas_por_vendedor.json');
    if (s == null) {
      print('[DEBUG] No hay historial offline guardado.');
      return [];
    }
    try {
      final ventas = List.from(jsonDecode(s) as List);
      print('[DEBUG] Historial offline cargado. Total ventas: ${ventas.length}');
      return ventas;
    } catch (e) {
      print('[DEBUG] Error leyendo historial offline: $e');
      return [];
    }
  }

  static Future<void> descargarYGuardarProductosConDescuentoOffline(int clieId, int vendId) async {
    try {
      print('[SYNC] 📥 Descargando productos para cliente $clieId, vendedor $vendId...');
      
      final productosService = ProductosService();
      final productos = await productosService.getProductosConDescuentoPorClienteVendedor(clieId, vendId);
      
      print('[SYNC] ✅ API devolvió ${productos.length} productos');
      
      // Convertir a JSON
      final productosJson = productos.map((p) => p.toJson()).toList();
      final jsonString = jsonEncode(productosJson);
      
      print('[SYNC] 💾 Guardando en almacenamiento seguro (${jsonString.length} caracteres)...');
      print('[SYNC] 🔑 Clave: json:productos_descuento_${clieId}_$vendId');
      
      await _secureStorage.write(
        key: 'json:productos_descuento_${clieId}_$vendId',
        value: jsonString,
      );
      
      print('[SYNC] ✅ ¡Guardado exitosamente! ${productos.length} productos para cliente $clieId');
    } catch (e) {
      print('[SYNC] ❌ Error descargando productos para cliente $clieId, vendedor $vendId: $e');
      // No relanzar la excepción para permitir que continúe la sincronización
    }
  }
  
  static Future<List<ProductoConDescuento>> cargarProductosConDescuentoOffline(int clieId, int vendId) async {
    print('[STORAGE] 🔍 Leyendo de almacenamiento seguro...');
    print('[STORAGE] 🔑 Clave: json:productos_descuento_${clieId}_$vendId');
    
    final s = await _secureStorage.read(key: 'json:productos_descuento_${clieId}_$vendId');
    
    if (s == null) {
      print('[STORAGE] ❌ No se encontró nada en el almacenamiento para esta clave');
      return [];
    }
    
    print('[STORAGE] ✅ Datos encontrados en almacenamiento (${s.length} caracteres)');
    
    try {
      final List<dynamic> list = jsonDecode(s);
      print('[STORAGE] ✅ JSON decodificado exitosamente');
      
      final productos = list.map((json) => ProductoConDescuento.fromJson(json)).toList();
      print('[STORAGE] ✅ Productos parseados: ${productos.length} productos');
      
      return productos;
    } catch (e) {
      print('[STORAGE] ❌ Error parseando JSON: $e');
      return [];
    }
  }

  /// Sincroniza todas las facturas y guarda cada factura completa offline.
  static Future<void> sincronizarTodo(int vendedorId) async {
    final facturas = await sincronizarFacturasPorVendedor(vendedorId);
    await guardarVentasOffline(facturas);
    // Opcional: guardar cada factura completa offline si necesitas detalles
    final servicio = VentaService();
    for (final f in facturas) {
      final facturaId = f['fact_Id'] ?? f['factId'];
      if (facturaId != null) {
        final detalle = await servicio.obtenerFacturaCompleta(facturaId);
        if (detalle != null && detalle['success'] == true) {
          await guardarFacturaCompletaOffline(facturaId, detalle['data']);
        }
      }
    }
  }

  static Future<void> descargarYGuardarProductosConDescuentoDeTodosLosClientesOffline(int vendedorId, List<int> clientesIds) async {
    for (final clieId in clientesIds) {
      print('[DEBUG] Descargando productos del cliente id: $clieId para vendedor id: $vendedorId');
      try {
        await descargarYGuardarProductosConDescuentoOffline(clieId, vendedorId);
      } catch (e) {
        print('[DEBUG] Error procesando cliente $clieId: $e');
        // Continuar con el siguiente cliente aunque falle este
      }
    }
  }

  static Future<void> guardarVentaOffline({
    required VentaInsertarViewModel ventaModel,
    required Map<int, double> selectedProducts,
    required List<ProductoConDescuento> allProducts,
    required String metodoPago,
    required int? clienteId,
    required int? vendedorId,
    required Map<String, dynamic>? selectedAddress,
    required String clienteNombre,
    required double totalCuenta,
  }) async {
    final now = DateTime.now();
    final idNegativo = -now.millisecondsSinceEpoch;
    final ventaOffline = {
      'fact_Id': idNegativo,
      'ventaModel': ventaModel.toJson(),
      'selectedProducts': selectedProducts.map((k, v) => MapEntry(k.toString(), v)),
      'allProducts': allProducts.map((p) => p.toJson()).toList(),
      'metodoPago': metodoPago,
      'clienteId': clienteId,
      'vendedorId': vendedorId,
      'selectedAddress': selectedAddress,
      'fechaGuardado': now.toIso8601String(),
      'offline': true,
      'fact_Numero': ventaModel.factNumero,
      // Agrega los campos para visualización
      'fact_Total': totalCuenta,
      'cliente': clienteNombre, // Si tienes el nombre, ponlo aquí
      'fact_FechaEmision': now.toIso8601String(),
    };
  
    // Guardar en ventas pendientes
    final keyPendientes = 'ventas_pendientes';
    final sPendientes = await _secureStorage.read(key: keyPendientes);
    List<dynamic> ventasPendientes = sPendientes == null ? [] : List.from(jsonDecode(sPendientes));
    ventasPendientes.insert(0, ventaOffline); // Insertar al inicio
    await _secureStorage.write(key: keyPendientes, value: jsonEncode(ventasPendientes));
    print('[DEBUG] Venta offline guardada en pendientes. Total pendientes: ${ventasPendientes.length}');
  
    // Guardar en historial local (facturas_por_vendedor.json)
    final keyHistorial = 'json:facturas_por_vendedor.json';
    final sHistorial = await _secureStorage.read(key: keyHistorial);
    List<dynamic> historial = sHistorial == null ? [] : List.from(jsonDecode(sHistorial));
    historial.insert(0, ventaOffline); // Insertar al inicio
    await _secureStorage.write(key: keyHistorial, value: jsonEncode(historial));
    print('[DEBUG] Venta offline guardada en historial. Total historial: ${historial.length}');
  }

  static Future<void> sincronizarVentasPendientes() async {
    try {
      final key = 'ventas_pendientes';
      final s = await _secureStorage.read(key: key);
      if (s == null) return;

      List<dynamic> ventasPendientes = List.from(jsonDecode(s));
      if (ventasPendientes.isEmpty) return;

      final ventaService = VentaService();
      List<dynamic> ventasNoEnviadas = [];

      for (final venta in ventasPendientes) {
        try {
          final ventaModel = VentaInsertarViewModel.fromJson(venta['ventaModel']);
          final resultado = await ventaService.insertarFacturaConValidacion(ventaModel);

          if (resultado?['success'] != true) {
            ventasNoEnviadas.add(venta); // Si falla, mantenerla en la lista
          }
        } catch (e) {
          print('[DEBUG] Error enviando venta pendiente: $e');
          ventasNoEnviadas.add(venta); // Si hay error, mantenerla en la lista
        }
      }

      // Guardar solo las que no se pudieron enviar
      await _secureStorage.write(key: key, value: jsonEncode(ventasNoEnviadas));
    } catch (e) {
      print('[DEBUG] Error en sincronizarVentasPendientes: $e');
      // No relanzar la excepción para no romper el flujo de carga
    }
  }
}
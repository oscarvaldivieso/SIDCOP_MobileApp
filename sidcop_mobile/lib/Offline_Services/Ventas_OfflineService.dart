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
    final s = await _secureStorage.read(key: 'json:$_archivoFacturas');
    if (s == null) return [];
    try {
      return List.from(jsonDecode(s) as List);
    } catch (_) {
      return [];
    }
  }

  static Future<void> descargarYGuardarProductosConDescuentoOffline(int clieId, int vendId) async {
    final productosService = ProductosService();
    final productos = await productosService.getProductosConDescuentoPorClienteVendedor(clieId, vendId);
    // Convertir a JSON
    final productosJson = productos.map((p) => p.toJson()).toList();
    await _secureStorage.write(
      key: 'json:productos_descuento_${clieId}_$vendId',
      value: jsonEncode(productosJson),
    );
  }
  
  static Future<List<ProductoConDescuento>> cargarProductosConDescuentoOffline(int clieId, int vendId) async {
    final s = await _secureStorage.read(key: 'json:productos_descuento_${clieId}_$vendId');
    if (s == null) return [];
    final List<dynamic> list = jsonDecode(s);
    return list.map((json) => ProductoConDescuento.fromJson(json)).toList();
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
      print('Guardando lista de productos del cliente id: $clieId para vendedor id: $vendedorId');
      await descargarYGuardarProductosConDescuentoOffline(clieId, vendedorId);
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
      'fechaGuardado': DateTime.now().toIso8601String(),
      'offline': true, // Marca la venta como offline
      'fact_Numero': ventaModel.factNumero, // Para buscarla fácil
    };
  
    // Guardar en ventas pendientes
    final keyPendientes = 'ventas_pendientes';
    final sPendientes = await _secureStorage.read(key: keyPendientes);
    List<dynamic> ventasPendientes = sPendientes == null ? [] : List.from(jsonDecode(sPendientes));
    ventasPendientes.add(ventaOffline);
    await _secureStorage.write(key: keyPendientes, value: jsonEncode(ventasPendientes));
  
    // Guardar en historial local (facturas_por_vendedor.json)
    final keyHistorial = 'json:facturas_por_vendedor.json';
    final sHistorial = await _secureStorage.read(key: keyHistorial);
    List<dynamic> historial = sHistorial == null ? [] : List.from(jsonDecode(sHistorial));
    historial.add(ventaOffline);
    await _secureStorage.write(key: keyHistorial, value: jsonEncode(historial));
  }

  static Future<void> sincronizarVentasPendientes() async {
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
        ventasNoEnviadas.add(venta); // Si hay error, mantenerla en la lista
      }
    }

    // Guardar solo las que no se pudieron enviar
    await _secureStorage.write(key: key, value: jsonEncode(ventasNoEnviadas));
  }
}
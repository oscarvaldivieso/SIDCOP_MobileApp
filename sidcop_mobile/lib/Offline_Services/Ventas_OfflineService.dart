import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sidcop_mobile/models/ventas/ProductosDescuentoViewModel.dart';
import 'package:sidcop_mobile/services/VentaService.dart';
import 'package:sidcop_mobile/services/ProductosService.dart';
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
      final productosService = ProductosService();
      final productos = await productosService.getProductosConDescuentoPorClienteVendedor(clieId, vendId);
      
      // Convertir a JSON
      final productosJson = productos.map((p) => p.toJson()).toList();
      final jsonString = jsonEncode(productosJson);
      
      await _secureStorage.write(
        key: 'json:productos_descuento_${clieId}_$vendId',
        value: jsonString,
      );
      
      // Guardar timestamp de última sincronización
      await _secureStorage.write(
        key: 'timestamp_productos_${clieId}_$vendId',
        value: DateTime.now().toIso8601String(),
      );
      
      print('[SYNC] ✅ Productos guardados para cliente $clieId: ${productos.length} productos');
    } catch (e) {
      print('[SYNC] ❌ Error descargando productos cliente $clieId: $e');
    }
  }
  
  static Future<List<ProductoConDescuento>> cargarProductosConDescuentoOffline(int clieId, int vendId) async {
    try {
      final s = await _secureStorage.read(key: 'json:productos_descuento_${clieId}_$vendId');
      if (s == null) {
        print('[STORAGE] ℹ️ No hay productos guardados para cliente $clieId');
        return [];
      }
      
      final List<dynamic> list = jsonDecode(s);
      final productos = list.map((json) => ProductoConDescuento.fromJson(json)).toList();
      
      // Obtener fecha de última sincronización
      final timestamp = await _secureStorage.read(key: 'timestamp_productos_${clieId}_$vendId');
      print('[STORAGE] ✅ Cargados ${productos.length} productos (actualizado: $timestamp)');
      
      return productos;
    } catch (e) {
      print('[STORAGE] ❌ Error cargando productos: $e');
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

  /// Obtiene la fecha de última actualización de los productos
  static Future<String?> obtenerFechaActualizacionProductos(int clieId, int vendId) async {
    return await _secureStorage.read(key: 'timestamp_productos_${clieId}_$vendId');
  }

  static Future<void> descargarYGuardarProductosConDescuentoDeTodosLosClientesOffline(int vendedorId, List<int> clientesIds) async {
    int descargados = 0;
    int errores = 0;
    
    for (final clieId in clientesIds) {
      try {
        await descargarYGuardarProductosConDescuentoOffline(clieId, vendedorId);
        descargados++;
      } catch (e) {
        errores++;
      }
    }
    
    print('[SYNC] 📊 Descarga completada: $descargados OK, $errores errores de ${clientesIds.length} clientes');
  }

  static Future<int> guardarVentaOffline({
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
    
    // Construir detalles de factura a partir de selectedProducts
    final List<dynamic> detalles = [];
    for (var productId in selectedProducts.keys) {
      final cantidad = selectedProducts[productId]!;
      final producto = allProducts.firstWhere(
        (p) => p.prodId == productId,
        orElse: () => ProductoConDescuento(
          prodId: productId,
          prodDescripcionCorta: 'Producto',
          prodPrecioUnitario: 0.0,
          cantidadDisponible: 0,
          descuentosEscala: [],
          listasPrecio: [],
          prod_Impulsado: false,
          prodPagaImpuesto: 'N',
          impuValor: 0.0,
          impuId: 0,
          prodCostoTotal: 0.0,
        ),
      );
      
      detalles.add({
        'prod_Id': productId,
        'prod_Descripcion': producto.prodDescripcionCorta,
        'prod_PagaImpuesto': producto.prodPagaImpuesto,
        'prod_CodigoBarra': '',
        'faDe_Cantidad': cantidad,
        'faDe_PrecioUnitario': producto.prodPrecioUnitario,
        'faDe_PorcentajeDescuento': 0.0,
        'faDe_Monto': producto.prodPrecioUnitario * cantidad,
      });
    }
    
    final ventaOffline = {
      'fact_Id': idNegativo,
      'fact_Numero': ventaModel.factNumero,
      'fact_FechaEmision': now.toIso8601String(),
      'fact_Anulado': false,
      'cliente': clienteNombre,
      'fact_Total': totalCuenta,
      'offline': true,
      'detalleFactura': detalles,
      'ventaModel': ventaModel.toJson(),
      'selectedProducts': selectedProducts.map((k, v) => MapEntry(k.toString(), v)),
      'allProducts': allProducts.map((p) => p.toJson()).toList(),
      'metodoPago': metodoPago,
      'clienteId': clienteId,
      'vendedorId': vendedorId,
      'selectedAddress': selectedAddress,
      'fechaGuardado': now.toIso8601String(),
    };
  
    // Guardar factura completa offline con ID negativo
    await guardarFacturaCompletaOffline(idNegativo.toInt(), ventaOffline);
    print('[OFFLINE] ✅ Factura offline guardada con ID: $idNegativo');
    
    // Guardar en ventas pendientes
    final keyPendientes = 'ventas_pendientes';
    final sPendientes = await _secureStorage.read(key: keyPendientes);
    List<dynamic> ventasPendientes = sPendientes == null ? [] : List.from(jsonDecode(sPendientes));
    ventasPendientes.insert(0, ventaOffline);
    await _secureStorage.write(key: keyPendientes, value: jsonEncode(ventasPendientes));
    print('[OFFLINE] ✅ Venta pendiente guardada. Total: ${ventasPendientes.length}');
  
    // Guardar en historial local
    final keyHistorial = 'json:facturas_por_vendedor.json';
    final sHistorial = await _secureStorage.read(key: keyHistorial);
    List<dynamic> historial = sHistorial == null ? [] : List.from(jsonDecode(sHistorial));
    historial.insert(0, ventaOffline);
    await _secureStorage.write(key: keyHistorial, value: jsonEncode(historial));
    print('[OFFLINE] ✅ Factura agregada al historial. Total: ${historial.length}');
    
    return idNegativo;
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
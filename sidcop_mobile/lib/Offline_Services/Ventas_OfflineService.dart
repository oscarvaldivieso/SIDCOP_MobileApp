import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sidcop_mobile/services/VentaService.dart';

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

  // Puedes agregar más funciones offline para ventas aquí.
}

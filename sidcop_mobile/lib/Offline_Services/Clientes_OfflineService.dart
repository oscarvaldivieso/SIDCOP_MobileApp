// Archivo para manejar clientes en modo offline
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sidcop_mobile/services/ClientesService.dart';
import 'package:sidcop_mobile/services/SyncService.dart';
import 'package:sidcop_mobile/services/DropdownDataService.dart';

class ClientesOfflineService {
  static const String _archivoClientes = 'clientes.json';
  static const String _archivoClientesPendientes = 'clientes_pendientes.json';
  static final FlutterSecureStorage _secureStorage = FlutterSecureStorage();

  /// Guarda clientes en un archivo JSON
  static Future<void> guardarClientes(List<Map<String, dynamic>> clientes) async {
    await guardarJson(_archivoClientes, clientes);
  }

  /// Carga clientes desde un archivo JSON
  static Future<List<Map<String, dynamic>>> cargarClientes() async {
    final raw = await leerJson(_archivoClientes);
    if (raw == null) return [];
    try {
      return List<Map<String, dynamic>>.from(raw as List);
    } catch (e) {
      return [];
    }
  }

  /// Guarda clientes pendientes en un archivo JSON
  static Future<void> guardarClientesPendientes(List<Map<String, dynamic>> clientes) async {
    await guardarJson(_archivoClientesPendientes, clientes);
  }

  /// Carga clientes pendientes desde un archivo JSON
  static Future<List<Map<String, dynamic>>> cargarClientesPendientes() async {
    final raw = await leerJson(_archivoClientesPendientes);
    if (raw == null) return [];
    try {
      return List<Map<String, dynamic>>.from(raw as List);
    } catch (e) {
      return [];
    }
  }

  /// Sincroniza clientes pendientes con el servidor
  static Future<void> sincronizarClientesPendientes() async {
    final pendientes = await cargarClientesPendientes();
    if (pendientes.isEmpty) return;

    final hasConnection = await SyncService.hasInternetConnection();
    if (!hasConnection) {
      print('No hay conexión a internet. Sincronización pospuesta.');
      return;
    }

    final dropdownService = DropdownDataService();
    final noSincronizados = <Map<String, dynamic>>[];

    for (final cliente in pendientes) {
      try {
        final response = await dropdownService.insertCliente(cliente);
        if (response['success'] != true) {
          print('Error al sincronizar cliente: ${cliente['id']}');
          noSincronizados.add(cliente);
        }
      } catch (e) {
        print('Excepción al sincronizar cliente: ${cliente['id']} - $e');
        noSincronizados.add(cliente);
      }
    }

    if (noSincronizados.isNotEmpty) {
      print('Clientes no sincronizados: ${noSincronizados.length}');
    }

    await guardarClientesPendientes(noSincronizados);
  }

  /// Guarda un objeto JSON en almacenamiento seguro
  static Future<void> guardarJson(String nombreArchivo, Object objeto) async {
    final contenido = jsonEncode(objeto);
    await _secureStorage.write(key: nombreArchivo, value: contenido);
  }

  /// Lee un objeto JSON desde almacenamiento seguro
  static Future<dynamic> leerJson(String nombreArchivo) async {
    final contenido = await _secureStorage.read(key: nombreArchivo);
    if (contenido == null) return null;
    return jsonDecode(contenido);
  }

  /// Guarda el detalle de un cliente en almacenamiento local
  static Future<void> guardarDetalleCliente(Map<String, dynamic> cliente) async {
    final clientes = await cargarClientes();
    final index = clientes.indexWhere((c) => c['clie_Id'] == cliente['clie_Id']);

    if (index != -1) {
      clientes[index] = cliente;
    } else {
      clientes.add(cliente);
    }

    await guardarClientes(clientes);
  }

  /// Carga el detalle de un cliente desde almacenamiento local
  static Future<Map<String, dynamic>?> cargarDetalleCliente(int clienteId) async {
    final clientes = await cargarClientes();
    final cliente = clientes.firstWhere(
      (c) => c['clie_Id'] == clienteId,
      orElse: () => <String, dynamic>{},
    );
    return cliente.isNotEmpty ? cliente : null;
  }

  /// Guarda las colonias en almacenamiento local
  static Future<void> guardarColonias(List<Map<String, dynamic>> colonias) async {
    await guardarJson('colonias.json', colonias);
  }

  /// Carga las colonias desde almacenamiento local
  static Future<List<Map<String, dynamic>>> cargarColonias() async {
    final raw = await leerJson('colonias.json');
    if (raw == null) return [];
    try {
      return List<Map<String, dynamic>>.from(raw);
    } catch (e) {
      return [];
    }
  }

  /// Maneja la carga de colonias considerando el modo offline
  static Future<List<Map<String, dynamic>>> manejarColoniasOffline(Future<List<Map<String, dynamic>>> Function() fetchColoniasOnline) async {
    final hasConnection = await SyncService.hasInternetConnection();

    if (hasConnection) {
      try {
        final colonias = await fetchColoniasOnline();
        await guardarColonias(colonias);
        return colonias;
      } catch (e) {
        print('Error al cargar colonias en línea: $e');
      }
    }

    // Si no hay conexión o falla la carga en línea, cargar desde almacenamiento local
    return await cargarColonias();
  }

  /// Guarda un cliente y sus direcciones en modo offline
  static Future<void> saveClienteOffline(
      Map<String, dynamic> cliente,
      List<Map<String, dynamic>> direcciones) async {
    final clientesPendientes = await cargarClientesPendientes();
    final clienteConDirecciones = {
      ...cliente,
      'direcciones': direcciones,
    };
    clientesPendientes.add(clienteConDirecciones);
    await guardarClientesPendientes(clientesPendientes);
    print('Cliente guardado offline con éxito.');
  }
}
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sidcop_mobile/services/PedidosService.Dart';
import 'package:sidcop_mobile/models/PedidosViewModel.Dart';
import 'package:sidcop_mobile/services/GlobalService.Dart';

class PedidosScreenOffline {
  static const _storage = FlutterSecureStorage();
  static const String _carpetaOffline = 'offline_pedidos';
  static const String _pedidosKey = 'pedidos_list';
  static const String _pedidoDetalleKey = 'pedido_detalle_';
  static const String _pedidosPendientesKey = 'pedidos_pendientes';
  
  // Devuelve el directorio de documents
  static Future<Directory> _directorioDocuments() async {
    return await getApplicationDocumentsDirectory();
  }

  // Construye la ruta absoluta para un archivo
  static Future<String> _rutaArchivo(String nombreRelativo) async {
    final docs = await _directorioDocuments();
    final ruta = p.join(docs.path, _carpetaOffline, nombreRelativo);
    final dirPadre = Directory(p.dirname(ruta));
    if (!await dirPadre.exists()) {
      await dirPadre.create(recursive: true);
    }
    return ruta;
  }

  // Guarda datos en el almacenamiento seguro y en archivo
  static Future<void> _guardarDatos(String clave, dynamic datos) async {
    try {
      final contenido = jsonEncode(datos);
      // Guardar en secure storage
      await _storage.write(key: clave, value: contenido);
      
      // Guardar en archivo como respaldo
      try {
        final ruta = await _rutaArchivo('$clave.json');
        final file = File(ruta);
        await file.writeAsString(contenido, flush: true);
      } catch (e) {
        print('Error al guardar archivo local: $e');
      }
    } catch (e) {
      rethrow;
    }
  }

  // Lee datos del almacenamiento seguro o del archivo
  static Future<dynamic> _leerDatos(String clave) async {
    try {
      // Intentar leer de secure storage primero
      var datos = await _storage.read(key: clave);
      
      // Si no hay datos en secure storage, intentar leer del archivo
      if (datos == null) {
        try {
          final ruta = await _rutaArchivo('$clave.json');
          final file = File(ruta);
          if (await file.exists()) {
            datos = await file.readAsString();
            // Si se encontró en archivo, actualizar secure storage
            if (datos != null) {
              await _storage.write(key: clave, value: datos);
            }
          }
        } catch (e) {
          print('Error al leer archivo local: $e');
        }
      }
      
      return datos != null ? jsonDecode(datos) : null;
    } catch (e) {
      rethrow;
    }
  }

  /// Guarda la lista de pedidos en el almacenamiento seguro
  static Future<void> guardarPedidos(List<PedidosViewModel> pedidos) async {
    try {
      // Obtener pedidos existentes
      final pedidosExistentes = await obtenerPedidos();
      
      // Crear un mapa para evitar duplicados
      final mapaPedidos = {
        for (var p in pedidosExistentes) p.pediId: p,
      };
      
      // Actualizar o agregar los nuevos pedidos
      for (var pedido in pedidos) {
        mapaPedidos[pedido.pediId] = pedido;
      }
      
      // Guardar la lista actualizada
      final listaActualizada = mapaPedidos.values.toList();
      final listaJson = listaActualizada.map((pedido) => pedido.toMap()).toList();
      
      // Usar el nuevo método _guardarDatos que guarda en ambos lugares
      await _guardarDatos(_pedidosKey, listaJson);
      
      // También guardar cada pedido individualmente para búsquedas más rápidas
      for (var pedido in listaActualizada) {
        await guardarDetallePedido(pedido);
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Obtiene la lista de pedidos guardados localmente
  static Future<List<PedidosViewModel>> obtenerPedidos() async {
    try {
      final data = await _leerDatos(_pedidosKey);
      if (data == null) return [];
      
      if (data is List) {
        return data.map<PedidosViewModel>((json) => 
          PedidosViewModel.fromJson(Map<String, dynamic>.from(json))
        ).toList();
      } else if (data is Map) {
        // Si por alguna razón los datos están en un mapa, convertirlo a lista
        return [PedidosViewModel.fromJson(Map<String, dynamic>.from(data))];
      }
      return [];
    } catch (e) {
      print('Error al obtener pedidos: $e');
      return [];
    }
  }

  /// Guarda el detalle de un pedido específico
  static Future<void> guardarDetallePedido(PedidosViewModel pedido) async {
    try {
      // No podemos modificar pedido.pediId directamente ya que es final
      // Si necesitamos un nuevo ID, debemos crear un nuevo objeto PedidosViewModel
      
      // Guardar el detalle del pedido
      final pedidoKey = '$_pedidoDetalleKey${pedido.pediId}';
      await _guardarDatos(pedidoKey, pedido.toMap());
      
      // Actualizar la lista de pedidos
      final pedidos = await obtenerPedidos();
      final index = pedidos.indexWhere((p) => p.pediId == pedido.pediId);
      
      if (index != -1) {
        pedidos[index] = pedido;
      } else {
        pedidos.add(pedido);
      }
      
      // Guardar la lista actualizada
      await _guardarDatos(_pedidosKey, pedidos.map((p) => p.toMap()).toList());
    } catch (e) {
      print('Error al guardar detalle del pedido: $e');
      rethrow;
    }
  }

  /// Obtiene el detalle de un pedido específico guardado localmente
  static Future<PedidosViewModel?> obtenerDetallePedido(int pedidoId) async {
    try {
      final pedidoKey = '$_pedidoDetalleKey$pedidoId';
      final data = await _leerDatos(pedidoKey);
      
      if (data == null) {
        // Si no se encuentra el detalle, intentar buscarlo en la lista general
        final todos = await obtenerPedidos();
        final pedido = todos.firstWhere(
          (p) => p.pediId == pedidoId,
          orElse: () => null as PedidosViewModel,
        );
        if (pedido != null) {
          await guardarDetallePedido(pedido); // Guardar para futuras búsquedas
          return pedido;
        }
        return null;
      }
      
      // Asegurarse de que los datos sean un Map<String, dynamic>
      final Map<String, dynamic> pedidoData = data is Map<String, dynamic>
          ? data
          : Map<String, dynamic>.from(data as Map);
          
      return PedidosViewModel.fromJson(pedidoData);
    } catch (e) {
      print('Error al obtener detalle del pedido $pedidoId: $e');
      return null;
    }
  }

  /// Agrega un pedido a la lista de pendientes de sincronización
  static Future<void> agregarPedidoPendiente(PedidosViewModel pedido) async {
    try {
      // Crear un nuevo pedido con un ID si es necesario
      PedidosViewModel pedidoConId = pedido;
      if (pedido.pediId == 0) {
        pedidoConId = PedidosViewModel(
          pediId: DateTime.now().millisecondsSinceEpoch,
          diClId: pedido.diClId,
          vendId: pedido.vendId,
          pediFechaPedido: pedido.pediFechaPedido,
          pediFechaEntrega: pedido.pediFechaEntrega,
          pedi_Codigo: pedido.pedi_Codigo,
          usuaCreacion: pedido.usuaCreacion,
          pediFechaCreacion: pedido.pediFechaCreacion,
          pediFechaModificacion: pedido.pediFechaModificacion,
          usuaModificacion: pedido.usuaModificacion,
          pediEstado: pedido.pediEstado,
          clieId: pedido.clieId,
          clieCodigo: pedido.clieCodigo,
          clieNombreNegocio: pedido.clieNombreNegocio,
          clieNombres: pedido.clieNombres,
          clieApellidos: pedido.clieApellidos,
          coloDescripcion: pedido.coloDescripcion,
          muniDescripcion: pedido.muniDescripcion,
          depaDescripcion: pedido.depaDescripcion,
          diClDireccionExacta: pedido.diClDireccionExacta,
          vendNombres: pedido.vendNombres,
          vendApellidos: pedido.vendApellidos,
          usuarioCreacion: pedido.usuarioCreacion,
          usuarioModificacion: pedido.usuarioModificacion,
          prodCodigo: pedido.prodCodigo,
          prodDescripcion: pedido.prodDescripcion,
          peDeProdPrecio: pedido.peDeProdPrecio,
          peDeCantidad: pedido.peDeCantidad,
          detalles: pedido.detalles,
          detallesJson: pedido.detallesJson,
          coFaNombreEmpresa: pedido.coFaNombreEmpresa,
          coFaDireccionEmpresa: pedido.coFaDireccionEmpresa,
          coFaRTN: pedido.coFaRTN,
          coFaCorreo: pedido.coFaCorreo,
          coFaTelefono1: pedido.coFaTelefono1,
          coFaTelefono2: pedido.coFaTelefono2,
          coFaLogo: pedido.coFaLogo,
          secuencia: pedido.secuencia,
        );
      }
      
      // Obtener pedidos pendientes existentes
      final pedidosPendientes = await obtenerPedidosPendientes();
      
      // Eliminar si ya existe un pedido con el mismo ID
      pedidosPendientes.removeWhere((p) => p.pediId == pedido.pediId);
      
      // Agregar el nuevo pedido
      pedidosPendientes.add(pedido);
      
      // Guardar la lista actualizada usando _guardarDatos
      await _guardarDatos(
        _pedidosPendientesKey,
        pedidosPendientes.map((p) => p.toMap()).toList(),
      );
      
      // Asegurarse de que el pedido también esté en la lista principal
      await guardarDetallePedido(pedido);
    } catch (e) {
      print('Error al agregar pedido pendiente: $e');
      rethrow;
    }
  }

  /// Obtiene la lista de pedidos pendientes de sincronización
  static Future<List<PedidosViewModel>> obtenerPedidosPendientes() async {
    try {
      final data = await _leerDatos(_pedidosPendientesKey);
      if (data == null) return [];
      
      if (data is List) {
        return data.map<PedidosViewModel?>((item) {
          try {
            if (item is Map<String, dynamic>) {
              return PedidosViewModel.fromJson(item);
            } else if (item is Map) {
              return PedidosViewModel.fromJson(Map<String, dynamic>.from(item));
            }
            throw Exception('Formato de pedido no válido');
          } catch (e) {
            print('Error al convertir pedido: $e');
            return null;
          }
        }).where((pedido) => pedido != null).map((pedido) => pedido!).toList();
      }
      return [];
    } catch (e) {
      print('Error al obtener pedidos pendientes: $e');
      return [];
    }
  }

  /// Elimina un pedido de la lista de pendientes después de sincronizar
  static Future<void> eliminarPedidoPendiente(int pedidoId) async {
    try {
      final pedidosPendientes = await obtenerPedidosPendientes();
      final nuevosPendientes = pedidosPendientes.where((p) => p.pediId != pedidoId).toList();
      
      if (nuevosPendientes.length < pedidosPendientes.length) {
        // Solo guardar si hubo cambios
        await _guardarDatos(
          _pedidosPendientesKey,
          nuevosPendientes.map((p) => p.toMap()).toList(),
        );
      }
    } catch (e) {
      print('Error al eliminar pedido pendiente $pedidoId: $e');
      rethrow;
    }
  }

  /// Sincroniza los pedidos pendientes con el servidor
  static Future<void> sincronizarPedidosPendientes() async {
    try {
      final pedidosService = PedidosService();
      final pedidosPendientes = await obtenerPedidosPendientes();
      
      if (pedidosPendientes.isEmpty) return;
      
      print('Iniciando sincronización de ${pedidosPendientes.length} pedidos pendientes');

      for (final pedido in pedidosPendientes) {
        try {
          print('Sincronizando pedido: ${pedido.pediId}');
          
          // Asegurarse de que los detalles estén en el formato correcto
          List<Map<String, dynamic>> detalles = [];
          if (pedido.detalles is List) {
            try {
              detalles = (pedido.detalles as List).map<Map<String, dynamic>>((d) {
                if (d is Map<String, dynamic>) return d;
                if (d is Map) return Map<String, dynamic>.from(d);
                if (d == null) return <String, dynamic>{};
                return (d as dynamic).toMap() ?? <String, dynamic>{};
              }).where((map) => map.isNotEmpty).toList();
            } catch (e) {
              print('Error al convertir detalles del pedido: $e');
              detalles = [];
            }
          }

          // Llamar al servicio para insertar el pedido
          final resultado = await pedidosService.insertarPedido(
            diClId: pedido.diClId,
            vendId: pedido.vendId,
            pediCodigo: pedido.pedi_Codigo ?? 'PED-${pedido.pediId}',
            fechaPedido: pedido.pediFechaPedido,
            fechaEntrega: pedido.pediFechaEntrega ?? DateTime.now().add(const Duration(days: 1)),
            usuaCreacion: pedido.usuaCreacion,
            clieId: pedido.clieId ?? 0,
            detalles: detalles,
          );

          if (resultado != null) {
            // Crear un nuevo pedido con los datos actualizados del servidor
            final pedidoActualizado = PedidosViewModel(
              pediId: resultado['pedi_Id'] ?? pedido.pediId,
              diClId: pedido.diClId,
              vendId: pedido.vendId,
              pediFechaPedido: pedido.pediFechaPedido,
              pediFechaEntrega: pedido.pediFechaEntrega,
              pedi_Codigo: resultado['pedi_Codigo'] ?? pedido.pedi_Codigo,
              usuaCreacion: pedido.usuaCreacion,
              pediFechaCreacion: pedido.pediFechaCreacion,
              usuaModificacion: pedido.usuaModificacion,
              pediFechaModificacion: pedido.pediFechaModificacion,
              pediEstado: pedido.pediEstado,
              clieCodigo: pedido.clieCodigo,
              clieId: pedido.clieId,
              clieNombreNegocio: pedido.clieNombreNegocio,
              clieNombres: pedido.clieNombres,
              clieApellidos: pedido.clieApellidos,
              coloDescripcion: pedido.coloDescripcion,
              muniDescripcion: pedido.muniDescripcion,
              depaDescripcion: pedido.depaDescripcion,
              diClDireccionExacta: pedido.diClDireccionExacta,
              vendNombres: pedido.vendNombres,
              vendApellidos: pedido.vendApellidos,
              usuarioCreacion: pedido.usuarioCreacion,
              usuarioModificacion: pedido.usuarioModificacion,
              prodCodigo: pedido.prodCodigo,
              prodDescripcion: pedido.prodDescripcion,
              peDeProdPrecio: pedido.peDeProdPrecio,
              peDeCantidad: pedido.peDeCantidad,
              detalles: pedido.detalles,
              detallesJson: pedido.detallesJson,
              coFaNombreEmpresa: pedido.coFaNombreEmpresa,
              coFaDireccionEmpresa: pedido.coFaDireccionEmpresa,
              coFaRTN: pedido.coFaRTN,
              coFaCorreo: pedido.coFaCorreo,
              coFaTelefono1: pedido.coFaTelefono1,
              coFaTelefono2: pedido.coFaTelefono2,
              coFaLogo: pedido.coFaLogo,
              secuencia: pedido.secuencia,
            );
            
            // Eliminar de pendientes y actualizar en la lista principal
            await eliminarPedidoPendiente(pedido.pediId);
            await guardarDetallePedido(pedidoActualizado);
            
            print('Pedido ${pedido.pediId} sincronizado correctamente');
          }
        } catch (e) {
          print('Error al sincronizar pedido ${pedido.pediId}: $e');
          // Continuar con el siguiente pedido
          continue;
        }
      }
      
      // Forzar actualización de la lista de pedidos
      final pedidosActuales = await obtenerPedidos();
      await _guardarDatos(
        _pedidosKey,
        pedidosActuales.map((p) => p.toMap()).toList(),
      );
      
    } catch (e) {
      print('Error en sincronizarPedidosPendientes: $e');
      rethrow;
    }
  }
}

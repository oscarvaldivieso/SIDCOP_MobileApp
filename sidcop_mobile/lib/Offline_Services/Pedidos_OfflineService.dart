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

  // Guarda el detalle de un pedido en el almacenamiento local
  static Future<void> guardarPedidoDetalle(int pedidoId, dynamic detalle) async {
    try {
      final detalleKey = '$_pedidoDetalleKey$pedidoId';
      await _guardarDatos(detalleKey, detalle);
    } catch (e) {
      print('Error al guardar detalle del pedido $pedidoId: $e');
      rethrow;
    }
  }

  // Preload all order details for offline access
  static Future<bool> preloadOrderDetails() async {
    try {
      final pedidosService = PedidosService();
      
      // Get all orders
      final pedidos = await pedidosService.getPedidos();
      
      // Save each order's details
      for (final pedido in pedidos) {
        try {
          final detalle = await pedidosService.getPedidoDetalle(pedido.pediId);
          await guardarPedidoDetalle(pedido.pediId, detalle);
        } catch (e) {
          print('Error al cargar detalle del pedido ${pedido.pediId}: $e');
          continue;
        }
      }
      
      return true;
    } catch (e) {
      print('Error en preloadOrderDetails: $e');
      return false;
    }
  }

  // Guarda un pedido pendiente de sincronización
  static Future<void> guardarPedidoPendiente(Map<String, dynamic> pedidoData) async {
    try {
      // Obtener pedidos pendientes existentes
      final pedidosPendientes = await _obtenerPedidosPendientes();
      
      // Agregar el nuevo pedido
      pedidosPendientes.add(pedidoData);
      
      // Guardar la lista actualizada
      await _guardarDatos(_pedidosPendientesKey, pedidosPendientes);
      
      print('Pedido guardado para sincronización: ${pedidoData['pedidoId']}');
    } catch (e) {
      print('Error al guardar pedido pendiente: $e');
      rethrow;
    }
  }
  
  // Obtiene la lista de pedidos pendientes de sincronización
  static Future<List<Map<String, dynamic>>> _obtenerPedidosPendientes() async {
    try {
      final datos = await _leerDatos(_pedidosPendientesKey);
      if (datos != null && datos is List) {
        return List<Map<String, dynamic>>.from(datos);
      }
      return [];
    } catch (e) {
      print('Error al obtener pedidos pendientes: $e');
      return [];
    }
  }
  
  // Sincroniza los pedidos pendientes con el servidor
  // Este método ya está implementado más abajo en el archivo
  // con la lógica completa de sincronización

  // Lee datos del almacenamiento seguro o del archivo
  static Future<dynamic> _leerDatos(String clave) async {
    try {
      print('Leyendo datos para clave: $clave');

      // Primero intentar leer de secure storage
      String? datos = await _storage.read(key: clave);

      // Si no hay datos en secure storage, intentar leer del archivo
      if (datos == null) {
        print('No se encontraron datos en secure storage, buscando en archivo...');
        try {
          final ruta = await _rutaArchivo('$clave.json');
          final file = File(ruta);

          if (await file.exists()) {
            print('Leyendo archivo: ${file.path}');
            datos = await file.readAsString();

            // Si se encontró en archivo, actualizar secure storage
            if (datos.isNotEmpty) {
              print('Datos encontrados en archivo, actualizando secure storage...');
              await _storage.write(key: clave, value: datos);
            } else {
              print('Archivo vacío');
              return null;
            }
          } else {
            print('Archivo no encontrado: ${file.path}');
            return null;
          }
        } catch (e) {
          print('Error al leer archivo local: $e');
          return null;
        }
      }

      if (datos != null && datos.isNotEmpty) {
        try {
          final decoded = jsonDecode(datos);
          print('Datos decodificados correctamente: ${decoded.runtimeType}');
          return decoded;
        } catch (e) {
          print('Error al decodificar JSON: $e');
          print('Datos crudos: $datos');
          return null;
        }
      }

      return null;
    } catch (e) {
      print('Error en _leerDatos: $e');
      rethrow;
    }
  }

  /// Guarda la lista de pedidos en el almacenamiento seguro
  static Future<void> guardarPedidos(List<PedidosViewModel> pedidos) async {
    try {
      print('=== GUARDANDO PEDIDOS ===');
      print('Cantidad de pedidos a guardar: ${pedidos.length}');

      if (pedidos.isEmpty) {
        print('Lista de pedidos vacía, no se guarda nada');
        return;
      }

      // Obtener pedidos existentes
      final pedidosExistentes = await obtenerPedidos();
      print('Pedidos existentes: ${pedidosExistentes.length}');

      // Crear un mapa para evitar duplicados usando pediId como clave
      final mapaPedidos = <int, PedidosViewModel>{};

      // Agregar pedidos existentes al mapa
      for (var pedido in pedidosExistentes) {
        mapaPedidos[pedido.pediId] = pedido;
      }
      print('Mapa inicializado con ${mapaPedidos.length} pedidos existentes');

      // Actualizar o agregar los nuevos pedidos
      for (var pedido in pedidos) {
        // Asegurarse de que los detalles estén en el formato correcto
        if (pedido.detallesJson == null && pedido.detalles.isNotEmpty) {
          pedido = PedidosViewModel(
            coFaNombreEmpresa: pedido.coFaNombreEmpresa,
            coFaDireccionEmpresa: pedido.coFaDireccionEmpresa,
            coFaRTN: pedido.coFaRTN,
            coFaCorreo: pedido.coFaCorreo,
            coFaTelefono1: pedido.coFaTelefono1,
            coFaTelefono2: pedido.coFaTelefono2,
            coFaLogo: pedido.coFaLogo,
            secuencia: pedido.secuencia,
            pediId: pedido.pediId,
            diClId: pedido.diClId,
            vendId: pedido.vendId,
            pediFechaPedido: pedido.pediFechaPedido,
            pediFechaEntrega: pedido.pediFechaEntrega,
            pedi_Codigo: pedido.pedi_Codigo,
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
            detallesJson: jsonEncode(pedido.detalles), // Asegurar que detallesJson esté en formato JSON
          );
        }
        mapaPedidos[pedido.pediId] = pedido;
      }
      print('Después de agregar nuevos: ${mapaPedidos.length} pedidos');

      // Convertir el mapa a lista
      final listaActualizada = mapaPedidos.values.toList();
      final listaJson = listaActualizada
          .map((pedido) => pedido.toMap())
          .toList();

      print('Lista final a guardar: ${listaJson.length} pedidos');

      // Guardar en la clave principal de pedidos
      await _guardarDatos(_pedidosKey, listaJson);

      // También guardar cada pedido individualmente para búsquedas más rápidas
      for (var pedido in listaActualizada) {
        await guardarDetallePedido(pedido);
      }

      print('=== PEDIDOS GUARDADOS EXITOSAMENTE ===');
    } catch (e) {
      print('Error en guardarPedidos: $e');
      rethrow;
    }
  }

  /// Procesa los detalles de un pedido para asegurar el formato correcto
  static void _procesarDetallesPedido(Map<String, dynamic> pedidoMap) {
    try {
      // Si no hay detalles pero sí hay detallesJson, intentar parsear
      if ((pedidoMap['detalles'] == null || 
          (pedidoMap['detalles'] is List && pedidoMap['detalles'].isEmpty)) &&
          pedidoMap['detallesJson'] != null) {
        try {
          if (pedidoMap['detallesJson'] is String) {
            pedidoMap['detalles'] = jsonDecode(pedidoMap['detallesJson']);
          } else {
            pedidoMap['detalles'] = pedidoMap['detallesJson'];
          }
          print('Detalles convertidos desde detallesJson: ${pedidoMap['detalles'].length} items');
        } catch (e) {
          print('Error al parsear detallesJson: $e');
          pedidoMap['detalles'] = [];
        }
      } else if (pedidoMap['detalles'] == null) {
        pedidoMap['detalles'] = [];
      }
      
      // Asegurarse de que los detalles sean una lista
      if (pedidoMap['detalles'] is! List) {
        pedidoMap['detalles'] = [pedidoMap['detalles']].whereType<dynamic>().toList();
      }
      
      // Asegurarse de que cada detalle tenga los campos necesarios
      final detalles = pedidoMap['detalles'] as List;
      for (var i = 0; i < detalles.length; i++) {
        if (detalles[i] is Map) {
          final detalle = Map<String, dynamic>.from(detalles[i]);
          detalle['descripcion'] = detalle['descripcion'] ?? detalle['prod_Descripcion'] ?? 'Producto sin descripción';
          detalle['cantidad'] = detalle['cantidad'] ?? detalle['peDe_Cantidad'] ?? 1;
          detalle['precio'] = detalle['precio'] ?? detalle['peDe_ProdPrecio'] ?? 0.0;
          detalle['imagen'] = detalle['imagen'] ?? detalle['prod_Imagen'] ?? '';
          detalles[i] = detalle;
        }
      }
      
      print('Procesados ${detalles.length} detalles para el pedido');
    } catch (e) {
      print('Error en _procesarDetallesPedido: $e');
      pedidoMap['detalles'] = [];
    }
  }

  /// Obtiene la lista de pedidos guardados localmente
  static Future<List<PedidosViewModel>> obtenerPedidos() async {
    try {
      print('=== OBTENIENDO TODOS LOS PEDIDOS ===');
      final data = await _leerDatos(_pedidosKey);

      if (data == null) {
        print('No se encontraron datos de pedidos en _pedidosKey');
        return [];
      }

      print('Tipo de datos: ${data.runtimeType}');
      print('Datos raw: $data'); // Debug adicional

      if (data is List) {
        print('Procesando lista de ${data.length} elementos');
        final List<PedidosViewModel> pedidos = [];

        for (int i = 0; i < data.length; i++) {
          try {
            final item = data[i];
            if (item is Map) {
              final pedidoMap = Map<String, dynamic>.from(item);

              // Asegurarse de que los detalles estén en el formato correcto
              _procesarDetallesPedido(pedidoMap);
              
              final pedido = PedidosViewModel.fromJson(pedidoMap);
              pedidos.add(pedido);
              print(
                'Pedido ${i + 1}: ID=${pedido.pediId} con ${pedido.detalles.length} detalles',
              );
            } else {
              print('Elemento $i no es un mapa: ${item.runtimeType}');
            }
          } catch (e, stackTrace) {
            print('Error procesando pedido en posición $i: $e');
            print('Stack trace: $stackTrace');
          }
        }

        print('Total de pedidos procesados: ${pedidos.length}');
        print('=== FIN OBTENIENDO PEDIDOS ===');
        return pedidos;
      } else if (data is Map) {
        // Si es un solo pedido (formato antiguo o error)
        print('Dato único detectado, convirtiendo a lista');
        try {
          final pedidoMap = Map<String, dynamic>.from(data);

          // Asegurarse de que los detalles estén en el formato correcto
          _procesarDetallesPedido(pedidoMap);
          
          final pedido = PedidosViewModel.fromJson(pedidoMap);
          print('Pedido único procesado: ID=${pedido.pediId} con ${pedido.detalles.length} detalles');
          return [pedido];
        } catch (e, stackTrace) {
          print('Error al procesar pedido único: $e');
          print('Stack trace: $stackTrace');
          return [];
        }
      }

      print('Formato de datos no reconocido: ${data.runtimeType}');
      return [];
    } catch (e) {
      print('Error al obtener pedidos: $e');
      return [];
    }
  }

  /// Guarda el detalle de un pedido específico
  static Future<void> guardarDetallePedido(PedidosViewModel pedido) async {
    try {
      // Guardar el detalle del pedido
      final pedidoKey = '$_pedidoDetalleKey${pedido.pediId}';
      await _guardarDatos(pedidoKey, pedido.toMap());

      // NO actualizar la lista completa aquí para evitar problemas de concurrencia
      // La lista se actualiza en guardarPedidos()
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
        final pedido = todos.where((p) => p.pediId == pedidoId).isNotEmpty
            ? todos.firstWhere((p) => p.pediId == pedidoId)
            : null;

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
      print('Iniciando agregarPedidoPendiente para pedido: ${pedido.pediId}');

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
          pediFechaCreacion: pedido.pediFechaCreacion ?? DateTime.now(),
          pediFechaModificacion: DateTime.now(),
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
          detallesJson: pedido.detallesJson ?? jsonEncode(pedido.detalles),
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
      print('Obteniendo pedidos pendientes existentes...');
      List<PedidosViewModel> pedidosPendientes = [];

      try {
        pedidosPendientes = await obtenerPedidosPendientes();
        print('Pedidos pendientes actuales: ${pedidosPendientes.length}');
      } catch (e) {
        print('Error al obtener pedidos pendientes: $e');
        pedidosPendientes = [];
      }

      // Verificar si el pedido ya existe en la lista
      final index = pedidosPendientes.indexWhere(
        (p) => p.pediId == pedidoConId.pediId,
      );

      if (index != -1) {
        // Actualizar pedido existente
        print('Actualizando pedido existente con ID: ${pedidoConId.pediId}');
        pedidosPendientes[index] = pedidoConId;
      } else {
        // Agregar nuevo pedido
        print('Agregando nuevo pedido con ID: ${pedidoConId.pediId}');
        pedidosPendientes.add(pedidoConId);
      }

      // Convertir a lista de mapas
      final listaParaGuardar = pedidosPendientes.map((p) => p.toMap()).toList();
      print('Guardando ${listaParaGuardar.length} pedidos pendientes...');

      // Guardar la lista actualizada
      await _guardarDatos(_pedidosPendientesKey, listaParaGuardar);

      // Asegurarse de que el pedido también esté en la lista principal
      print('Guardando detalle del pedido ${pedidoConId.pediId}...');
      await guardarDetallePedido(pedidoConId);

      // Verificar que se guardó correctamente
      final pedidosGuardados = await _leerDatos(_pedidosPendientesKey);
      final totalGuardado = pedidosGuardados is List
          ? pedidosGuardados.length
          : 0;
      print('Verificación: Se guardaron $totalGuardado pedidos en total');

      print(
        'Pedido ${pedidoConId.pediId} procesado correctamente. Total pendientes: ${pedidosPendientes.length}',
      );
    } catch (e) {
      print('Error al agregar pedido pendiente: $e');
      rethrow;
    }
  }

  /// Obtiene la lista de pedidos pendientes de sincronización
  static Future<List<PedidosViewModel>> obtenerPedidosPendientes() async {
    try {
      print('=== INICIO obtenerPedidosPendientes ===');
      final data = await _leerDatos(_pedidosPendientesKey);

      if (data == null) {
        print('No se encontraron datos de pedidos pendientes');
        return [];
      }

      print('Tipo de datos recuperados: ${data.runtimeType}');
      print('Contenido raw de datos: $data'); // Debug adicional

      // Si es una lista, procesar cada elemento
      if (data is List) {
        print('Procesando lista de ${data.length} pedidos...');
        final pedidos = <PedidosViewModel>[];

        for (var i = 0; i < data.length; i++) {
          try {
            final item = data[i];
            print(
              'Procesando item $i: ${item.runtimeType} - $item',
            ); // Debug adicional

            if (item is Map) {
              final pedidoMap = item is Map<String, dynamic>
                  ? item
                  : Map<String, dynamic>.from(item);

              print(
                'PedidoMap keys: ${pedidoMap.keys.toList()}',
              ); // Debug adicional
              print('pediId value: ${pedidoMap['pediId']}'); // Debug adicional

              // Verificar campos requeridos
              if (pedidoMap['pediId'] == null) {
                print('  ⚠️  Pedido sin ID, se omitirá');
                continue;
              }

              final pedido = PedidosViewModel.fromJson(pedidoMap);
              pedidos.add(pedido);
              print('  ✓ Pedido ${pedido.pediId} agregado correctamente');
            } else {
              print(
                '  ⚠️  Elemento en posición $i no es un mapa: ${item.runtimeType}',
              );
            }
          } catch (e, stackTrace) {
            print('  ❌ Error procesando pedido #$i: $e');
            print('  Stack trace: $stackTrace');
          }
        }

        print('Total de pedidos procesados exitosamente: ${pedidos.length}');
        print('=== FIN obtenerPedidosPendientes ===');
        return pedidos;
      }

      // Si es un solo pedido (formato antiguo)
      if (data is Map) {
        print('⚠️  Formato antiguo detectado: un solo pedido');
        try {
          final pedidoMap = data is Map<String, dynamic>
              ? data
              : Map<String, dynamic>.from(data);

          if (pedidoMap['pediId'] == null) {
            print('❌ Pedido sin ID, no se puede procesar');
            return [];
          }

          final pedido = PedidosViewModel.fromJson(pedidoMap);
          print('✓ Pedido único ${pedido.pediId} procesado');
          print('=== FIN obtenerPedidosPendientes ===');
          return [pedido];
        } catch (e) {
          print('❌ Error al procesar pedido único: $e');
          return [];
        }
      }

      print('❌ Formato de datos no soportado: ${data.runtimeType}');
      return [];
    } catch (e, stackTrace) {
      print('❌❌❌ ERROR CRÍTICO en obtenerPedidosPendientes ❌❌❌');
      print('Error: $e');
      print('Stack trace: $stackTrace');
      return [];
    }
  }

  /// Elimina un pedido de la lista de pendientes después de sincronizar
  static Future<void> eliminarPedidoPendiente(int pedidoId) async {
    try {
      final pedidosPendientes = await obtenerPedidosPendientes();
      final nuevosPendientes = pedidosPendientes
          .where((p) => p.pediId != pedidoId)
          .toList();

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

      print(
        'Iniciando sincronización de ${pedidosPendientes.length} pedidos pendientes',
      );

      for (final pedido in pedidosPendientes) {
        try {
          print('Sincronizando pedido: ${pedido.pediId}');

          // Asegurarse de que los detalles estén en el formato correcto
          List<Map<String, dynamic>> detalles = [];
          if (pedido.detalles is List) {
            try {
              detalles = (pedido.detalles as List)
                  .map<Map<String, dynamic>>((d) {
                    if (d is Map<String, dynamic>) return d;
                    if (d is Map) return Map<String, dynamic>.from(d);
                    if (d == null) return <String, dynamic>{};
                    return (d as dynamic).toMap() ?? <String, dynamic>{};
                  })
                  .where((map) => map.isNotEmpty)
                  .toList();
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
            fechaEntrega:
                pedido.pediFechaEntrega ??
                DateTime.now().add(const Duration(days: 1)),
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

  /// Método adicional para verificar el estado del almacenamiento (solo para debug)
  static Future<void> verificarEstadoAlmacenamiento() async {
    try {
      print('=== VERIFICACIÓN ESTADO ALMACENAMIENTO ===');

      // Verificar pedidos principales
      final pedidosData = await _leerDatos(_pedidosKey);
      print(
        'Datos en $_pedidosKey: ${pedidosData?.runtimeType} - ${pedidosData is List ? (pedidosData as List).length : 'No es lista'}',
      );

      // Verificar pedidos pendientes
      final pendientesData = await _leerDatos(_pedidosPendientesKey);
      print(
        'Datos en $_pedidosPendientesKey: ${pendientesData?.runtimeType} - ${pendientesData is List ? (pendientesData as List).length : 'No es lista'}',
      );

      // Listar todas las claves en secure storage
      final todasLasClaves = await _storage.readAll();
      print(
        'Todas las claves en secure storage: ${todasLasClaves.keys.toList()}',
      );

      print('=== FIN VERIFICACIÓN ===');
    } catch (e) {
      print('Error en verificación: $e');
    }
  }

  /// Método auxiliar para limpiar y reinicializar el almacenamiento (usar solo para debug)
  static Future<void> limpiarDatosDebug() async {
    try {
      await _storage.delete(key: _pedidosKey);
      await _storage.delete(key: _pedidosPendientesKey);
      print('Datos limpiados para debug');
    } catch (e) {
      print('Error limpiando datos: $e');
    }
  }
}
